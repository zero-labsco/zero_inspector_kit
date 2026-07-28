import '../interceptors/log_interceptor.dart';
import '../models/log_entry.dart';

/// 日志记录简化 API / Simplified logging API
///
/// 提供比 `InspectorLogInterceptor.instance.xxx()` 更短的手动日志调用方式。
/// Provides shorter manual logging calls than `InspectorLogInterceptor.instance.xxx()`.
///
/// 用法示例 / Usage examples:
/// ```dart
/// InspectorLog.v('Verbose log');
/// InspectorLog.d('Debug log', tag: 'Network');
/// InspectorLog.i('Info log');
/// InspectorLog.w('Warning log');
/// InspectorLog.e('Error log');
/// ```
class InspectorLog {
  InspectorLog._();

  /// 启动日志捕获 / Start log capture
  static void start() => InspectorLogInterceptor.instance.start();

  /// 停止日志捕获 / Stop log capture
  static void stop() => InspectorLogInterceptor.instance.stop();

  /// 添加指定级别日志 / Add a log entry with specified level
  static void log(LogLevel level, String message, {String? tag}) =>
      InspectorLogInterceptor.instance.log(level, message, tag: tag);

  /// 添加 Verbose 级别日志 / Add verbose log
  static void v(String message, {String? tag}) =>
      InspectorLogInterceptor.instance.verbose(message, tag: tag);

  /// 添加 Debug 级别日志 / Add debug log
  static void d(String message, {String? tag}) =>
      InspectorLogInterceptor.instance.debug(message, tag: tag);

  /// 添加 Info 级别日志 / Add info log
  static void i(String message, {String? tag}) =>
      InspectorLogInterceptor.instance.info(message, tag: tag);

  /// 添加 Warning 级别日志 / Add warning log
  static void w(String message, {String? tag}) =>
      InspectorLogInterceptor.instance.warning(message, tag: tag);

  /// 添加 Error 级别日志 / Add error log
  static void e(String message, {String? tag}) =>
      InspectorLogInterceptor.instance.error(message, tag: tag);

  /// 日志捕获回调，用于第三方日志库双向同步 / Callback for third-party log library bidirectional sync
  static set onLogCaptured(void Function(LogEntry)? callback) {
    InspectorLogInterceptor.instance.onLogCaptured = callback;
  }

  /// 当前是否正在捕获日志 / Whether log capture is currently active
  static bool get isRunning => InspectorLogInterceptor.instance.isRunning;
}
