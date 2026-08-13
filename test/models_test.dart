import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/interceptors/dio_interceptor.dart';
import 'package:zero_inspector_kit/src/models/database_info.dart';
import 'package:zero_inspector_kit/src/models/interceptor_rule.dart';
import 'package:zero_inspector_kit/src/models/leak_record.dart';
import 'package:zero_inspector_kit/src/models/log_entry.dart';
import 'package:zero_inspector_kit/src/models/memory_snapshot.dart';
import 'package:zero_inspector_kit/src/models/network_request.dart';
import 'package:zero_inspector_kit/src/models/route_entry.dart';
import 'package:zero_inspector_kit/src/services/inspector_service.dart';

/// 模型单元测试 / Model unit tests
///
/// 覆盖 8 个核心数据模型的构造、计算属性、工厂方法、规则匹配逻辑
/// Covers construction, computed properties, factory methods, and rule
/// matching logic of 8 core data models
void main() {
  /// =======================================================================
  /// InterceptorRule — 网络拦截规则匹配测试 / InterceptorRule matching tests
  /// =======================================================================
  group('RequestInterceptorRule.matches()', () {
    /// 辅助函数：构造默认规则（只改关键字段）
    /// Helper: build a default rule and override only specific fields
    RequestInterceptorRule buildRule({
      String urlPattern = '',
      String method = '',
      bool enabled = true,
      bool useRegex = false,
    }) {
      return RequestInterceptorRule(
        id: 'r1',
        name: 'test rule',
        urlPattern: urlPattern,
        method: method,
        enabled: enabled,
        useRegex: useRegex,
      );
    }

    test('禁用状态不匹配任何请求 / Disabled rule matches nothing', () {
      final r = buildRule(
        urlPattern: 'https://api.example.com/user',
        method: 'GET',
        enabled: false,
      );
      expect(r.matches('https://api.example.com/user', 'GET'), isFalse);
    });

    test('精确 URL + 精确 Method 匹配 / Exact URL + exact Method match', () {
      final r = buildRule(
        urlPattern: 'https://api.example.com/user/123',
        method: 'GET',
      );
      expect(r.matches('https://api.example.com/user/123', 'GET'), isTrue);
      // URL 完全不同则不匹配 / Different URL should not match
      expect(r.matches('https://api.example.com/user/456', 'GET'), isFalse);
      // Method 完全不同则不匹配 / Different method should not match
      expect(r.matches('https://api.example.com/user/123', 'POST'), isFalse);
    });

    test(
      'Method 通配符（空字符串）匹配所有方法 / Empty method wildcard matches all methods',
      () {
        final r = buildRule(
          urlPattern: 'https://api.example.com/user',
          method: '',
        );
        expect(r.matches('https://api.example.com/user', 'GET'), isTrue);
        expect(r.matches('https://api.example.com/user', 'POST'), isTrue);
        expect(r.matches('https://api.example.com/user', 'DELETE'), isTrue);
      },
    );

    test('Method 匹配忽略大小写 / Method match is case insensitive', () {
      final r = buildRule(
        urlPattern: 'https://api.example.com/user',
        method: 'post',
      );
      expect(r.matches('https://api.example.com/user', 'POST'), isTrue);
      expect(r.matches('https://api.example.com/user', 'Post'), isTrue);
      expect(r.matches('https://api.example.com/user', 'pOST'), isTrue);
    });

    test('URL 正则匹配：前缀匹配 / Regex URL match — prefix', () {
      final r = buildRule(
        urlPattern: r'^https://api\.example\.com/v1/.*',
        useRegex: true,
      );
      expect(r.matches('https://api.example.com/v1/users', 'GET'), isTrue);
      expect(r.matches('https://api.example.com/v2/users', 'GET'), isFalse);
    });

    test('URL 正则匹配：包含子串 / Regex URL match — contains substring', () {
      final r = buildRule(urlPattern: r'/api/v\d+/items/\d+', useRegex: true);
      expect(r.matches('https://host/api/v1/items/7', 'GET'), isTrue);
      expect(r.matches('https://host/api/v2/items/99', 'POST'), isTrue);
      expect(r.matches('https://host/api/items/abc', 'GET'), isFalse);
    });

    test('非法正则表达式安全降级为 false / Invalid regex safely degrades to false', () {
      final r = buildRule(urlPattern: r'[invalid-regex(?', useRegex: true);
      // 不抛出异常，返回 false / Does not throw, returns false
      expect(r.matches('https://api.example.com/anything', 'GET'), isFalse);
    });

    test('空规则（所有字段默认）行为：URL 必须完全相等才匹配 / Empty rule: URL must be exactly equal', () {
      final r = buildRule();
      // method 空（匹配所有方法），但 URL 为空字符串，所以只匹配空 URL
      // Empty method (matches all) but URL is empty, so only matches empty URL
      expect(r.matches('', 'GET'), isTrue);
      expect(r.matches('https://x', 'GET'), isFalse);
    });
  });

  /// InterceptorRule.copyWith — 副本构造测试 / copyWith tests
  group('RequestInterceptorRule.copyWith()', () {
    test('不传参数返回等价对象 / No args returns equivalent object', () {
      final r = RequestInterceptorRule(
        id: 'r1',
        name: 'n1',
        urlPattern: 'https://a.com',
        method: 'GET',
        requestHeaders: {'Authorization': 'Bearer x'},
        responseStatusCode: 418,
      );
      final r2 = r.copyWith();
      expect(r2.id, equals(r.id));
      expect(r2.urlPattern, equals(r.urlPattern));
      expect(r2.method, equals(r.method));
      expect(r2.responseStatusCode, equals(418));
      expect(r2.requestHeaders, equals({'Authorization': 'Bearer x'}));
    });

    test('传入参数覆盖字段 / Args override fields', () {
      final r = RequestInterceptorRule(
        id: 'r1',
        name: 'old',
        urlPattern: 'https://old.com',
      );
      final r2 = r.copyWith(
        name: 'new',
        urlPattern: 'https://new.com',
        enabled: false,
      );
      expect(r2.id, equals('r1')); // ID 未传保留原 ID / ID unchanged
      expect(r2.name, equals('new'));
      expect(r2.urlPattern, equals('https://new.com'));
      expect(r2.enabled, isFalse);
    });
  });

  /// =======================================================================
  /// LogEntry — 日志条目测试 / LogEntry tests
  /// =======================================================================
  group('LogEntry', () {
    test('levelText 缩写正确 / levelText abbreviation is correct', () {
      final ts = DateTime.now();
      expect(
        LogEntry(
          id: '1',
          level: LogLevel.verbose,
          message: '',
          timestamp: ts,
        ).levelText,
        equals('V'),
      );
      expect(
        LogEntry(
          id: '1',
          level: LogLevel.debug,
          message: '',
          timestamp: ts,
        ).levelText,
        equals('D'),
      );
      expect(
        LogEntry(
          id: '1',
          level: LogLevel.info,
          message: '',
          timestamp: ts,
        ).levelText,
        equals('I'),
      );
      expect(
        LogEntry(
          id: '1',
          level: LogLevel.warning,
          message: '',
          timestamp: ts,
        ).levelText,
        equals('W'),
      );
      expect(
        LogEntry(
          id: '1',
          level: LogLevel.error,
          message: '',
          timestamp: ts,
        ).levelText,
        equals('E'),
      );
    });

    test('timestampText 格式化正确 / timestampText format is correct', () {
      final ts = DateTime(2025, 1, 1, 13, 5, 9, 123);
      final e = LogEntry(
        id: '1',
        level: LogLevel.info,
        message: 'x',
        timestamp: ts,
      );
      // HH:mm:ss.mmm 格式，补零正确 / Padded zeros
      expect(e.timestampText, equals('13:05:09.123'));
    });

    test('可选 tag 字段正常工作 / Optional tag field works', () {
      final ts = DateTime.now();
      final withTag = LogEntry(
        id: '1',
        level: LogLevel.info,
        message: 'hi',
        timestamp: ts,
        tag: 'Network',
      );
      final noTag = LogEntry(
        id: '2',
        level: LogLevel.info,
        message: 'hi',
        timestamp: ts,
      );
      expect(withTag.tag, equals('Network'));
      expect(noTag.tag, isNull);
    });
  });

  /// =======================================================================
  /// NetworkRequest — 网络请求模型测试 / NetworkRequest model tests
  /// =======================================================================
  group('NetworkRequest', () {
    test('status getter 默认值为 -1 / status getter defaults to -1', () {
      final r = NetworkRequest(
        id: '1',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 1000,
      );
      expect(r.status, equals(-1));
    });

    test('status getter 读取传入的 statusCode / status getter reads statusCode', () {
      final r = NetworkRequest(
        id: '1',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 1000,
        statusCode: 404,
      );
      expect(r.status, equals(404));
    });

    test('isSuccess 判断 200-299 范围 / isSuccess checks 200-299 range', () {
      final ok = NetworkRequest(
        id: '1',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 1000,
        statusCode: 200,
      );
      final created = NetworkRequest(
        id: '2',
        method: 'POST',
        url: 'https://a.com',
        requestTime: 1000,
        statusCode: 201,
      );
      final notFound = NetworkRequest(
        id: '3',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 1000,
        statusCode: 404,
      );
      final noCode = NetworkRequest(
        id: '4',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 1000,
      );
      final limit = NetworkRequest(
        id: '5',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 1000,
        statusCode: 299,
      );
      final over = NetworkRequest(
        id: '6',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 1000,
        statusCode: 300,
      );
      expect(ok.isSuccess, isTrue);
      expect(created.isSuccess, isTrue);
      expect(limit.isSuccess, isTrue);
      expect(over.isSuccess, isFalse);
      expect(notFound.isSuccess, isFalse);
      expect(noCode.isSuccess, isFalse);
    });

    test('durationText 显示毫秒或秒 / durationText shows ms or seconds', () {
      final noDuration = NetworkRequest(
        id: '1',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 0,
      );
      final ms900 = NetworkRequest(
        id: '2',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 0,
        duration: 900,
      );
      final ms1500 = NetworkRequest(
        id: '3',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 0,
        duration: 1500,
      );
      expect(noDuration.durationText, equals('-'));
      expect(ms900.durationText, equals('900ms'));
      expect(ms1500.durationText, equals('1.50s'));
    });

    test(
      '可选字段（headers/body/responseBody）支持 null / Optional fields support null',
      () {
        final r = NetworkRequest(
          id: '1',
          method: 'GET',
          url: 'https://a.com',
          requestTime: 0,
        );
        expect(r.headers, isNull);
        expect(r.body, isNull);
        expect(r.responseBody, isNull);

        final r2 = NetworkRequest(
          id: '2',
          method: 'POST',
          url: 'https://a.com',
          headers: {'Content-Type': 'application/json'},
          body: {'k': 'v'},
          responseBody: {'ok': true},
          requestTime: 0,
          responseTime: 100,
          duration: 100,
        );
        expect(r2.headers!.length, equals(1));
        expect(r2.body, isA<Map>());
        expect(r2.responseBody, isA<Map>());
      },
    );

    test('isModifiedByInterceptor 默认 false / isModifiedByInterceptor defaults to false', () {
      final r = NetworkRequest(
        id: '1',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 0,
      );
      expect(r.isModifiedByInterceptor, isFalse);
    });

    test('copyWith 可覆盖 isModifiedByInterceptor / copyWith overrides isModifiedByInterceptor', () {
      final r = NetworkRequest(
        id: '1',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 0,
      );
      final modified = r.copyWith(isModifiedByInterceptor: true);
      expect(modified.isModifiedByInterceptor, isTrue);
      // 不传该参数时应保留原值 / omitting keeps the original value
      expect(modified.copyWith().isModifiedByInterceptor, isTrue);
    });

    test('toJson 包含 isModifiedByInterceptor / toJson includes isModifiedByInterceptor', () {
      final r = NetworkRequest(
        id: '1',
        method: 'GET',
        url: 'https://a.com',
        requestTime: 0,
        isModifiedByInterceptor: true,
      );
      expect(r.toJson()['isModifiedByInterceptor'], isTrue);
    });
  });

  /// =======================================================================
  /// RouteEntry — 路由条目模型测试 / RouteEntry model tests
  /// =======================================================================
  group('RouteEntry', () {
    test('actionText 所有枚举值对应正确 / actionText for all enums is correct', () {
      final ts = DateTime.now();
      String action(RouteAction a) => RouteEntry(
        id: '1',
        routeName: '/',
        timestamp: ts,
        action: a,
      ).actionText;

      expect(action(RouteAction.push), equals('Push'));
      expect(action(RouteAction.pop), equals('Pop'));
      expect(action(RouteAction.pushReplacement), equals('Push Replacement'));
      expect(action(RouteAction.popUntil), equals('Pop Until'));
      expect(action(RouteAction.pushNamed), equals('Push Named'));
      expect(action(RouteAction.unknown), equals('Unknown'));
    });

    test('可选 arguments 字段支持 Map / Optional arguments supports Map', () {
      final ts = DateTime.now();
      final r = RouteEntry(
        id: '1',
        routeName: '/detail',
        timestamp: ts,
        action: RouteAction.pushNamed,
        arguments: {'id': 42, 'name': 'test'},
      );
      expect(r.arguments, isNotNull);
      expect(r.arguments!['id'], equals(42));
      expect(r.arguments!['name'], equals('test'));

      final noArgs = RouteEntry(
        id: '2',
        routeName: '/home',
        timestamp: ts,
        action: RouteAction.push,
      );
      expect(noArgs.arguments, isNull);
    });
  });

  /// =======================================================================
  /// DatabaseInfo / TableInfo / ColumnInfo — 数据库模型测试
  /// Database model tests
  /// =======================================================================
  group('DatabaseInfo model family', () {
    test('DatabaseInfo 构造及嵌套表结构正确 / Correct constructor and nested tables', () {
      final db = DatabaseInfo(
        name: 'app.db',
        path: '/data/databases/app.db',
        tables: [
          TableInfo(
            name: 'users',
            rowCount: 100,
            columns: [
              ColumnInfo(name: 'id', type: 'INTEGER'),
              ColumnInfo(name: 'name', type: 'TEXT'),
            ],
          ),
          TableInfo(
            name: 'posts',
            rowCount: 5,
            columns: [
              ColumnInfo(name: 'id', type: 'INTEGER'),
              ColumnInfo(name: 'title', type: 'TEXT'),
              ColumnInfo(name: 'content', type: 'TEXT'),
            ],
          ),
        ],
      );
      expect(db.name, equals('app.db'));
      expect(db.path, equals('/data/databases/app.db'));
      expect(db.tables.length, equals(2));
      expect(db.tables[0].name, equals('users'));
      expect(db.tables[0].rowCount, equals(100));
      expect(db.tables[0].columns.length, equals(2));
      expect(db.tables[0].columns[0].name, equals('id'));
      expect(db.tables[0].columns[1].type, equals('TEXT'));
      expect(db.tables[1].name, equals('posts'));
      expect(db.tables[1].rowCount, equals(5));
      expect(db.tables[1].columns.length, equals(3));
    });

    test(
      'QueryResult rows + columns 正确关联 / QueryResult rows + columns aligned',
      () {
        final q = QueryResult(
          rows: [
            {'id': 1, 'name': 'Alice'},
            {'id': 2, 'name': 'Bob'},
          ],
          columns: const ['id', 'name'],
        );
        expect(q.rows.length, equals(2));
        expect(q.columns.length, equals(2));
        expect(q.rows[0][q.columns[0]], equals(1));
        expect(q.rows[1][q.columns[1]], equals('Bob'));
      },
    );
  });

  /// =======================================================================
  /// MemorySnapshot — 内存快照模型测试 / MemorySnapshot model tests
  /// =======================================================================
  group('MemorySnapshot', () {
    test('processOnly 工厂构造正确 process 快照 / processOnly factory builds process-only snapshot', () {
      final snap = MemorySnapshot.processOnly(50 * 1024 * 1024);
      expect(snap.processRss, equals(50 * 1024 * 1024));
      expect(snap.isHeapDataAvailable, isFalse);
      expect(snap.isNativeDataAvailable, isFalse);
      // Dart Heap 和 Native 字段默认 0 / All Dart / Native fields default to 0
      expect(snap.heapUsage, equals(0));
      expect(snap.totalPss, equals(0));
      expect(snap.physicalFootprint, equals(0));
      // timestamp 自动生成 / auto-generated timestamp
      expect(
        DateTime.now().difference(snap.timestamp).inSeconds.abs(),
        lessThan(2),
      );
    });

    test('withHeapData 工厂构造包含 Dart Heap 数据 / withHeapData factory includes heap data', () {
      final snap = MemorySnapshot.withHeapData(
        processRss: 100 * 1024 * 1024,
        heapUsage: 30 * 1024 * 1024,
        heapCapacity: 60 * 1024 * 1024,
        externalUsage: 5 * 1024 * 1024,
        newSpaceUsage: 2 * 1024 * 1024,
        newSpaceCapacity: 8 * 1024 * 1024,
        newSpaceExternalUsage: 0,
        oldSpaceUsage: 28 * 1024 * 1024,
        oldSpaceCapacity: 52 * 1024 * 1024,
        oldSpaceExternalUsage: 5 * 1024 * 1024,
      );
      expect(snap.isHeapDataAvailable, isTrue);
      expect(snap.processRss, equals(100 * 1024 * 1024));
      expect(snap.heapUsage, equals(30 * 1024 * 1024));
      expect(snap.heapCapacity, equals(60 * 1024 * 1024));
      expect(snap.newSpaceUsage, equals(2 * 1024 * 1024));
      expect(snap.oldSpaceCapacity, equals(52 * 1024 * 1024));
    });

    test(
      'fromNativeMap 正确读取 Android/通用字段 / fromNativeMap reads all native fields',
      () {
        final map = <String, dynamic>{
          // Android 字段 / Android fields
          'totalPss': 4000,
          // 边界值：num 自动转 int / num auto-converted to int
          'dalvikPss': 1000.0,
          'nativePss': 2000,
          'nativePrivateDirty': 1800,
          'dalvikPrivateDirty': 600,
          'totalPrivateDirty': 2500,
          'totalRss': 5000,
          'nativeRss': 2200,
          'dalvikRss': 1200,
          // iOS 字段 / iOS fields
          'physicalFootprint': 6000,
          'internalCompressed': 1000,
          'internalSize': 5500,
          // 设备字段 / Device fields
          'totalMem': 8 * 1024 * 1024 * 1024,
          'availMem': 2 * 1024 * 1024 * 1024,
          'lowMemory': true,
        };
        final snap = MemorySnapshot.fromNativeMap(
          processRss: 512 * 1024,
          map: map,
        );
        expect(snap.processRss, equals(512 * 1024));
        expect(snap.isNativeDataAvailable, isTrue);
        // Android / iOS 字段均读取成功 / Both platforms fields are read
        expect(snap.totalPss, equals(4000));
        expect(snap.dalvikPss, equals(1000));
        expect(snap.nativePrivateDirty, equals(1800));
        expect(snap.physicalFootprint, equals(6000));
        expect(snap.internalCompressed, equals(1000));
        // 设备总内存 8GB，可用 2GB，低内存 true / 8GB total, 2GB avail, low memory
        expect(snap.deviceTotalMem, equals(8 * 1024 * 1024 * 1024));
        expect(snap.deviceAvailMem, equals(2 * 1024 * 1024 * 1024));
        expect(snap.isLowMemory, isTrue);
        // num 类型（1000.0）正确转成 int / num (1000.0) auto-coerced to int
        expect(snap.dalvikPss, equals(1000));
      },
    );

    test(
      'fromNativeMap 缺失字段默认 0/false / Missing fields default to 0/false',
      () {
        final snap = MemorySnapshot.fromNativeMap(
          processRss: 1,
          map: <String, dynamic>{
            // 故意什么都不填 / Intentionally empty
          },
        );
        expect(snap.isNativeDataAvailable, isTrue);
        expect(snap.totalPss, equals(0));
        expect(snap.deviceTotalMem, equals(0));
        expect(snap.isLowMemory, isFalse);
      },
    );

    test('fromNativeMap 读取 isHeapDataAvailable 参数 / fromNativeMap respects isHeapDataAvailable param', () {
      final snap = MemorySnapshot.fromNativeMap(
        processRss: 1,
        map: <String, dynamic>{},
        isHeapDataAvailable: true,
      );
      expect(snap.isHeapDataAvailable, isTrue);
    });

    test('copyWithHeapData 保留 Native 数据并覆盖 Dart Heap / copyWithHeapData preserves Native, overrides Dart Heap', () {
      final native = MemorySnapshot.fromNativeMap(
        processRss: 10000,
        map: <String, dynamic>{
          'totalPss': 8000,
          'nativePss': 4000,
          'lowMemory': true,
          'totalMem': 1024,
          'availMem': 128,
        },
      );
      final merged = native.copyWithHeapData(
        heapUsage: 100,
        heapCapacity: 200,
        externalUsage: 10,
        newSpaceUsage: 20,
        newSpaceCapacity: 50,
        newSpaceExternalUsage: 1,
        oldSpaceUsage: 80,
        oldSpaceCapacity: 150,
        oldSpaceExternalUsage: 9,
        isHeapDataAvailable: true,
      );
      // Native 字段保留 / Native fields preserved
      expect(merged.processRss, equals(10000));
      expect(merged.totalPss, equals(8000));
      expect(merged.nativePss, equals(4000));
      expect(merged.isLowMemory, isTrue);
      expect(merged.deviceTotalMem, equals(1024));
      expect(merged.deviceAvailMem, equals(128));
      expect(merged.isNativeDataAvailable, isTrue);
      // Dart Heap 字段已覆盖 / Dart Heap fields set
      expect(merged.heapUsage, equals(100));
      expect(merged.heapCapacity, equals(200));
      expect(merged.externalUsage, equals(10));
      expect(merged.newSpaceUsage, equals(20));
      expect(merged.oldSpaceCapacity, equals(150));
      expect(merged.isHeapDataAvailable, isTrue);
    });

    test('toJson 返回完整字段 / toJson returns all fields', () {
      final snap = MemorySnapshot.withHeapData(
        processRss: 10,
        heapUsage: 1,
        heapCapacity: 2,
        externalUsage: 3,
        newSpaceUsage: 4,
        newSpaceCapacity: 5,
        newSpaceExternalUsage: 6,
        oldSpaceUsage: 7,
        oldSpaceCapacity: 8,
        oldSpaceExternalUsage: 9,
      );
      final json = snap.toJson();
      // 检查关键字段存在 / Check all key fields present
      expect(json['timestamp'], greaterThan(0));
      expect(json['processRss'], equals(10));
      expect(json['heapUsage'], equals(1));
      expect(json['heapCapacity'], equals(2));
      expect(json['newSpaceCapacity'], equals(5));
      expect(json['oldSpaceUsage'], equals(7));
      expect(json['isHeapDataAvailable'], equals(true));
    });
  });

  /// =======================================================================
  /// LeakRecord — 泄漏记录模型测试 / LeakRecord model tests
  /// =======================================================================
  group('LeakRecord', () {
    /// 构造默认 LeakRecord 的辅助方法 / Helper to build a default LeakRecord
    LeakRecord build({
      Object? target,
      String? tag,
      Duration expectedReleaseAfter = const Duration(seconds: 10),
      LeakStatus status = LeakStatus.tracking,
    }) {
      final realTarget = target ?? Object();
      return LeakRecord(
        objectId: realTarget.hashCode,
        objectType: realTarget.runtimeType.toString(),
        weakRef: WeakReference<Object>(realTarget),
        trackedAt: DateTime.now(),
        expectedReleaseAt: DateTime.now().add(expectedReleaseAfter),
        tag: tag,
        status: status,
      );
    }

    test(
      'displayName 有 tag 时拼接类型 / displayName with tag shows type in parens',
      () {
        final r = build(tag: 'HomeController');
        expect(r.displayName, equals('HomeController (Object)'));
      },
    );

    test(
      'displayName 无 tag 时显示类型 / displayName without tag shows type only',
      () {
        final r = build();
        expect(r.displayName, equals('Object'));
      },
    );

    test(
      'displayName 空字符串 tag 退化为类型 / Empty-string tag degrades to type only',
      () {
        final r = build(tag: '');
        expect(r.displayName, equals('Object'));
      },
    );

    test('未过期时 isExpired=false, overdue=Duration.zero / Not expired: isExpired=false, overdue=Duration.zero', () {
      final r = build(expectedReleaseAfter: const Duration(days: 1));
      expect(r.isExpired, isFalse);
      expect(r.overdue, equals(Duration.zero));
    });

    test(
      '已过期时 isExpired=true, overdue>0 / Expired: isExpired=true, overdue>0',
      () {
        final r = build(
          expectedReleaseAfter: const Duration(milliseconds: -1000),
        );
        expect(r.isExpired, isTrue);
        // overdue 至少 1s 且为正值 / overdue >= 1s and positive
        expect(r.overdue.inMilliseconds, greaterThanOrEqualTo(900));
      },
    );

    test('elapsed 正值 / elapsed value is positive', () {
      final r = build();
      expect(r.elapsed.inMilliseconds, greaterThanOrEqualTo(0));
    });

    test('对象未被 GC 时 isReleased=false / Not GCed: isReleased=false', () {
      final obj = Object();
      final r = build(target: obj);
      expect(r.isReleased, isFalse);
      expect(r.weakRef.target, same(obj));
    });

    test('设置 status 为 leaked 时写入 leakedAt 时间戳 / Setting status=leaked writes leakedAt timestamp', () {
      final r = build(status: LeakStatus.tracking);
      expect(r.leakedAt, isNull);
      final before = DateTime.now();
      r.status = LeakStatus.leaked;
      final after = DateTime.now();
      expect(r.status, equals(LeakStatus.leaked));
      expect(r.leakedAt, isNotNull);
      expect(
        r.leakedAt!.isBefore(after) ||
            r.leakedAt!.millisecondsSinceEpoch == after.millisecondsSinceEpoch,
        isTrue,
      );
      expect(
        r.leakedAt!.isAfter(before) ||
            r.leakedAt!.millisecondsSinceEpoch == before.millisecondsSinceEpoch,
        isTrue,
      );
    });

    test('leakedAt 只写一次 / leakedAt is written only once', () {
      final r = build();
      r.status = LeakStatus.leaked;
      final first = r.leakedAt!;
      // 等待 1ms 再设置 / wait 1ms then re-set
      Future.delayed(const Duration(milliseconds: 2), () {
        r.status = LeakStatus.leaked;
        expect(r.leakedAt, equals(first)); // 时间戳不变 / timestamp unchanged
      });
    });

    test('toString 包含关键字段 / toString contains key fields', () {
      final r = build(tag: 'X');
      final s = r.toString();
      expect(s, contains('X (Object)'));
      expect(s, contains('id='));
      expect(s, contains('tracking'));
    });

    test('所有字段初始化正确 / All fields correctly initialized', () {
      final obj = Object();
      final now = DateTime.now();
      final expectAt = now.add(const Duration(seconds: 30));
      final r = LeakRecord(
        objectId: obj.hashCode,
        objectType: 'MyType',
        weakRef: WeakReference(obj),
        trackedAt: now,
        expectedReleaseAt: expectAt,
        tag: 'custom',
        gcTriggeredAt: now,
        leakedAt: now,
        status: LeakStatus.verifying,
      );
      expect(r.objectId, equals(obj.hashCode));
      expect(r.objectType, equals('MyType'));
      expect(r.tag, equals('custom'));
      expect(r.trackedAt, equals(now));
      expect(r.expectedReleaseAt, equals(expectAt));
      expect(r.gcTriggeredAt, equals(now));
      expect(r.leakedAt, equals(now));
      expect(r.status, equals(LeakStatus.verifying));
    });
  });

  /// =======================================================================
  /// InspectorDioInterceptor — 请求 ID 匹配测试 / Request ID matching tests
  /// =======================================================================
  group('InspectorDioInterceptor request ID matching', () {
    setUp(() {
      InspectorService.instance.clearNetworkRequests();
    });

    tearDown(() {
      InspectorService.instance.clearNetworkRequests();
    });

    test('onResponse 通过 request ID 精确匹配而非 URL / onResponse matches by request ID, not URL', () {
      final interceptor = InspectorDioInterceptor();

      // 模拟两个并发请求到同一 URL / Simulate two concurrent requests to same URL
      interceptor.onRequest({
        'method': 'GET',
        'url': 'https://api.example.com/user',
        'headers': <String, dynamic>{},
        'data': null,
      });
      interceptor.onRequest({
        'method': 'GET',
        'url': 'https://api.example.com/user',
        'headers': <String, dynamic>{},
        'data': null,
      });

      final requests = InspectorService.instance.networkRequests;
      expect(requests.length, equals(2));

      // 获取第一个请求的 ID / Get first request's ID
      final firstRequestId = requests
          .where((r) => r.responseTime == null)
          .last
          .id;

      // 模拟第二个请求先返回（携带同一 URL 但带上 request ID header）
      // Simulate second request responding first (same URL but with request ID header)
      interceptor.onResponse({
        'statusCode': 200,
        'data': 'second response',
        'requestOptions': {
          'uri': 'https://api.example.com/user',
          'method': 'GET',
          'headers': {'x-inspector-request-id': firstRequestId},
        },
      });

      // 应更新正确的请求 / Should update the correct request
      final updated = InspectorService.instance.networkRequests.firstWhere(
        (r) => r.id == firstRequestId,
      );
      expect(updated.responseBody, equals('second response'));
      expect(updated.statusCode, equals(200));
    });

    test('onError 通过 request ID 匹配 / onError matches by request ID', () {
      final interceptor = InspectorDioInterceptor();

      interceptor.onRequest({
        'method': 'POST',
        'url': 'https://api.example.com/login',
        'headers': <String, dynamic>{},
        'data': {'user': 'test'},
      });

      final requests = InspectorService.instance.networkRequests;
      expect(requests.length, equals(1));
      final requestId = requests.first.id;

      interceptor.onError({
        'message': 'Connection refused',
        'response': {'statusCode': 503, 'data': 'Service Unavailable'},
        'requestOptions': {
          'uri': 'https://api.example.com/login',
          'method': 'POST',
          'headers': {'x-inspector-request-id': requestId},
        },
      });

      final updated = InspectorService.instance.networkRequests.firstWhere(
        (r) => r.id == requestId,
      );
      expect(updated.statusCode, equals(503));
      expect(updated.responseBody, equals('Service Unavailable'));
    });
  });

  /// =======================================================================
  /// InspectorService.updateNetworkRequest — responseTime 时机测试
  /// InspectorService.updateNetworkRequest — responseTime timing tests
  /// =======================================================================
  group('InspectorService.updateNetworkRequest responseTime', () {
    setUp(() {
      InspectorService.instance.clearNetworkRequests();
    });

    tearDown(() {
      InspectorService.instance.clearNetworkRequests();
    });

    test('仅更新 body 时不应设置 responseTime / Updating only body must not set responseTime', () {
      final service = InspectorService.instance;
      final requestTime = DateTime.now().millisecondsSinceEpoch;

      // 添加请求 / Add request
      service.addNetworkRequest(
        NetworkRequest(
          id: 'test-1',
          method: 'POST',
          url: 'https://api.example.com/data',
          requestTime: requestTime,
        ),
      );

      // 仅更新请求体（无 statusCode）— 模拟拦截器捕获请求体
      // Update only request body (no statusCode) — simulates interceptor
      // capturing request body
      service.updateNetworkRequest('test-1', body: '{"key":"value"}');

      final request = service.networkRequests.firstWhere(
        (r) => r.id == 'test-1',
      );
      expect(request.body, equals('{"key":"value"}'));
      // 关键断言：responseTime 和 duration 不应被设置
      // Key assertion: responseTime and duration must NOT be set
      expect(
        request.responseTime,
        isNull,
        reason: 'responseTime should not be set when only body is updated',
      );
      expect(
        request.duration,
        isNull,
        reason: 'duration should not be set when only body is updated',
      );
    });

    test('提供 statusCode 时应设置 responseTime / Providing statusCode should set responseTime', () {
      final service = InspectorService.instance;
      final requestTime = DateTime.now().millisecondsSinceEpoch;

      service.addNetworkRequest(
        NetworkRequest(
          id: 'test-2',
          method: 'GET',
          url: 'https://api.example.com/data',
          requestTime: requestTime,
        ),
      );

      // 更新响应（含 statusCode）— 模拟响应到达
      // Update response (with statusCode) — simulates response arrival
      service.updateNetworkRequest(
        'test-2',
        statusCode: 200,
        responseBody: 'ok',
      );

      final request = service.networkRequests.firstWhere(
        (r) => r.id == 'test-2',
      );
      expect(request.statusCode, equals(200));
      expect(request.responseBody, equals('ok'));
      expect(
        request.responseTime,
        isNotNull,
        reason: 'responseTime must be set when statusCode is provided',
      );
      expect(
        request.duration,
        isNotNull,
        reason: 'duration must be set when statusCode is provided',
      );
    });

    test(
      '先更新 body 再更新响应：responseTime 应为响应到达时间 / '
      'Update body then response: responseTime should be response arrival time',
      () {
        final service = InspectorService.instance;
        final requestTime = DateTime.now().millisecondsSinceEpoch;

        service.addNetworkRequest(
          NetworkRequest(
            id: 'test-3',
            method: 'POST',
            url: 'https://api.example.com/data',
            requestTime: requestTime,
          ),
        );

        // 步骤 1：仅更新请求体（HTTP 拦截器在 close() 中调用）
        // Step 1: Update only request body (called by HTTP interceptor in close())
        service.updateNetworkRequest('test-3', body: '{"key":"value"}');

        // 验证中间状态 / Verify intermediate state
        var request = service.networkRequests.firstWhere(
          (r) => r.id == 'test-3',
        );
        expect(
          request.responseTime,
          isNull,
          reason: 'responseTime must be null after body-only update',
        );

        // 步骤 2：响应到达（含 statusCode）
        // Step 2: Response arrives (with statusCode)
        service.updateNetworkRequest(
          'test-3',
          statusCode: 201,
          responseBody: 'created',
        );

        // 验证最终状态 / Verify final state
        request = service.networkRequests.firstWhere((r) => r.id == 'test-3');
        expect(request.statusCode, equals(201));
        expect(request.body, equals('{"key":"value"}'));
        expect(
          request.responseTime,
          isNotNull,
          reason: 'responseTime must be set after response update',
        );
        expect(
          request.duration,
          isNotNull,
          reason: 'duration must be set after response update',
        );
        expect(
          request.duration,
          greaterThanOrEqualTo(0),
          reason: 'duration must be non-negative',
        );
      },
    );
  });

  /// =======================================================================
  /// InspectorDioInterceptor — 并发请求 ID 唯一性测试
  /// InspectorDioInterceptor — concurrent request ID uniqueness tests
  /// =======================================================================
  group('InspectorDioInterceptor concurrent request ID uniqueness', () {
    setUp(() {
      InspectorService.instance.clearNetworkRequests();
    });

    tearDown(() {
      InspectorService.instance.clearNetworkRequests();
    });

    test('同一毫秒内并发请求应生成不同 ID / Concurrent requests in the same millisecond should generate unique IDs', () {
      final interceptor = InspectorDioInterceptor();

      // 快速连续发起多个请求到同一 URL（模拟并发场景）
      // Fire multiple requests to the same URL in rapid succession (concurrent scenario)
      for (var i = 0; i < 20; i++) {
        interceptor.onRequest({
          'method': 'GET',
          'url': 'https://api.example.com/concurrent',
          'headers': <String, dynamic>{},
          'data': null,
        });
      }

      final requests = InspectorService.instance.networkRequests;
      final ids = requests.map((r) => r.id).toList();
      final uniqueIds = ids.toSet();

      // 所有请求 ID 必须唯一 / All request IDs must be unique
      expect(
        uniqueIds.length,
        equals(ids.length),
        reason:
            'Concurrent requests must have unique IDs. '
            'Got ${ids.length} requests but only ${uniqueIds.length} unique IDs. '
            'Duplicate IDs would cause response data to be associated with the wrong request.',
      );
    });
  });
}
