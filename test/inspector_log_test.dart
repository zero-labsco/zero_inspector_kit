import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/interceptors/log_interceptor.dart';
import 'package:zero_inspector_kit/src/models/log_entry.dart';
import 'package:zero_inspector_kit/src/services/inspector_service.dart';
import 'package:zero_inspector_kit/src/utils/inspector_log.dart';

/// InspectorLog 简化 API 单元测试 / InspectorLog simplified API unit tests
///
/// 验证 `InspectorLog.xxx` 静态方法正确委托到 `InspectorLogInterceptor.instance`
/// Verifies `InspectorLog.xxx` static methods correctly delegate to
/// `InspectorLogInterceptor.instance`
void main() {
  /// 每个测试前停止并清空 / Stop and clear before each test
  setUp(() {
    InspectorLog.stop();
    InspectorService.instance.clearLogs();
  });

  /// 每个测试后清理 / Cleanup after each test
  tearDown(() {
    InspectorLog.stop();
    InspectorService.instance.clearLogs();
    InspectorLogInterceptor.instance.onLogCaptured = null;
  });

  /// ========================================================================
  /// 生命周期 / Lifecycle
  /// ========================================================================
  group('InspectorLog lifecycle', () {
    test('初始状态未运行 / Initial state is not running', () {
      expect(InspectorLog.isRunning, isFalse);
    });

    test('start 后 isRunning 为 true / isRunning is true after start', () {
      InspectorLog.start();
      expect(InspectorLog.isRunning, isTrue);
    });

    test('stop 后 isRunning 为 false / isRunning is false after stop', () {
      InspectorLog.start();
      InspectorLog.stop();
      expect(InspectorLog.isRunning, isFalse);
    });
  });

  /// ========================================================================
  /// 简写日志级别 / Shorthand log levels
  /// ========================================================================
  group('InspectorLog shorthand methods', () {
    test('v() 添加 Verbose 级别日志 / v() adds verbose log', () {
      InspectorLog.start();
      InspectorLog.v('verbose msg', tag: 'TagV');
      final logs = InspectorService.instance.logEntries;
      expect(logs.length, equals(1));
      expect(logs[0].level, equals(LogLevel.verbose));
      expect(logs[0].message, equals('verbose msg'));
      expect(logs[0].tag, equals('TagV'));
    });

    test('d() 添加 Debug 级别日志 / d() adds debug log', () {
      InspectorLog.start();
      InspectorLog.d('debug msg');
      expect(
        InspectorService.instance.logEntries[0].level,
        equals(LogLevel.debug),
      );
    });

    test('i() 添加 Info 级别日志 / i() adds info log', () {
      InspectorLog.start();
      InspectorLog.i('info msg');
      expect(
        InspectorService.instance.logEntries[0].level,
        equals(LogLevel.info),
      );
    });

    test('w() 添加 Warning 级别日志 / w() adds warning log', () {
      InspectorLog.start();
      InspectorLog.w('warning msg');
      expect(
        InspectorService.instance.logEntries[0].level,
        equals(LogLevel.warning),
      );
    });

    test('e() 添加 Error 级别日志 / e() adds error log', () {
      InspectorLog.start();
      InspectorLog.e('error msg');
      expect(
        InspectorService.instance.logEntries[0].level,
        equals(LogLevel.error),
      );
    });
  });

  /// ========================================================================
  /// 通用 log 方法 / Generic log method
  /// ========================================================================
  group('InspectorLog.log()', () {
    test('log() 按指定级别添加日志 / log() adds log with specified level', () {
      InspectorLog.start();
      InspectorLog.log(LogLevel.error, 'generic error', tag: 'Generic');
      final entry = InspectorService.instance.logEntries[0];
      expect(entry.level, equals(LogLevel.error));
      expect(entry.message, equals('generic error'));
      expect(entry.tag, equals('Generic'));
    });
  });

  /// ========================================================================
  /// onLogCaptured 委托 / onLogCaptured delegation
  /// ========================================================================
  group('InspectorLog.onLogCaptured', () {
    test('设置回调后添加日志会触发回调 / Setting callback triggers it when log added', () {
      InspectorLog.start();
      LogEntry? captured;
      InspectorLog.onLogCaptured = (entry) {
        captured = entry;
      };
      InspectorLog.i('captured msg');
      expect(captured, isNotNull);
      expect(captured!.message, equals('captured msg'));
      expect(captured!.level, equals(LogLevel.info));
    });
  });

  /// ========================================================================
  /// 与底层拦截器行为一致性 / Consistency with underlying interceptor
  /// ========================================================================
  group('Consistency with InspectorLogInterceptor', () {
    test('未 start 时添加日志不会记录 / Log not recorded when not started', () {
      InspectorLog.i('not started');
      expect(InspectorService.instance.logEntries, isEmpty);
    });

    test(
      'InspectorLog 与直接调用底层产生相同级别 / InspectorLog produces same level as direct interceptor call',
      () {
        InspectorLog.start();
        InspectorLog.w('shortcut');
        InspectorLogInterceptor.instance.warning('direct');
        final logs = InspectorService.instance.logEntries;
        expect(logs.length, equals(2));
        expect(logs[0].level, equals(LogLevel.warning));
        expect(logs[1].level, equals(LogLevel.warning));
      },
    );
  });
}
