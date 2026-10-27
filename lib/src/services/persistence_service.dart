import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/alert_event.dart';
import '../models/error_record.dart';
import '../models/log_entry.dart';
import '../models/network_request.dart';
import '../utils/inspector_internal_log.dart';
import 'export_service.dart';

/// 持久化环形缓冲服务 / Persistence ring-buffer service
///
/// 所有采集数据原本只存在于内存（ListQueue + 单例），App 崩溃或面板长期不开就会丢失。
/// 本服务把日志 / 网络 / 异常异步落盘到 SQLite，按"行数上限 + 保留时长"双重
/// 滚动裁剪，形成磁盘环形缓冲，从而支持崩溃后复盘与"导出本次会话完整存档"。
/// Collected data previously lived only in memory (ListQueue + singleton) and was
/// lost when the app crashed or the panel stayed closed. This service async-flushes
/// logs / network / errors into SQLite, rolling by both row cap and retention
/// window (a disk ring buffer) — enabling crash post-mortems and a full
/// "export this session" archive.
///
/// 全部操作都在 try/catch 内并优雅降级：数据库不可用（如桌面端未配置 FFI）
/// 时 [isEnabled] 为 false，所有写入变为空操作，绝不影响宿主 App。
/// Everything is guarded by try/catch and degrades gracefully: if the DB is
/// unavailable (e.g. desktop without FFI) [isEnabled] is false and all writes
/// become no-ops — never affecting the host app.
class PersistenceService {
  PersistenceService._();

  /// 单例实例 / Singleton instance
  static final PersistenceService instance = PersistenceService._();

  /// 数据库文件名 / Database file name
  static const String _dbName = 'zero_inspector_kit.db';

  /// 数据库版本 / Database version
  /// Schema 版本：2 = 补齐裁剪用的 ts / last_ts 索引；3 = 新增 alerts 表（告警持久化）
  /// Schema version: 2 = ts / last_ts indexes; 3 = new `alerts` table for
  /// alert persistence.
  static const int _dbVersion = 3;

  /// 每张表的默认行数上限（环形缓冲）/ Default per-table row cap (ring buffer)
  static const int _defaultMaxRows = 5000;

  /// 默认保留时长 / Default retention window
  static const Duration _defaultRetention = Duration(days: 7);

  /// 默认刷盘间隔 / Default flush interval
  static const Duration _defaultFlushInterval = Duration(seconds: 2);

  /// 累积到该条数立即刷盘（不等定时器）/ Batch size that triggers an immediate flush
  static const int _flushThreshold = 50;

  Database? _db;
  bool _enabled = false;

  /// dispose 后不允许在途 init 再拉起定时器 / 打开新库。
  /// After dispose, an in-flight init must not start a timer or open a new DB.
  ///
  /// 此前 dispose 与在途 init 存在竞态：dispose 时 `_enabled` 仍为 false、`_db`
  /// 仍为 null，于是既不刷盘也不关库；随后 init 完成并把 `_enabled = true` +
  /// `Timer.periodic(2s)` 装上，留下一个**永远不会再被 cancel 的刷盘定时器**和
  /// 一个无人关闭的数据库句柄（`_initFuture = null` 还会让重试循环再开一个库）。
  /// Previously dispose raced with an in-flight init: at dispose time `_enabled`
  /// was still false and `_db` still null, so nothing was flushed or closed; the
  /// init then completed and installed `_enabled = true` + a 2s
  /// `Timer.periodic` — leaving a flush timer that is never cancelled again and a
  /// DB handle nobody owns (and `_initFuture = null` let the retry loop open yet
  /// another database).
  bool _disposed = false;

  /// 正在进行的 init 任务；用于并发防重入，避免两次 init 各 openDatabase
  /// 导致前一个句柄泄漏。失败时置 null 以便 barrel 的重试循环再次尝试。
  /// In-flight init task: prevents two concurrent `init`s from each opening a
  /// database (leaking the first handle). Reset to null on failure so the host's
  /// retry loop can try again once the binding is ready.
  Completer<void>? _initFuture;
  int _maxRows = _defaultMaxRows;
  Duration _retention = _defaultRetention;
  Timer? _flushTimer;

  /// 待刷盘缓冲：按条目 id 去重（last-wins）。
  /// Pending flush buffers: keyed by entry id, last write wins.
  ///
  /// 为什么必须去重：同一逻辑记录会被重复入队 —— 多行日志续行合并后以同一
  /// `LogEntry.id` 再次入队（此前落 N 行、重启回放出现 N 次且内容递增）；
  /// 网络请求先入队一次（发请求），响应到达后再入队一次（落 2 行，会话存档
  /// 里同一请求出现两条）；聚合异常每次重复命中都入队。用 Map 覆盖写保证
  /// 一条记录最终只落一行最新状态。
  /// Why dedupe: the same logical record is enqueued repeatedly — a reassembled
  /// multi-line log re-enqueues under the same `LogEntry.id` (previously N rows
  /// on disk, N duplicates on replay with growing content); a network request is
  /// enqueued once on send and again on response (2 rows, two copies in the
  /// session archive); an aggregated error re-enqueues on every repeat hit.
  /// Map overwrite guarantees one final row per record.
  ///
  /// 告警事件没有稳定 id（每次触发都是独立事件），保持 List 顺序入队。
  /// Alert events have no stable id (each firing is a distinct event), so they
  /// stay in a List and keep their insertion order.
  final Map<String, LogEntry> _pendingLogs = {};
  final Map<String, NetworkRequest> _pendingNetwork = {};
  final Map<String, ErrorRecord> _pendingErrors = {};
  final List<AlertEvent> _pendingAlerts = [];

  /// 是否已启用（DB 可用）/ Whether enabled (DB available)
  bool get isEnabled => _enabled;

  /// 每张表的行数上限（环形缓冲裁剪线），由 [init] 的 [maxRowsPerTable] 决定。
  /// Row cap per table (the ring-buffer trim line), set via [init]'s
  /// [maxRowsPerTable].
  int get maxRowsPerTable => _maxRows;

  /// 初始化数据库（失败时优雅降级）/ Initialize the DB (degrades gracefully)
  Future<void> init({
    int maxRowsPerTable = _defaultMaxRows,
    Duration retention = _defaultRetention,
    Duration flushInterval = _defaultFlushInterval,
  }) async {
    if (_enabled) return;
    // dispose 之后不再开启持久化（否则会把已释放的服务重新拉起来）。
    // Never start persistence again after dispose.
    if (_disposed) return;
    // 并发防重入：已有 init 在跑则直接复用其结果，避免两个调用各 openDatabase
    // 导致前一个句柄泄漏。
    // Concurrency guard: reuse the in-flight init instead of opening a second DB.
    if (_initFuture != null) return _initFuture!.future;
    final c = Completer<void>();
    _initFuture = c;
    _maxRows = maxRowsPerTable;
    _retention = retention;
    try {
      final dir = await getDatabasesPath();
      final path = dir.endsWith('/') ? '$dir$_dbName' : '$dir/$_dbName';
      _db = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE logs(id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'ts INTEGER, level INTEGER, tag TEXT, message TEXT, eid TEXT)',
          );
          await db.execute(
            'CREATE TABLE network(id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'ts INTEGER, method TEXT, url TEXT, data TEXT)',
          );
          await db.execute(
            'CREATE TABLE errors(id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'ts INTEGER, type TEXT, count INTEGER, first_ts INTEGER, '
            'last_ts INTEGER, stack TEXT, message TEXT, eid TEXT)',
          );
          await db.execute(
            'CREATE TABLE alerts(id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'ts INTEGER, last_ts INTEGER, source TEXT, message TEXT)',
          );
          await _createIndexes(db);
        },
        // 版本升级时补表 + 重建索引：此前没有 onUpgrade，未来加字段必然丢数据。
        // Add the missing table and rebuild indexes on upgrade; there was no
        // onUpgrade before, so adding a column would have silently lost data.
        onUpgrade: (db, oldVersion, newVersion) async {
          await db.execute(
            'CREATE TABLE IF NOT EXISTS alerts('
            'id INTEGER PRIMARY KEY AUTOINCREMENT, '
            'ts INTEGER, last_ts INTEGER, source TEXT, message TEXT)',
          );
          await _createIndexes(db);
        },
      );
      // 等待期间可能已被 dispose：立刻关掉刚打开的库，绝不装上定时器。
      // We may have been disposed while awaiting: close the freshly opened DB and
      // never install the timer.
      if (_disposed) {
        try {
          await _db?.close();
        } catch (_) {}
        _db = null;
        c.complete();
        return;
      }
      _enabled = true;
      _flushTimer?.cancel();
      _flushTimer = Timer.periodic(flushInterval, (_) => flush());
      await _trim();
      c.complete();
    } catch (_) {
      // 桌面端未配置 sqflite FFI 等情况：降级为纯内存模式。
      // e.g. desktop without sqflite FFI: fall back to memory-only mode.
      _enabled = false;
      _db = null;
      // 失败后允许重试（binding 就绪后再调 init 能重新打开）。
      // Allow a later retry after failure (e.g. once the binding is ready).
      _initFuture = null;
      c.complete();
    }
    return c.future;
  }

  /// 建索引：裁剪每 2s 跑 6 条 `NOT IN (SELECT id ... ORDER BY id DESC LIMIT n)`
  /// 的全表扫描，没有 ts / last_ts 索引时代价随行数线性增长。
  /// Create the indexes: trimming runs 6 `NOT IN (SELECT id ... ORDER BY id
  /// DESC LIMIT n)` statements every 2s, which degrade to full scans that grow
  /// linearly with row count without ts / last_ts indexes.
  static Future<void> _createIndexes(Database db) async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_logs_ts ON logs(ts)',
      'CREATE INDEX IF NOT EXISTS idx_network_ts ON network(ts)',
      'CREATE INDEX IF NOT EXISTS idx_errors_ts ON errors(ts)',
      'CREATE INDEX IF NOT EXISTS idx_errors_last_ts ON errors(last_ts)',
      'CREATE INDEX IF NOT EXISTS idx_alerts_ts ON alerts(ts)',
      'CREATE INDEX IF NOT EXISTS idx_alerts_last_ts ON alerts(last_ts)',
    ];
    for (final sql in statements) {
      try {
        await db.execute(sql);
      } catch (_) {}
    }
  }

  /// 入队一条日志（异步落盘）/ Enqueue a log (async flush)
  ///
  /// 同一 id 重复入队（多行日志续行合并）只保留最新一份，见 [_pendingLogs]。
  /// Repeated enqueues of the same id (multi-line log reassembly) keep only the
  /// newest copy — see [_pendingLogs].
  void enqueueLog(LogEntry e) {
    if (!_enabled) return;
    // 先删后插：覆盖写的同时把该条目移到队尾，使 flush 的插入顺序反映最新时序。
    // Remove-then-put: overwrite AND move to the tail so flush insertion order
    // reflects the latest write order.
    _pendingLogs.remove(e.id);
    _pendingLogs[e.id] = e;
    if (_pendingLogs.length >= _flushThreshold) flush();
  }

  /// 入队一条网络记录 / Enqueue a network record
  ///
  /// 同一请求会先入队一次（发送）、再入队一次（响应到达），按 id 覆盖写，
  /// 最终只落一行含响应的完整记录。
  /// A request is enqueued on send and again on response; the id-keyed
  /// overwrite keeps exactly one complete row.
  void enqueueNetwork(NetworkRequest r) {
    if (!_enabled) return;
    _pendingNetwork.remove(r.id);
    _pendingNetwork[r.id] = r;
    if (_pendingNetwork.length >= _flushThreshold) flush();
  }

  /// 入队一条聚合异常 / Enqueue an aggregated error
  ///
  /// 同一崩溃的每次重复命中都入队，按 id 覆盖写后只保留计数最高的最新状态。
  /// Every repeat hit of the same crash enqueues; the id-keyed overwrite keeps
  /// the newest state (highest count).
  void enqueueError(ErrorRecord e) {
    if (!_enabled) return;
    _pendingErrors.remove(e.id);
    _pendingErrors[e.id] = e;
    if (_pendingErrors.length >= _flushThreshold) flush();
  }

  /// 入队一条告警事件（异步落盘，崩溃后可在 Alerts 标签回看）
  /// Enqueue an alert event (async flush; recoverable in the Alerts tab later)
  void enqueueAlert(AlertEvent e) {
    if (!_enabled) return;
    _pendingAlerts.add(e);
    if (_pendingAlerts.length >= _flushThreshold) flush();
  }

  /// 把缓冲区写入磁盘并按环形缓冲裁剪 / Flush buffer to disk then trim
  Future<void> flush() async {
    final db = _db;
    if (!_enabled || db == null) return;
    if (_pendingLogs.isEmpty &&
        _pendingNetwork.isEmpty &&
        _pendingErrors.isEmpty &&
        _pendingAlerts.isEmpty) {
      return;
    }

    // Map 的 values 即去重后的最新状态（LinkedHashMap 保持写入顺序）。
    // The maps' values are the deduped newest states (LinkedHashMap keeps order).
    final logs = List<LogEntry>.of(_pendingLogs.values);
    _pendingLogs.clear();
    final nets = List<NetworkRequest>.of(_pendingNetwork.values);
    _pendingNetwork.clear();
    final errs = List<ErrorRecord>.of(_pendingErrors.values);
    _pendingErrors.clear();
    final alerts = List<AlertEvent>.of(_pendingAlerts);
    _pendingAlerts.clear();

    try {
      final batch = db.batch();
      for (final l in logs) {
        batch.insert('logs', {
          'ts': l.timestamp.millisecondsSinceEpoch,
          'level': l.level.index,
          'tag': l.tag,
          'message': l.message,
          'eid': l.id,
        });
      }
      for (final n in nets) {
        batch.insert('network', {
          'ts': n.requestTime,
          'method': n.method,
          'url': n.url,
          'data': jsonEncode(n.toJson()),
        });
      }
      for (final e in errs) {
        batch.insert('errors', {
          'ts': e.lastSeen.millisecondsSinceEpoch,
          'type': e.type,
          'count': e.count,
          'first_ts': e.firstSeen.millisecondsSinceEpoch,
          'last_ts': e.lastSeen.millisecondsSinceEpoch,
          'stack': e.sampleStack,
          'message': e.message,
          'eid': e.id,
        });
      }
      for (final a in alerts) {
        final ts = a.time.millisecondsSinceEpoch;
        batch.insert('alerts', {
          'ts': ts,
          'last_ts': ts,
          'source': a.source,
          'message': a.message,
        });
      }
      await batch.commit(noResult: true);
      await _trim();
      _flushFailures = 0;
    } catch (_) {
      // 写盘失败（磁盘满 / DB 已关 / schema 冲突）时把待写数据放回缓冲：此前缓冲
      // 在 `commit` **之前**就被清空，一次失败就永久丢弃整批日志 / 网络 / 异常 /
      // 告警，且完全没有痕迹。
      // Put the entries back when the write fails (disk full / DB closed / schema
      // conflict): the buffers used to be cleared *before* `commit`, so a single
      // failure silently dropped a whole batch of logs / network / errors / alerts.
      for (final l in logs) {
        _pendingLogs.putIfAbsent(l.id, () => l);
      }
      for (final n in nets) {
        _pendingNetwork.putIfAbsent(n.id, () => n);
      }
      for (final e in errs) {
        _pendingErrors.putIfAbsent(e.id, () => e);
      }
      _pendingAlerts.insertAll(0, alerts);

      // 连续失败说明磁盘确实不可写：无休止地堆积只会吃光内存，这里优雅降级为
      // 纯内存模式（与"数据库不可用"时的行为一致），并记一条内部日志便于排查。
      // Repeated failures mean the disk really is unwritable: buffering forever
      // would just exhaust memory, so degrade to memory-only mode (consistent
      // with the "DB unavailable" path) and leave one internal log line.
      _flushFailures++;
      if (_flushFailures >= _maxConsecutiveFlushFailures) {
        _enabled = false;
        _pendingLogs.clear();
        _pendingNetwork.clear();
        _pendingErrors.clear();
        _pendingAlerts.clear();
        InspectorInternalLog.error(
          'persistence',
          'Flush failed $_flushFailures times in a row; persistence degraded to '
              'memory-only / 连续 $_flushFailures 次刷盘失败，已降级为纯内存模式',
        );
      }
    }
  }

  /// 连续刷盘失败计数，成功一次即清零 / Consecutive flush failures; reset on success
  int _flushFailures = 0;

  /// 连续失败多少次后降级为纯内存模式 / Failures before degrading to memory-only
  static const int _maxConsecutiveFlushFailures = 5;

  /// 按保留时长 + 行数上限滚动裁剪（环形缓冲）/ Roll by retention + row cap
  Future<void> _trim() async {
    final db = _db;
    if (db == null) return;
    try {
      final cutoff = DateTime.now().subtract(_retention).millisecondsSinceEpoch;
      await db.delete('logs', where: 'ts < ?', whereArgs: [cutoff]);
      await db.delete('network', where: 'ts < ?', whereArgs: [cutoff]);
      await db.delete('errors', where: 'last_ts < ?', whereArgs: [cutoff]);
      await db.delete('alerts', where: 'last_ts < ?', whereArgs: [cutoff]);
      // 超出行数上限的最旧记录 / Drop oldest rows beyond the cap
      await db.execute(
        'DELETE FROM logs WHERE id NOT IN '
        '(SELECT id FROM logs ORDER BY id DESC LIMIT $_maxRows)',
      );
      await db.execute(
        'DELETE FROM network WHERE id NOT IN '
        '(SELECT id FROM network ORDER BY id DESC LIMIT $_maxRows)',
      );
      await db.execute(
        'DELETE FROM errors WHERE id NOT IN '
        '(SELECT id FROM errors ORDER BY id DESC LIMIT $_maxRows)',
      );
      await db.execute(
        'DELETE FROM alerts WHERE id NOT IN '
        '(SELECT id FROM alerts ORDER BY id DESC LIMIT $_maxRows)',
      );
    } catch (_) {}
  }

  /// 读取已持久化的日志（最新在前）/ Load persisted logs (newest first)
  ///
  /// 按 `eid` 去重：旧版本（<1.17.0）会把续行合并的多行日志按合并次数落多行，
  /// 直接回放会在日志列表出现重复条目。查询按 `id DESC`，故首次出现即为最新
  /// 状态，后续同 `eid` 行跳过。
  /// Deduped by `eid`: versions before 1.17.0 wrote one row per reassembly step
  /// of a multi-line log, so replaying them verbatim duplicated entries. Rows
  /// come back newest-first (`id DESC`), so the first occurrence is the newest
  /// state and later rows sharing the `eid` are skipped.
  Future<List<LogEntry>> loadLogs({int limit = 500}) async {
    final db = _db;
    if (!_enabled || db == null) return const [];
    try {
      final rows = await db.query('logs', orderBy: 'id DESC', limit: limit);
      final seen = <String>{};
      final out = <LogEntry>[];
      for (final r in rows) {
        final id = (r['eid'] as String?) ?? '${r['id']}';
        if (!seen.add(id)) continue;
        final levelIndex = (r['level'] as int?) ?? 0;
        out.add(
          LogEntry(
            id: id,
            level: levelIndex >= 0 && levelIndex < LogLevel.values.length
                ? LogLevel.values[levelIndex]
                : LogLevel.verbose,
            message: (r['message'] as String?) ?? '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(
              (r['ts'] as int?) ?? 0,
            ),
            tag: r['tag'] as String?,
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// 读取已持久化的聚合异常（最新在前）/ Load persisted errors (newest first)
  Future<List<ErrorRecord>> loadErrors({int limit = 200}) async {
    final db = _db;
    if (!_enabled || db == null) return const [];
    try {
      final rows = await db.query('errors', orderBy: 'id DESC', limit: limit);
      return rows.map((r) {
        final first = (r['first_ts'] as int?) ?? (r['ts'] as int?) ?? 0;
        final last = (r['last_ts'] as int?) ?? first;
        final id = (r['eid'] as String?) ?? '${r['id']}';
        return ErrorRecord(
          id: id,
          type: (r['type'] as String?) ?? '',
          message: (r['message'] as String?) ?? '',
          stackSignature: id,
          count: (r['count'] as int?) ?? 1,
          firstSeen: DateTime.fromMillisecondsSinceEpoch(first),
          lastSeen: DateTime.fromMillisecondsSinceEpoch(last),
          sampleStack: r['stack'] as String?,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// 读取已持久化的告警事件（最新在前）/ Load persisted alerts (newest first)
  Future<List<AlertEvent>> loadAlerts({int limit = 100}) async {
    final db = _db;
    if (!_enabled || db == null) return const [];
    try {
      final rows = await db.query('alerts', orderBy: 'id DESC', limit: limit);
      return rows.map((r) {
        return AlertEvent(
          source: (r['source'] as String?) ?? '',
          message: (r['message'] as String?) ?? '',
          time: DateTime.fromMillisecondsSinceEpoch((r['ts'] as int?) ?? 0),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// 读取已持久化的网络记录（原始 JSON，最新在前）
  /// Load persisted network records (raw JSON, newest first)
  ///
  /// 按记录 `id` 去重：旧版本（<1.17.0）对同一请求会落"发请求"与"收响应"两行，
  /// 直接读回会在会话存档里出现同一请求两条。查询按 `id DESC`，首次出现即为
  /// 最新状态（含响应）。
  /// Deduped by record `id`: versions before 1.17.0 wrote two rows per request
  /// (send + response), so reading them back verbatim duplicated the request in
  /// the session archive. Rows come back newest-first, so the first occurrence
  /// is the newest state (response included).
  Future<List<Map<String, dynamic>>> loadNetworkJson({int limit = 500}) async {
    final db = _db;
    if (!_enabled || db == null) return const [];
    try {
      final rows = await db.query('network', orderBy: 'id DESC', limit: limit);
      final seen = <String>{};
      final out = <Map<String, dynamic>>[];
      for (final r in rows) {
        final data = r['data'] as String?;
        if (data == null) continue;
        try {
          final decoded = jsonDecode(data);
          if (decoded is! Map<String, dynamic>) continue;
          final id = decoded['id'];
          if (id is String && !seen.add(id)) continue;
          out.add(decoded);
        } catch (_) {}
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// 构建"本次会话完整存档"JSON（日志 + 异常 + 网络）
  /// Build the full-session archive JSON (logs + errors + network)
  Future<String> buildSessionArchiveJson({
    int logLimit = 2000,
    int netLimit = 500,
    int errLimit = 200,
    int alertLimit = 100,
  }) async {
    await flush();
    final logs = await loadLogs(limit: logLimit);
    final errs = await loadErrors(limit: errLimit);
    final nets = await loadNetworkJson(limit: netLimit);
    final alerts = await loadAlerts(limit: alertLimit);
    return jsonEncode({
      'generatedAt': DateTime.now().toIso8601String(),
      'logs': logs.map((l) => l.toJson()).toList(),
      'errors': errs
          .map(
            (e) => {
              'id': e.id,
              'type': e.type,
              'message': e.message,
              'count': e.count,
              'firstSeen': e.firstSeen.toIso8601String(),
              'lastSeen': e.lastSeen.toIso8601String(),
              'stack': e.sampleStack,
            },
          )
          .toList(),
      'network': nets,
      'alerts': alerts
          .map(
            (a) => {
              'source': a.source,
              'message': a.message,
              'timestamp': a.time.toIso8601String(),
            },
          )
          .toList(),
    });
  }

  /// 导出并分享"本次会话完整存档"/ Export & share the full-session archive
  Future<bool> exportSessionArchiveAndShare() async {
    if (!_enabled) return false;
    try {
      final json = await buildSessionArchiveJson();
      final path = await ExportService.instance.writeToFile(
        json,
        'zik_session_${DateTime.now().millisecondsSinceEpoch}.json',
      );
      await ExportService.instance.shareFile(
        path,
        mimeType: 'application/json',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 清空磁盘上的持久化数据 / Clear persisted data on disk
  Future<void> clearAll() async {
    _pendingLogs.clear();
    _pendingNetwork.clear();
    _pendingErrors.clear();
    _pendingAlerts.clear();
    final db = _db;
    if (db == null) return;
    try {
      await db.delete('logs');
      await db.delete('network');
      await db.delete('errors');
      await db.delete('alerts');
    } catch (_) {}
  }

  /// 关闭（先刷盘）/ Close (flush first)
  Future<void> dispose() async {
    _disposed = true;
    _flushTimer?.cancel();
    _flushTimer = null;
    // 先等在途 init 收尾：它在 dispose 之前就已经 await 上了，若不等待，它随后
    // 会装上一个新的定时器并持有一个无人关闭的库。
    // Await the in-flight init first: it started before dispose, so if we do not
    // wait it will install a new timer and hold a DB nobody closes.
    final pending = _initFuture;
    if (pending != null) await pending.future;
    if (_enabled) await flush();
    try {
      await _db?.close();
    } catch (_) {}
    _db = null;
    _enabled = false;
    _initFuture = null;
    // 复位标志，保持"dispose 之后可以再次 init 重新启用"这一契约（见
    // `ZeroInspectorKit.dispose` 的文档）。在途 init 已在上面被 await 并自行退出，
    // 因此这里复位不会重新引入竞态。
    // Reset the flag to keep the documented contract that `init` can re-enable
    // persistence after `dispose` (see `ZeroInspectorKit.dispose`). The in-flight
    // init was awaited above and bailed out on its own, so resetting here does not
    // reintroduce the race.
    _disposed = false;
  }
}
