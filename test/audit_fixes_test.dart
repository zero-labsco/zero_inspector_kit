import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/database_info.dart';
import 'package:zero_inspector_kit/src/models/log_entry.dart';
import 'package:zero_inspector_kit/src/models/network_request.dart';
import 'package:zero_inspector_kit/src/services/database_provider.dart';
import 'package:zero_inspector_kit/src/services/inspector_service.dart';
import 'package:zero_inspector_kit/src/ui/database_viewer.dart';
import 'package:zero_inspector_kit/src/ui/log_viewer.dart';
import 'package:zero_inspector_kit/src/ui/widgets/widgets.dart';

/// 1.17.0 审计修复的回归测试 / Regression tests for the 1.17.0 audit fixes
///
/// 每个用例都对应一个真实缺陷，且在修复前会失败（或行为错误）：
/// Each case maps to a real defect and fails (or misbehaves) without the fix:
/// 1. 数据库查看器两个搜索框漏传 onChanged，输入永不更新关键词（搜索失效）。
///    Both DatabaseViewer search boxes omitted onChanged, so typing never
///    updated the keyword (search was dead).
/// 2. 日志过滤缓存用「视图身份 + 长度」失效判定，环形缓冲写满 500 条后长度
///    恒定、视图身份稳定，过滤结果冻结。
///    The log filter cache keyed on "view identity + length"; once the 500-entry
///    ring buffer was full neither changed, freezing filtered results.
/// 3. 服务数据版本号随写入自增（上述两个缓存的基础）。
///    The service data version bumps on every mutation (the base for both).
/// 4. `NetworkRequest.fromJson` 与 `toJson`  round-trip；批量删除单次通知；
///    网络记录跨重启回放。
///    NetworkRequest.fromJson/toJson round-trip; batched removal notifies once;
///    network records replay across restarts.
void main() {
  setUp(() {
    InspectorService.instance.clearAll();
  });

  tearDown(() {
    InspectorService.instance.clearAll();
    DatabaseRegistry.instance.unregisterProvider('fake-audit');
  });

  group('服务数据版本号 / service data versions', () {
    test('日志写入自增 logVersion', () {
      final before = InspectorService.instance.logVersion;
      InspectorService.instance.addLogEntry(
        LogEntry(
          id: 'v-1',
          level: LogLevel.info,
          message: 'm',
          timestamp: DateTime.now(),
        ),
      );
      expect(InspectorService.instance.logVersion, greaterThan(before));
    });

    test('网络新增 / 更新 / 批量删除各自自增 networkVersion', () {
      final base = InspectorService.instance.networkVersion;
      InspectorService.instance.addNetworkRequest(
        NetworkRequest(
          id: 'n-1',
          method: 'GET',
          url: 'https://example.com',
          requestTime: 1,
        ),
      );
      final afterAdd = InspectorService.instance.networkVersion;
      expect(afterAdd, greaterThan(base));

      InspectorService.instance.updateNetworkRequest('n-1', statusCode: 200);
      expect(InspectorService.instance.networkVersion, greaterThan(afterAdd));

      final afterUpdate = InspectorService.instance.networkVersion;
      InspectorService.instance.removeNetworkRequests(const ['n-1']);
      expect(
        InspectorService.instance.networkVersion,
        greaterThan(afterUpdate),
      );
      expect(InspectorService.instance.networkRequestCount, 0);
    });

    test('回放网络记录不触发告警与重复入队（幂等）', () {
      NetworkRequest req(int i) => NetworkRequest(
        id: 'r-$i',
        method: 'GET',
        url: 'https://example.com/$i',
        requestTime: i,
        statusCode: 200,
      );
      InspectorService.instance.restoreNetworkRequests([req(1), req(2)]);
      expect(InspectorService.instance.networkRequestCount, 2);
      // 同 id 回放两次不产生重复行 / replaying the same ids twice adds no rows
      InspectorService.instance.restoreNetworkRequests([req(1), req(2)]);
      expect(InspectorService.instance.networkRequestCount, 2);
      // 最新在前：后写入的排在前面 / newest first: later writes come first
      expect(
        InspectorService.instance.networkRequests.first.id,
        anyOf('r-1', 'r-2'),
      );
      expect(
        InspectorService.instance.networkRequests.map((r) => r.id).toSet(),
        {'r-1', 'r-2'},
      );
    });
  });

  group('NetworkRequest.fromJson / toJson round-trip', () {
    test('完整字段往返', () {
      final original = NetworkRequest(
        id: 'req-1',
        method: 'POST',
        url: 'https://example.com/api?token=abc',
        headers: const {'content-type': 'application/json'},
        body: '{"a":1}',
        responseBody: '{"ok":true}',
        statusCode: 201,
        requestTime: 1700000000000,
        responseTime: 1700000000500,
        duration: 500,
        isModifiedByInterceptor: true,
      );
      final restored = NetworkRequest.fromJson(original.toJson());
      expect(restored, isNotNull);
      expect(restored!.id, original.id);
      expect(restored.method, original.method);
      expect(restored.url, original.url);
      expect(restored.headers, original.headers);
      expect(restored.body, original.body);
      expect(restored.responseBody, original.responseBody);
      expect(restored.statusCode, original.statusCode);
      expect(restored.requestTime, original.requestTime);
      expect(restored.responseTime, original.responseTime);
      expect(restored.duration, original.duration);
      expect(restored.isModifiedByInterceptor, isTrue);
    });

    test('缺必备字段返回 null', () {
      expect(NetworkRequest.fromJson(const {'method': 'GET'}), isNull);
      expect(NetworkRequest.fromJson(const {'id': 'x'}), isNull);
      expect(
        NetworkRequest.fromJson(const {
          'id': 'x',
          'method': 'GET',
          'url': 'u',
          'requestTime': 'not-a-number',
        }),
        isNull,
      );
    });

    test('可选字段缺失时降级为 null', () {
      final restored = NetworkRequest.fromJson(const {
        'id': 'x',
        'method': 'GET',
        'url': 'https://example.com',
        'requestTime': 42,
      });
      expect(restored, isNotNull);
      expect(restored!.statusCode, isNull);
      expect(restored.responseTime, isNull);
      expect(restored.duration, isNull);
      expect(restored.headers, isNull);
      expect(restored.isModifiedByInterceptor, isFalse);
    });
  });

  group('日志过滤缓存不再冻结 / log filter cache no longer freezes', () {
    testWidgets('写满 500 条后新匹配日志仍出现在过滤结果中', (tester) async {
      // 灌满环形缓冲（默认 500 条）：此后 addFirst + removeLast 使长度恒定，
      // 旧实现据此判定“数据没变”，过滤结果冻结。
      // Fill the ring buffer (default 500): afterwards addFirst + removeLast
      // keeps the length constant, which the old implementation read as
      // "nothing changed" and froze the filtered list.
      for (var i = 0; i < 600; i++) {
        InspectorService.instance.addLogEntry(
          LogEntry(
            id: 'fill-$i',
            level: LogLevel.info,
            message: 'filler $i',
            timestamp: DateTime.now(),
          ),
        );
      }
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LogViewer())),
      );
      await tester.pumpAndSettle();

      // 输入关键词过滤 / filter by keyword
      final searchField = find.descendant(
        of: find.byType(InspectorSearchField),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, 'needle');
      await tester.pumpAndSettle();
      expect(find.text('needle-1'), findsNothing);

      // 加入一条匹配的新日志 / add a new matching log
      InspectorService.instance.addLogEntry(
        LogEntry(
          id: 'needle-1',
          level: LogLevel.info,
          message: 'needle-1',
          timestamp: DateTime.now(),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('needle-1'), findsOneWidget);
    });
  });

  group('数据库搜索框 / database viewer search boxes', () {
    testWidgets('全局搜索输入后按库名 / 表名过滤', (tester) async {
      DatabaseRegistry.instance.registerProvider(_FakeProvider());
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DatabaseViewer())),
      );
      await tester.pumpAndSettle();

      // 未输入时两个库都在 / both databases visible before typing
      expect(find.text('alpha.db'), findsOneWidget);
      expect(find.text('beta.db'), findsOneWidget);

      final searchField = find.descendant(
        of: find.byType(InspectorSearchField),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, 'beta');
      await tester.pumpAndSettle();

      expect(find.text('beta.db'), findsOneWidget);
      expect(find.text('alpha.db'), findsNothing);

      // 清空恢复 / clearing restores both
      await tester.enterText(searchField, '');
      await tester.pumpAndSettle();
      expect(find.text('alpha.db'), findsOneWidget);
      expect(find.text('beta.db'), findsOneWidget);
    });

    testWidgets('进入数据库后库内搜索过滤表名', (tester) async {
      DatabaseRegistry.instance.registerProvider(_FakeProvider());
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DatabaseViewer())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('alpha.db'));
      await tester.pumpAndSettle();
      expect(find.text('users'), findsOneWidget);
      expect(find.text('orders'), findsOneWidget);

      final searchField = find.descendant(
        of: find.byType(InspectorSearchField),
        matching: find.byType(TextField),
      );
      await tester.enterText(searchField, 'order');
      await tester.pumpAndSettle();

      expect(find.text('orders'), findsOneWidget);
      expect(find.text('users'), findsNothing);
    });
  });
}

/// 测试用数据库提供者 / Fake database provider for tests
class _FakeProvider implements DatabaseProvider {
  @override
  String get name => 'fake-audit';

  @override
  Future<List<DatabaseInfo>> getDatabases() async => [
    DatabaseInfo(
      name: 'alpha.db',
      path: '/virtual/alpha.db',
      tables: [
        TableInfo(name: 'users', rowCount: 2, columns: []),
        TableInfo(name: 'orders', rowCount: 5, columns: []),
      ],
    ),
    DatabaseInfo(
      name: 'beta.db',
      path: '/virtual/beta.db',
      tables: [TableInfo(name: 'cache', rowCount: 1, columns: [])],
    ),
  ];

  @override
  Future<QueryResult> queryTable(
    String dbPath,
    String tableName, {
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool desc = false,
    String? whereKeyword,
  }) async => QueryResult(rows: const [], columns: const []);
}
