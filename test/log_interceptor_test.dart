import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/interceptors/log_interceptor.dart';
import 'package:zero_inspector_kit/src/models/log_entry.dart';
import 'package:zero_inspector_kit/src/services/inspector_service.dart';

/// 日志拦截器单元测试 / Log interceptor unit tests
///
/// 覆盖 detectLogLevel 级别识别、captureLog 捕获逻辑、
/// 重入保护（_isCapturing）、start/stop 状态控制等关键功能
/// Covers detectLogLevel level detection, captureLog capture logic,
/// reentrance guard (_isCapturing), and start/stop state control
void main() {
  /// 每个测试前重置状态 / Reset state before each test
  setUp(() {
    // 停止拦截器并清空日志，避免测试间互相污染
    // Stop interceptor and clear logs to avoid cross-test contamination
    InspectorLogInterceptor.instance.stop();
    InspectorService.instance.clearLogs();
    InspectorLogInterceptor.instance.onLogCaptured = null;
  });

  /// 每个测试后清理 / Cleanup after each test
  tearDown(() {
    InspectorLogInterceptor.instance.stop();
    InspectorService.instance.clearLogs();
    InspectorLogInterceptor.instance.onLogCaptured = null;
  });

  /// =======================================================================
  /// detectLogLevel — 日志级别识别测试 / detectLogLevel detection tests
  /// =======================================================================
  group('InspectorLogInterceptor.detectLogLevel()', () {
    /// 辅助函数：快速调用单例的 detectLogLevel
    /// Helper: quickly call singleton's detectLogLevel
    LogLevel detect(String msg) =>
        InspectorLogInterceptor.instance.detectLogLevel(msg);

    test('纯文本默认返回 Info / Plain text defaults to Info', () {
      expect(detect('hello world'), equals(LogLevel.info));
      expect(detect(''), equals(LogLevel.info));
      expect(detect('   '), equals(LogLevel.info));
    });

    test('单字母方括号标记（V/D/I/W/E）/ Single-letter bracket markers', () {
      expect(detect('[V] verbose msg'), equals(LogLevel.verbose));
      expect(detect('[D] debug msg'), equals(LogLevel.debug));
      expect(detect('[I] info msg'), equals(LogLevel.info));
      expect(detect('[W] warning msg'), equals(LogLevel.warning));
      expect(detect('[E] error msg'), equals(LogLevel.error));
    });

    test('全拼写方括号标记 / Full-name bracket markers', () {
      expect(detect('[VERBOSE] xxx'), equals(LogLevel.verbose));
      expect(detect('[DEBUG] xxx'), equals(LogLevel.debug));
      expect(detect('[INFO] xxx'), equals(LogLevel.info));
      expect(detect('[WARNING] xxx'), equals(LogLevel.warning));
      expect(detect('[WARN] xxx'), equals(LogLevel.warning));
      expect(detect('[ERROR] xxx'), equals(LogLevel.error));
      expect(detect('[ERR] xxx'), equals(LogLevel.error));
    });

    test('TRACE/FATAL/CRITICAL 特殊标记 / TRACE, FATAL, CRITICAL markers', () {
      // [T] = VERBOSE
      expect(detect('[T] trace msg'), equals(LogLevel.verbose));
      // [F]/[FATAL]/[CRITICAL] = ERROR
      expect(detect('[F] fatal msg'), equals(LogLevel.error));
      expect(detect('[FATAL] xxx'), equals(LogLevel.error));
      expect(detect('[CRITICAL] xxx'), equals(LogLevel.error));
    });

    test('方括号级别前缀忽略大小写 / Bracket prefix case insensitive', () {
      expect(detect('[d] lower debug'), equals(LogLevel.debug));
      expect(detect('[Debug] mixed case'), equals(LogLevel.debug));
      expect(detect('[info] lower info'), equals(LogLevel.info));
      expect(detect('[Warning] mixed warn'), equals(LogLevel.warning));
    });

    test('前后空白不影响识别 / Leading/trailing whitespace ignored', () {
      expect(detect('  [D]  padded  '), equals(LogLevel.debug));
      expect(detect('\t[E]\ttabbed\t'), equals(LogLevel.error));
    });

    test('去除 ANSI 颜色代码后识别级别 / Strip ANSI codes then detect', () {
      // 常见 logger 库 ANSI 前缀格式 / Common logger library ANSI prefix format
      const ansiDebug = '\x1B[34m[D] debug colored\x1B[0m';
      const ansiError = '\x1B[1;31m[ERROR] fail\x1B[0m';
      const ansiWarn = '\x1B[33m[W] attention\x1B[0m';
      expect(detect(ansiDebug), equals(LogLevel.debug));
      expect(detect(ansiError), equals(LogLevel.error));
      expect(detect(ansiWarn), equals(LogLevel.warning));
    });

    test('未知方括号内容退化为 Info / Unknown bracket content degrades to Info', () {
      expect(detect('[UNKNOWN] msg'), equals(LogLevel.info));
      expect(detect('[CUSTOM] msg'), equals(LogLevel.info));
      expect(detect('[123] msg'), equals(LogLevel.info));
    });

    test('方括号未闭合退化为 Info / Unclosed bracket degrades to Info', () {
      expect(detect('[D open msg'), equals(LogLevel.info));
      expect(detect('D] close only'), equals(LogLevel.info));
    });

    test(
      '第三方日志库（emoji/前缀）统一归类为 Info / Third-party libs classified as Info',
      () {
        // logger 库常见 emoji 前缀 / Common logger emoji prefixes
        expect(detect('💡 something'), equals(LogLevel.info));
        expect(detect('🐛 bug report'), equals(LogLevel.info));
        expect(detect('⚠️  warning'), equals(LogLevel.info));
        expect(detect('⛔ error here'), equals(LogLevel.info));
        // 带日期前缀 / Date prefixed
        expect(detect('2025-01-01 msg'), equals(LogLevel.info));
      },
    );
  });

  /// =======================================================================
  /// captureLog — 日志捕获逻辑测试 / captureLog capture logic tests
  /// =======================================================================
  group('InspectorLogInterceptor.captureLog()', () {
    test(
      '未 start() 时 captureLog 不产生记录 / Not started: captureLog produces no records',
      () {
        // 默认状态下 _isStarted=false / Default state _isStarted=false
        InspectorLogInterceptor.instance.captureLog('msg', LogLevel.info);
        expect(InspectorService.instance.logEntries, isEmpty);
      },
    );

    test(
      'start() 后 captureLog 成功记录到 InspectorService / After start: logs recorded in InspectorService',
      () {
        InspectorLogInterceptor.instance.start();
        InspectorLogInterceptor.instance.captureLog('hello', LogLevel.warning);
        final logs = InspectorService.instance.logEntries;
        expect(logs.length, equals(1));
        expect(logs[0].message, equals('hello'));
        expect(logs[0].level, equals(LogLevel.warning));
        expect(logs[0].id, startsWith('log_'));
        // 时间戳接近当前 / Timestamp near now
        expect(
          DateTime.now().difference(logs[0].timestamp).inSeconds.abs(),
          lessThan(2),
        );
      },
    );

    test('新记录插入到列表头部（倒序）/ New entries inserted at head (reverse order)', () {
      InspectorLogInterceptor.instance.start();
      InspectorLogInterceptor.instance.captureLog('first', LogLevel.info);
      InspectorLogInterceptor.instance.captureLog('second', LogLevel.info);
      InspectorLogInterceptor.instance.captureLog('third', LogLevel.info);
      final logs = InspectorService.instance.logEntries;
      expect(logs.length, equals(3));
      expect(logs[0].message, equals('third'));
      expect(logs[1].message, equals('second'));
      expect(logs[2].message, equals('first'));
    });

    test('tag 可选字段正确传递 / Optional tag field passed correctly', () {
      InspectorLogInterceptor.instance.start();
      InspectorLogInterceptor.instance.captureLog(
        'network request',
        LogLevel.info,
        tag: 'Network',
      );
      InspectorLogInterceptor.instance.captureLog('no tag', LogLevel.info);
      final logs = InspectorService.instance.logEntries;
      expect(logs[1].tag, equals('Network'));
      expect(logs[0].tag, isNull);
    });

    test(
      'onLogCaptured 回调被触发且顺序正确 / onLogCaptured callback fires with correct order',
      () {
        final captured = <LogEntry>[];
        InspectorLogInterceptor.instance.onLogCaptured = captured.add;
        InspectorLogInterceptor.instance.start();
        InspectorLogInterceptor.instance.captureLog('cb1', LogLevel.debug);
        InspectorLogInterceptor.instance.captureLog('cb2', LogLevel.error);
        expect(captured.length, equals(2));
        expect(captured[0].message, equals('cb1'));
        expect(captured[0].level, equals(LogLevel.debug));
        expect(captured[1].message, equals('cb2'));
        expect(captured[1].level, equals(LogLevel.error));
      },
    );

    test(
      'stop() 后 captureLog 不再产生记录 / After stop: captureLog produces no records',
      () {
        InspectorLogInterceptor.instance.start();
        InspectorLogInterceptor.instance.captureLog('before', LogLevel.info);
        InspectorLogInterceptor.instance.stop();
        InspectorLogInterceptor.instance.captureLog('after', LogLevel.info);
        final logs = InspectorService.instance.logEntries;
        // 只有 start 期间的那一条被记录 / Only the one during start was recorded
        expect(logs.length, equals(1));
        expect(logs[0].message, equals('before'));
      },
    );

    test(
      '重入保护：onLogCaptured 回调内部调用 captureLog 被忽略 / Reentrance guard: captureLog inside onLogCaptured is ignored',
      () {
        int callbackCount = 0;
        InspectorLogInterceptor.instance.onLogCaptured = (entry) {
          callbackCount++;
          // 模拟用户在回调中再次调用日志方法（会导致无限递归的常见 bug）
          // Simulate user calling logging methods inside callback (a common infinite-recursion bug)
          InspectorLogInterceptor.instance.captureLog(
            'inner-${entry.message}',
            LogLevel.info,
          );
        };
        InspectorLogInterceptor.instance.start();
        InspectorLogInterceptor.instance.captureLog('outer', LogLevel.info);

        // 回调只触发一次（最外层），内部的 captureLog 被 _isCapturing 标志拒绝
        // Callback fires only once (outermost), inner captureLog rejected by _isCapturing flag
        expect(callbackCount, equals(1));
        // 最终日志也只应该有 1 条（最外层）
        // Final log count should also be 1 (outermost only)
        expect(InspectorService.instance.logEntries.length, equals(1));
        expect(
          InspectorService.instance.logEntries[0].message,
          equals('outer'),
        );
      },
    );
  });

  /// =======================================================================
  /// start/stop 状态控制 / start/stop state control
  /// =======================================================================
  group('InspectorLogInterceptor start/stop', () {
    test(
      '多次 start() 是安全的（幂等）/ Multiple start() calls are safe (idempotent)',
      () {
        InspectorLogInterceptor.instance.start();
        InspectorLogInterceptor.instance.start();
        InspectorLogInterceptor.instance.start();
        InspectorLogInterceptor.instance.captureLog('x', LogLevel.info);
        // 只产生一条记录 / Only one entry produced
        expect(InspectorService.instance.logEntries.length, equals(1));
      },
    );

    test(
      'start → stop → start 可重新启用 / start → stop → start re-enables capture',
      () {
        InspectorLogInterceptor.instance.start();
        InspectorLogInterceptor.instance.captureLog('a', LogLevel.info);
        InspectorLogInterceptor.instance.stop();
        InspectorLogInterceptor.instance.captureLog('b', LogLevel.info); // 忽略
        InspectorLogInterceptor.instance.start();
        InspectorLogInterceptor.instance.captureLog('c', LogLevel.info);
        final logs = InspectorService.instance.logEntries;
        expect(logs.length, equals(2));
        // c 是最新（插入最前），a 最后 / c is newest (inserted first), a is last
        expect(logs[0].message, equals('c'));
        expect(logs[1].message, equals('a'));
      },
    );
  });

  /// =======================================================================
  /// 便捷方法（verbose/debug/info/warning/error）/ Convenience methods
  /// =======================================================================
  group('InspectorLogInterceptor convenience methods', () {
    test(
      'verbose/debug/info/warning/error 使用正确的级别 / Convenience methods use correct levels',
      () {
        InspectorLogInterceptor.instance.start();
        final inst = InspectorLogInterceptor.instance;
        inst.verbose('vmsg');
        inst.debug('dmsg');
        inst.info('imsg');
        inst.warning('wmsg');
        inst.error('emsg');
        final logs = InspectorService.instance.logEntries;
        expect(logs.length, equals(5));
        // 顺序从新到旧：error, warning, info, debug, verbose
        // Newest to oldest: error, warning, info, debug, verbose
        expect(logs[0].level, equals(LogLevel.error));
        expect(logs[0].message, equals('emsg'));
        expect(logs[1].level, equals(LogLevel.warning));
        expect(logs[1].message, equals('wmsg'));
        expect(logs[2].level, equals(LogLevel.info));
        expect(logs[2].message, equals('imsg'));
        expect(logs[3].level, equals(LogLevel.debug));
        expect(logs[3].message, equals('dmsg'));
        expect(logs[4].level, equals(LogLevel.verbose));
        expect(logs[4].message, equals('vmsg'));
      },
    );

    test('便捷方法 tag 参数正确传递 / Convenience method tag passed correctly', () {
      InspectorLogInterceptor.instance.start();
      InspectorLogInterceptor.instance.info('with tag', tag: 'DB');
      InspectorLogInterceptor.instance.debug('no tag');
      final logs = InspectorService.instance.logEntries;
      expect(logs[1].tag, equals('DB'));
      expect(logs[0].tag, isNull);
    });

    test('log() 通用方法正确工作 / Generic log() method works', () {
      InspectorLogInterceptor.instance.start();
      InspectorLogInterceptor.instance.log(
        LogLevel.warning,
        'warn via log()',
        tag: 'X',
      );
      final logs = InspectorService.instance.logEntries;
      expect(logs.length, equals(1));
      expect(logs[0].level, equals(LogLevel.warning));
      expect(logs[0].message, equals('warn via log()'));
      expect(logs[0].tag, equals('X'));
    });
  });

  /// =======================================================================
  /// FlutterError.onError 保留与恢复测试 / FlutterError.onError preservation tests
  /// =======================================================================
  group('InspectorLogInterceptor FlutterError.onError preservation', () {
    test(
      'stop() 恢复原始 FlutterError.onError / stop() restores original FlutterError.onError',
      () {
        // 保存原始值 / Save original value
        final originalOnError = FlutterError.onError;

        // 设置一个模拟的第三方错误处理回调（如 Crashlytics）
        // Set a mock third-party error handler (e.g. Crashlytics)
        FlutterErrorDetails? mockHandlerCalled;
        void mockHandler(FlutterErrorDetails details) {
          mockHandlerCalled = details;
        }
        FlutterError.onError = mockHandler;

        // 启动日志拦截器 / Start log interceptor
        InspectorLogInterceptor.instance.start();

        // 触发 FlutterError / Trigger FlutterError
        FlutterError.onError!(
          FlutterErrorDetails(exception: Exception('test'), stack: StackTrace.current),
        );

        // 原始回调应被调用（Crashlytics 不丢失）/ Original handler should be called
        expect(mockHandlerCalled, isNotNull);

        // 停止拦截器 / Stop interceptor
        InspectorLogInterceptor.instance.stop();

        // FlutterError.onError 应恢复为 mockHandler / Should restore to mockHandler
        expect(FlutterError.onError, same(mockHandler));

        // 重置 / Reset
        FlutterError.onError = originalOnError;
      },
    );

    test(
      'start() 时原始 FlutterError.onError 被优先调用 / Original FlutterError.onError called first on start',
      () {
        final originalOnError = FlutterError.onError;

        // 追踪调用顺序 / Track call order
        final callOrder = <String>[];
        void mockHandler(FlutterErrorDetails details) {
          callOrder.add('original');
        }
        FlutterError.onError = mockHandler;

        InspectorLogInterceptor.instance.start();

        FlutterError.onError!(
          FlutterErrorDetails(exception: Exception('test'), stack: StackTrace.current),
        );

        // 原始回调应先于日志捕获被调用 / Original handler called before log capture
        expect(callOrder, contains('original'));
        expect(
          InspectorService.instance.logEntries.any((e) => e.level == LogLevel.error),
          isTrue,
        );

        InspectorLogInterceptor.instance.stop();
        FlutterError.onError = originalOnError;
      },
    );
  });
}
