import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/alert_event.dart';
import '../models/error_record.dart';
import '../models/log_entry.dart';
import '../models/network_request.dart';
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
  int _maxRows = _defaultMaxRows;
  Duration _retention = _defaultRetention;
  Timer? _flushTimer;

  final List<LogEntry> _pendingLogs = [];
  final List<NetworkRequest> _pendingNetwork = [];
  final List<ErrorRecord> _pendingErrors = [];
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
      _enabled = true;
      _flushTimer?.cancel();
      _flushTimer = Timer.periodic(flushInterval, (_) => flush());
      await _trim();
    } catch (_) {
      // 桌面端未配置 sqflite FFI 等情况：降级为纯内存模式。
      // e.g. desktop without sqflite FFI: fall back to memory-only mode.
      _enabled = false;
      _db = null;
    }
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
  void enqueueLog(LogEntry e) {
    if (!_enabled) return;
    _pendingLogs.add(e);
    if (_pendingLogs.length >= _flushThreshold) flush();
  }

  /// 入队一条网络记录 / Enqueue a network record
  void enqueueNetwork(NetworkRequest r) {
    if (!_enabled) return;
    _pendingNetwork.add(r);
    if (_pendingNetwork.length >= _flushThreshold) flush();
  }

  /// 入队一条聚合异常 / Enqueue an aggregated error
  void enqueueError(ErrorRecord e) {
    if (!_enabled) return;
    _pendingErrors.add(e);
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

    final logs = List<LogEntry>.of(_pendingLogs);
    _pendingLogs.clear();
    final nets = List<NetworkRequest>.of(_pendingNetwork);
    _pendingNetwork.clear();
    final errs = List<ErrorRecord>.of(_pendingErrors);
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
    } catch (_) {}
  }

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
  Future<List<LogEntry>> loadLogs({int limit = 500}) async {
    final db = _db;
    if (!_enabled || db == null) return const [];
    try {
      final rows = await db.query('logs', orderBy: 'id DESC', limit: limit);
      return rows.map((r) {
        final levelIndex = (r['level'] as int?) ?? 0;
        return LogEntry(
          id: (r['eid'] as String?) ?? '${r['id']}',
          level: levelIndex >= 0 && levelIndex < LogLevel.values.length
              ? LogLevel.values[levelIndex]
              : LogLevel.verbose,
          message: (r['message'] as String?) ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            (r['ts'] as int?) ?? 0,
          ),
          tag: r['tag'] as String?,
        );
      }).toList();
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
  Future<List<Map<String, dynamic>>> loadNetworkJson({int limit = 500}) async {
    final db = _db;
    if (!_enabled || db == null) return const [];
    try {
      final rows = await db.query('network', orderBy: 'id DESC', limit: limit);
      final out = <Map<String, dynamic>>[];
      for (final r in rows) {
        final data = r['data'] as String?;
        if (data == null) continue;
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) out.add(decoded);
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
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_enabled) await flush();
    try {
      await _db?.close();
    } catch (_) {}
    _db = null;
    _enabled = false;
  }
}
