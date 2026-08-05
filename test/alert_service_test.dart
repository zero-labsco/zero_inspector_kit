import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/log_entry.dart';
import 'package:zero_inspector_kit/src/models/network_request.dart';
import 'package:zero_inspector_kit/src/services/alert_service.dart';

/// AlertService 单元测试 / AlertService unit tests
///
/// 重点覆盖 v1.3.0 新增的告警系统：节流、防风暴、规则评估、生命周期。
/// 主要聚焦在「告警风暴」防御：高频检查下同一来源不应淹没缓冲。
/// Focus on the v1.3.0 alert system: throttling, anti-storm, rule
/// evaluation, lifecycle. Especially storm prevention: high-frequency
/// checks on the same source must not flood the buffer.
void main() {
  late AlertService alerts;

  setUp(() {
    // 告警服务是单例；测试间显式清空避免相互污染
    // AlertService is a singleton; explicitly clear between tests.
    alerts = AlertService.instance;
    alerts.clearAll();
  });

  tearDown(() {
    alerts.clearAll();
  });

  group('Lifecycle / 生命周期', () {
    test('default rules are present / 默认规则已注册', () {
      expect(alerts.rules, isNotEmpty);
      expect(
        alerts.rules.any((r) => r.kind.toString().contains('httpStatus')),
        isTrue,
      );
      expect(
        alerts.rules.any((r) => r.kind.toString().contains('memoryMb')),
        isTrue,
      );
      expect(
        alerts.rules.any((r) => r.kind.toString().contains('fpsLow')),
        isTrue,
      );
    });

    test('initial unread count is 0 / 初始未读数为 0', () {
      expect(alerts.unreadCount.value, equals(0));
      expect(alerts.events, isEmpty);
    });

    test('clearAll resets events and unread / clearAll 重置事件与未读', () {
      alerts.checkMemory(999);
      expect(alerts.unreadCount.value, greaterThan(0));
      alerts.clearAll();
      expect(alerts.events, isEmpty);
      expect(alerts.unreadCount.value, equals(0));
    });
  });

  group('Storm prevention / 防风暴节流', () {
    test(
      'memory above threshold fires only once per cooldown window '
      'under rapid checks / 高频检测下内存告警每秒最多 1 条',
      () {
        for (var i = 0; i < 1000; i++) {
          alerts.checkMemory(500);
        }
        // 1000 次调用落在同一毫秒内 → 只产生 1 条告警
        expect(alerts.events.length, equals(1));
        expect(alerts.unreadCount.value, equals(1));
        expect(alerts.events.first.source, equals('memory'));
      },
    );

    test(
      'low FPS fires only once per cooldown window under rapid checks '
      '/ 高频检测下 FPS 告警每秒最多 1 条',
      () {
        for (var i = 0; i < 500; i++) {
          alerts.checkFps(20);
        }
        expect(alerts.events.length, equals(1));
        expect(alerts.unreadCount.value, equals(1));
        expect(alerts.events.first.source, equals('fps'));
      },
    );

    test(
      'same slow URL does not flood the buffer / 同一慢请求 URL 不刷屏',
      () {
        final req = NetworkRequest(
          id: 'r1',
          method: 'GET',
          url: 'https://api.example.com/slow',
          requestTime: 0,
          responseTime: 5000,
          statusCode: 200,
          duration: 5000,
        );
        for (var i = 0; i < 200; i++) {
          alerts.checkNetwork(req);
        }
        // 同 URL + 持续超阈值：被节流到 1 条
        expect(alerts.events.length, equals(1));
        expect(alerts.unreadCount.value, equals(1));
      },
    );

    test(
      'different sources fire independently / 不同来源互不影响',
      () {
        alerts.checkMemory(500);
        alerts.checkFps(20);
        alerts.checkNetwork(
          NetworkRequest(
            id: 'r1',
            method: 'GET',
            url: 'https://api.example.com/a',
            requestTime: 0,
            statusCode: 500,
            duration: 0,
          ),
        );
        expect(alerts.events.length, equals(3));
        expect(alerts.unreadCount.value, equals(3));
      },
    );

    test(
      'after cooldown elapses, same source can fire again '
      '/ 冷却结束后同来源可再次触发',
      () {
        alerts.checkMemory(500);
        expect(alerts.events.length, equals(1));
        // 模拟冷却结束：手动复用 _fire 的内部节流表无法直接测试，
        // 但可通过 clearAll 验证节流状态被清理后能再次触发。
        alerts.clearAll();
        alerts.checkMemory(500);
        expect(alerts.events.length, equals(1));
        expect(alerts.unreadCount.value, equals(1));
      },
    );

    test(
      'single request hitting both 5xx and slow rules fires both alerts '
      '/ 单次请求同时命中 5xx 与慢请求规则时两条告警都触发',
      () {
        final req = NetworkRequest(
          id: 'r1',
          method: 'GET',
          url: 'https://api.example.com/both',
          requestTime: 0,
          responseTime: 5000,
          statusCode: 500,
          duration: 5000,
        );
        // 同 source 但不同 message 应互不影响
        alerts.checkNetwork(req);
        expect(alerts.events.length, equals(2));
        expect(
          alerts.events.any((e) => e.message.contains('HTTP 500')),
          isTrue,
        );
        expect(
          alerts.events.any((e) => e.message.contains('Slow')),
          isTrue,
        );
      },
    );
  });

  group('Rule evaluation / 规则评估', () {
    test(
      'requests below thresholds do not fire / 未越过阈值的请求不触发',
      () {
        alerts.checkNetwork(
          NetworkRequest(
            id: 'r1',
            method: 'GET',
            url: 'https://api.example.com/ok',
            requestTime: 0,
            statusCode: 200,
            duration: 50,
          ),
        );
        expect(alerts.events, isEmpty);
        expect(alerts.unreadCount.value, equals(0));
      },
    );

    test(
      'non-ERROR log level does not fire / 非 ERROR 日志不触发',
      () {
        final entry = LogEntry(
          id: 'l1',
          level: LogLevel.info,
          message: 'hello',
          timestamp: DateTime.now(),
        );
        alerts.checkLog(entry);
        expect(alerts.events, isEmpty);
      },
    );

    test(
      'ERROR log fires / ERROR 日志触发告警',
      () {
        final entry = LogEntry(
          id: 'l1',
          level: LogLevel.error,
          message: 'boom',
          timestamp: DateTime.now(),
          tag: 'auth',
        );
        alerts.checkLog(entry);
        expect(alerts.events.length, equals(1));
        expect(alerts.events.first.source, equals('auth'));
      },
    );
  });
}
