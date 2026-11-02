import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../models/log_entry.dart';
import '../services/inspector_service.dart';

/// 日志拦截器类 / Log interceptor class
/// 负责自动捕获应用中的所有日志输出，包括：/ Automatically captures all log outputs in the application, including:
/// - print() / debugPrint() 调用 / print() / debugPrint() calls
/// - Flutter 错误和异常 / Flutter errors and exceptions
/// - 第三方日志库（如 logger）通过 print() 输出的日志 / Third-party logging libraries (e.g., logger) output via print()
class InspectorLogInterceptor {
  /// 私有构造函数 / Private constructor
  InspectorLogInterceptor._();

  /// 单例实例 / Singleton instance
  static final InspectorLogInterceptor instance = InspectorLogInterceptor._();

  /// 是否已启动日志捕获 / Whether log capture has started
  bool _isStarted = false;

  /// 原始的 debugPrint 函数引用 / Original debugPrint function reference
  DebugPrintCallback? _originalDebugPrint;

  /// 原始的 FlutterError.onError 回调 / Original FlutterError.onError callback
  FlutterExceptionHandler? _originalFlutterOnError;

  /// 是否正在捕获日志（防止递归调用）/ Whether currently capturing logs (prevents recursive calls)
  bool _isCapturing = false;

  /// 全局单调递增计数器，用于生成唯一日志 ID / Monotonic counter for unique log IDs
  static int _logIdCounter = 0;

  /// 当前是否已启动日志捕获 / Whether log capture has been started
  bool get isRunning => _isStarted;

  /// 日志捕获回调，供外部日志库集成使用 / Log capture callback for external logging library integration
  void Function(LogEntry)? onLogCaptured;

  /// 启动日志捕获 / Start log capture
  void start() {
    if (!_isStarted) {
      _isStarted = true;
      _overrideDebugPrint();
      _setupErrorHandling();
    }
  }

  /// 停止日志捕获 / Stop log capture
  ///
  /// 与 [start] 对称，未启动时不执行任何恢复动作。此前缺少这层守卫：未 start 就
  /// stop、或宿主在 start **之后**自行安装了 Crashlytics / Sentry 的 handler 时，
  /// 恢复动作会用启动瞬间的旧快照（可能为 null）覆盖宿主当前的
  /// `FlutterError.onError`，导致宿主错误上报静默失效。
  /// Symmetric to [start]: does nothing when not started. Without this guard,
  /// stopping without starting — or after the host installed its own Crashlytics /
  /// Sentry handler *after* start — replaced the host's current
  /// `FlutterError.onError` with the snapshot taken at start time (possibly null),
  /// silently breaking host error reporting.
  void stop() {
    if (!_isStarted) return;
    _isStarted = false;
    _restoreDebugPrint();
    _restoreFlutterOnError();
    _stopIsolateErrorListener();
  }

  /// 覆盖 debugPrint 函数，实现日志捕获 / Override debugPrint function to capture logs
  void _overrideDebugPrint() {
    _originalDebugPrint = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      // 先调用原始的 debugPrint 确保日志正常输出到控制台 / Call original debugPrint first to ensure normal console output
      if (_originalDebugPrint != null) {
        _originalDebugPrint!(message, wrapWidth: wrapWidth);
      }
      // 识别日志级别并捕获 / Detect log level and capture
      final level = detectLogLevel(message ?? '');
      captureLog(message ?? '', level);
    };
  }

  /// 恢复原始的 debugPrint 函数 / Restore original debugPrint function
  void _restoreDebugPrint() {
    if (_originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
      _originalDebugPrint = null;
    }
  }

  /// 设置错误处理，捕获 Flutter 错误和异常 / Set up error handling to capture Flutter errors and exceptions
  void _setupErrorHandling() {
    // 保存原始回调，避免覆盖 Crashlytics / Sentry 等第三方错误上报
    // Save original callback to avoid overwriting Crashlytics / Sentry etc.
    _originalFlutterOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      // 先调用原始回调（如 Crashlytics），确保错误上报不丢失
      // Call original callback first (e.g. Crashlytics) to preserve error reporting
      _originalFlutterOnError?.call(details);
      captureLog(details.exception.toString(), LogLevel.error);
      if (details.stack != null) {
        captureLog(details.stack.toString(), LogLevel.error);
      }
    };

    // 捕获未处理的异常 / Capture unhandled exceptions
    // 全局异步异常兜底（覆盖两行式集成、以及非本插件 Zone 启动的场景）。
    _startIsolateErrorListener();
  }

  /// 全局异步异常监听端口（Isolate 级）。
  /// Global async-error listener port (isolate-level).
  ReceivePort? _isolateErrorPort;

  /// 全局接管未捕获的异步异常（Future / Stream error）。Isolate 级监听不干扰
  /// Flutter 自身的错误呈现，仅额外写入检查器日志。
  /// Globally capture uncaught async errors (Future / Stream). The isolate-level
  /// listener does not interfere with Flutter's own error presentation; it only
  /// additionally writes the error to the inspector log.
  void _startIsolateErrorListener() {
    if (_isolateErrorPort != null) return;
    final port = ReceivePort();
    _isolateErrorPort = port;
    port.listen((dynamic errorAndStack) {
      if (errorAndStack is List && errorAndStack.length >= 2) {
        captureLog(errorAndStack[0].toString(), LogLevel.error);
        captureLog(errorAndStack[1].toString(), LogLevel.error);
      } else {
        captureLog(errorAndStack.toString(), LogLevel.error);
      }
    });
    Isolate.current.addErrorListener(port.sendPort);
  }

  /// 停止并清理全局异步异常监听。
  /// Stop and clean up the global async-error listener.
  void _stopIsolateErrorListener() {
    final port = _isolateErrorPort;
    if (port == null) return;
    Isolate.current.removeErrorListener(port.sendPort);
    port.close();
    _isolateErrorPort = null;
  }

  /// 恢复原始的 FlutterError.onError / Restore original FlutterError.onError
  ///
  /// 即使原始值为 null 也要恢复回去——此前只在非 null 时恢复，导致原本没有注册
  /// 自定义 onError 的宿主在 stop 后，检查器的回调仍常驻（且拿不到 Flutter 默认的
  /// 错误呈现）。/ Even when the original was null we must restore it; otherwise a
  /// host with no custom handler keeps our callback alive after stop.
  void _restoreFlutterOnError() {
    FlutterError.onError = _originalFlutterOnError;
    _originalFlutterOnError = null;
  }

  /// 捕获日志并添加到服务中 / Capture log and add to service
  /// [message] 日志消息 / Log message
  /// [level] 日志级别 / Log level
  /// [tag] 日志标签（可选）/ Log tag (optional)
  void captureLog(String message, LogLevel level, {String? tag}) {
    // 如果未启动或正在捕获中，直接返回（防止递归调用）/ Return if not started or already capturing (prevents recursion)
    if (!_isStarted || _isCapturing) return;

    _isCapturing = true;
    try {
      // 创建日志条目 / Create log entry
      final entry = LogEntry(
        id: _generateId(),
        level: level,
        message: message,
        timestamp: DateTime.now(),
        tag: tag,
      );

      // 添加到检查器服务 / Add to inspector service
      InspectorService.instance.addLogEntry(entry);

      // 触发回调（供外部日志库集成）/ Trigger callback (for external logging library integration)
      if (onLogCaptured != null) {
        onLogCaptured!(entry);
      }
    } finally {
      _isCapturing = false;
    }
  }

  /// 通用日志方法 / Generic log method
  /// [level] 日志级别 / Log level
  /// [message] 日志消息 / Log message
  /// [tag] 日志标签（可选）/ Log tag (optional)
  void log(LogLevel level, String message, {String? tag}) {
    captureLog(message, level, tag: tag);
  }

  /// 输出 VERBOSE 级别的日志 / Output VERBOSE level log
  void verbose(String message, {String? tag}) =>
      log(LogLevel.verbose, message, tag: tag);

  /// 输出 DEBUG 级别的日志 / Output DEBUG level log
  void debug(String message, {String? tag}) =>
      log(LogLevel.debug, message, tag: tag);

  /// 输出 INFO 级别的日志 / Output INFO level log
  void info(String message, {String? tag}) =>
      log(LogLevel.info, message, tag: tag);

  /// 输出 WARNING 级别的日志 / Output WARNING level log
  void warning(String message, {String? tag}) =>
      log(LogLevel.warning, message, tag: tag);

  /// 输出 ERROR 级别的日志 / Output ERROR level log
  void error(String message, {String? tag}) =>
      log(LogLevel.error, message, tag: tag);

  /// 生成唯一的日志 ID / Generate unique log ID
  ///
  /// 使用单调递增计数器而非时间戳：第三方库同步逐行 print 的多行日志会在
  /// 同一毫秒内产生多条 captureLog 调用，若以毫秒时间戳作 ID 会碰撞，导致按
  /// ID 查找详情时总是命中第一条（点击任意分段都显示表头）。
  /// Uses a monotonic counter instead of a timestamp: synchronous multi-line
  /// captures can share the same millisecond and collide, breaking ID-based
  /// detail lookup (tapping any segment would show the first one).
  String _generateId() {
    return 'log_${_logIdCounter++}';
  }

  /// ANSI 转义序列（颜色码）匹配模式，编译一次复用。
  /// ANSI escape sequence (color code) pattern, compiled once and reused.
  static final RegExp _ansiEscapePattern = RegExp(r'\x1B\[[0-9;]*[A-Za-z]');

  /// 根据日志内容自动识别日志级别 / Automatically detect log level based on message content
  /// 支持以下标准格式（方括号级别标记）：/ Supports the following standard formats (bracket level markers):
  /// - `[VERBOSE]` message / `[V]` message / `[T]` message (trace)
  /// - `[DEBUG]` message / `[D]` message
  /// - `[INFO]` message / `[I]` message
  /// - `[WARNING]` message / `[WARN]` message / `[W]` message
  /// - `[ERROR]` message / `[ERR]` message / `[E]` message
  /// - `[FATAL]` message / `[CRITICAL]` message / `[F]` message
  ///
  /// 对于第三方日志库（如 logger、logcat 等），由于其格式各不相同且自带标识，/ For third-party logging libraries (e.g., logger, logcat), since their formats vary and they have their own identifiers,
  /// 统一归类到 INFO 级别，用户可通过日志内容中的标识自行识别级别。/ they are uniformly classified as INFO level. Users can identify levels through identifiers in the log content.
  LogLevel detectLogLevel(String message) {
    // 去除首尾空白 / Trim whitespace
    var processed = message.trim();

    // 移除 ANSI 颜色代码（如 [34m[D] message[0m）/ Remove ANSI color codes (e.g., [34m[D] message[0m)
    //
    // 正则提到静态常量：`detectLogLevel` 对**每一行** print / debugPrint 都会
    // 调用，此前每调用一次就重新编译一次正则。
    // The regex is a static constant: `detectLogLevel` runs for **every** print /
    // debugPrint line, and it used to recompile the regex on every call.
    processed = processed.replaceAll(_ansiEscapePattern, '');

    // 提取级别前缀（如 [D], [INFO]）/ Extract level prefix (e.g., [D], [INFO])
    String levelPrefix = '';
    final bracketIndex = processed.indexOf('[');
    if (bracketIndex != -1) {
      final endBracketIndex = processed.indexOf(']', bracketIndex);
      if (endBracketIndex != -1) {
        levelPrefix = processed
            .substring(bracketIndex, endBracketIndex + 1)
            .toUpperCase();
      }
    }

    // 根据级别前缀判断日志级别 / Determine log level based on prefix
    if (levelPrefix == '[VERBOSE]' ||
        levelPrefix == '[V]' ||
        levelPrefix == '[T]') {
      return LogLevel.verbose;
    } else if (levelPrefix == '[DEBUG]' || levelPrefix == '[D]') {
      return LogLevel.debug;
    } else if (levelPrefix == '[INFO]' || levelPrefix == '[I]') {
      return LogLevel.info;
    } else if (levelPrefix == '[WARNING]' ||
        levelPrefix == '[WARN]' ||
        levelPrefix == '[W]') {
      return LogLevel.warning;
    } else if (levelPrefix == '[ERROR]' ||
        levelPrefix == '[ERR]' ||
        levelPrefix == '[E]') {
      return LogLevel.error;
    } else if (levelPrefix == '[FATAL]' ||
        levelPrefix == '[CRITICAL]' ||
        levelPrefix == '[F]') {
      return LogLevel.error;
    }

    // 第三方日志库（如 logger、logcat 等）统一归类到 INFO 级别 / Third-party logging libraries (e.g., logger, logcat) are uniformly classified as INFO level
    // 第三方库自己已经有标识（emoji、前缀等），用户可通过日志内容识别级别 / Third-party libraries have their own identifiers (emoji, prefixes, etc.), users can identify levels through log content
    return LogLevel.info;
  }
}

// `runInspectorApp` 已在 2.0.0 移除（此前是死代码：不挂载悬浮按钮与路由观察者，
// 也没有启动网络 / 数据库 / 路由采集）。请改用
// `ZeroInspectorKit.runAppWithInspector()`。
// `runInspectorApp` was removed in 2.0.0 (it was dead code: it never installed the
// floating button or the route observer, nor started network / database / route
// capture). Use `ZeroInspectorKit.runAppWithInspector()` instead.
