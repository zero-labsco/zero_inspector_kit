import '../models/log_entry.dart';
import '../services/inspector_service.dart';

/// 日志拦截器
/// 用于捕获应用中的日志信息，支持手动日志和自动捕获print输出
class InspectorLogInterceptor {
  InspectorLogInterceptor._();

  /// 单例实例
  static final InspectorLogInterceptor instance = InspectorLogInterceptor._();

  /// 是否已启动
  bool _isStarted = false;

  /// 启动日志捕获
  void start() {
    if (!_isStarted) {
      _isStarted = true;
    }
  }

  /// 停止日志捕获
  void stop() {
    _isStarted = false;
  }

  /// 捕获日志并添加到服务中
  void _captureLog(String message) {
    final entry = LogEntry(
      id: _generateId(),
      level: LogLevel.debug,
      message: message,
      timestamp: DateTime.now(),
    );
    InspectorService.instance.addLogEntry(entry);
  }

  /// 添加自定义日志
  /// [level] 日志级别
  /// [message] 日志消息
  /// [tag] 日志标签（可选）
  void log(LogLevel level, String message, {String? tag}) {
    final entry = LogEntry(
      id: _generateId(),
      level: level,
      message: message,
      timestamp: DateTime.now(),
      tag: tag,
    );
    InspectorService.instance.addLogEntry(entry);
  }

  /// 添加verbose级别日志
  void verbose(String message, {String? tag}) => log(LogLevel.verbose, message, tag: tag);

  /// 添加debug级别日志
  void debug(String message, {String? tag}) => log(LogLevel.debug, message, tag: tag);

  /// 添加info级别日志
  void info(String message, {String? tag}) => log(LogLevel.info, message, tag: tag);

  /// 添加warning级别日志
  void warning(String message, {String? tag}) => log(LogLevel.warning, message, tag: tag);

  /// 添加error级别日志
  void error(String message, {String? tag}) => log(LogLevel.error, message, tag: tag);

  /// 打印并捕获日志（替代print函数）
  void logPrint(String message) {
    print(message);
    _captureLog(message);
  }

  /// 生成唯一日志ID
  String _generateId() {
    return 'log_${DateTime.now().millisecondsSinceEpoch}';
  }
}