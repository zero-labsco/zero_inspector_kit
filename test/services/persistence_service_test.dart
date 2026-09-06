import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// 持久化环形缓冲的真实数据库单元测试：在主机上通过 sqflite_common_ffi 跑通
/// 「入队 → 刷盘 → 按行数上限/保留时长滚动裁剪 → 读取/清空」的完整链路，
/// 验证跨重启不丢（磁盘环形缓冲）的核心语义。
/// Real-DB unit test for the persistence ring buffer: runs the full
/// enqueue → flush → ring trim (row cap + retention) → read/clear chain on the
/// host via sqflite_common_ffi, verifying the "survives restart" semantics.

/// 测试用每表行数上限（环形缓冲裁剪线）/ Row cap per table used in tests
const int _cap = 20;

/// 测试用保留时长 / Retention window used in tests
const Duration _retention = Duration(hours: 1);

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // 用独立临时目录承载数据库，避免污染开发机默认库目录。
    // Use an isolated temp dir so tests never touch the default DB location.
    final tempDir = await Directory.systemTemp.createTemp(
      'zik_persistence_test_',
    );
    await databaseFactory.setDatabasesPath(tempDir.path);
    // 单例只在首次 init 生效，因此容量/保留策略在文件级一次配好，测试通过
    // 显式 flush() 驱动落盘（定时器拉长，避免与用例并发干扰）。
    // The singleton only honors its first init(), so cap/retention are fixed
    // at file level; tests drive flushes explicitly (timer kept long).
    await PersistenceService.instance.init(
      maxRowsPerTable: _cap,
      retention: _retention,
      flushInterval: const Duration(minutes: 5),
    );
  });

  // 每例前清空磁盘，保证独立、可预期 / Blank disk before every case.
  setUp(() async {
    await PersistenceService.instance.clearAll();
  });

  tearDownAll(() async {
    await PersistenceService.instance.dispose();
  });

  LogEntry makeLog(int i, {DateTime? at}) => LogEntry(
    id: 'log-$i',
    level: LogLevel.info,
    message: 'message $i',
    timestamp: at ?? DateTime.now().add(Duration(milliseconds: i)),
    tag: 'test',
  );

  ErrorRecord makeError(int i) {
    final now = DateTime.now().add(Duration(milliseconds: i));
    return ErrorRecord(
      id: 'err-$i',
      type: 'DemoException',
      message: 'boom $i',
      stackSignature: 'stack $i',
      count: 3,
      firstSeen: now,
      lastSeen: now,
    );
  }

  NetworkRequest makeNetwork(int i) => NetworkRequest(
    id: 'net-$i',
    method: 'GET',
    url: 'https://example.com/api/$i',
    requestTime: DateTime.now().millisecondsSinceEpoch + i,
    statusCode: 200,
  );

  test('入队并 flush 后日志落盘且最新在前 / flush persists logs newest-first', () async {
    final svc = PersistenceService.instance;
    for (var i = 1; i <= 3; i++) {
      svc.enqueueLog(makeLog(i));
    }
    await svc.flush();
    final logs = await svc.loadLogs(limit: 100);
    expect(logs.map((l) => l.id), ['log-3', 'log-2', 'log-1']);
    expect(logs.first.message, 'message 3');
    expect(logs.first.tag, 'test');
  });

  test(
    '环形缓冲按行数上限裁掉最旧 / ring buffer evicts the oldest beyond the cap',
    () async {
      final svc = PersistenceService.instance;
      for (var i = 1; i <= _cap + 5; i++) {
        svc.enqueueLog(makeLog(i));
      }
      await svc.flush();
      final logs = await svc.loadLogs(limit: 1000);
      expect(logs.length, _cap);
      // 最新保留 / Newest retained
      expect(logs.first.id, 'log-${_cap + 5}');
      // 最旧 5 条被裁掉 / The oldest 5 are evicted
      expect(logs.last.id, 'log-6');
      expect(logs.any((l) => l.id == 'log-1'), isFalse);
    },
  );

  test(
    '超出保留时长的最旧记录被清除 / rows older than the retention window are purged',
    () async {
      final svc = PersistenceService.instance;
      svc.enqueueLog(
        makeLog(1, at: DateTime.now().subtract(const Duration(hours: 2))),
      );
      svc.enqueueLog(makeLog(2, at: DateTime.now()));
      await svc.flush();
      final logs = await svc.loadLogs(limit: 100);
      expect(logs.length, 1);
      expect(logs.first.id, 'log-2');
    },
  );

  test(
    '聚合异常同样落盘、保留聚合次数 / aggregated errors persist with their count',
    () async {
      final svc = PersistenceService.instance;
      for (var i = 1; i <= _cap + 5; i++) {
        svc.enqueueError(makeError(i));
      }
      await svc.flush();
      final errs = await svc.loadErrors(limit: 1000);
      expect(errs.length, _cap);
      expect(errs.first.id, 'err-${_cap + 5}');
      expect(errs.first.count, 3);
      expect(errs.first.type, 'DemoException');
      // 最旧 5 条被裁掉 / The oldest 5 are evicted
      expect(errs.last.id, 'err-6');
    },
  );

  test(
    '网络记录落盘并能按原始 JSON 读回 / network rows persist and read back as JSON',
    () async {
      final svc = PersistenceService.instance;
      for (var i = 1; i <= 3; i++) {
        svc.enqueueNetwork(makeNetwork(i));
      }
      await svc.flush();
      final nets = await svc.loadNetworkJson(limit: 100);
      expect(nets.length, 3);
      expect(nets.first['id'], 'net-3');
      expect(nets.first['method'], 'GET');
      expect(nets.first['statusCode'], 200);
    },
  );

  test(
    'clearAll 同时清空磁盘与未刷盘队列 / clearAll wipes disk and the pending queue',
    () async {
      final svc = PersistenceService.instance;
      svc.enqueueLog(makeLog(1));
      await svc.flush();
      expect((await svc.loadLogs()).length, 1);
      // 一条仍停留在待刷队列中 / One row left pending in memory
      svc.enqueueLog(makeLog(2));
      await svc.clearAll();
      expect((await svc.loadLogs()).length, 0);
      // 清空后再 flush，待刷队列不应“复活”旧数据 / Flushing after clear must not resurrect data
      await svc.flush();
      expect((await svc.loadLogs()).length, 0);
    },
  );

  test(
    '完整会话存档 JSON 含三类数据 / full-session archive JSON contains all sections',
    () async {
      final svc = PersistenceService.instance;
      svc.enqueueLog(makeLog(1));
      svc.enqueueNetwork(makeNetwork(1));
      svc.enqueueError(makeError(1));
      final json = await svc.buildSessionArchiveJson();
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      expect(decoded['logs'], isNotEmpty);
      expect(decoded['network'], isNotEmpty);
      expect(decoded['errors'], isNotEmpty);
      expect(decoded['errors'][0]['count'], 3);
    },
  );
}
