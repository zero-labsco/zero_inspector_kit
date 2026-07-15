import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';
import '../services/inspector_service.dart';

/// 日志拦截器
/// 自动捕获应用中的日志信息，无需用户手动调用
/// 支持：
/// 1. print() / debugPrint() 输出自动捕获
/// 2. Flutter 错误和异常捕获
/// 3. 其他日志库集成（通过回调接口）
class InspectorLogInterceptor {
  InspectorLogInterceptor._();

  /// 单例实例
  static final InspectorLogInterceptor instance = InspectorLogInterceptor._();

  /// 是否已启动
  bool _isStarted = false;

  /// 原始 debugPrint 函数
  DebugPrintCallback? _originalDebugPrint;

  /// 是否正在捕获日志（防止递归）
  bool _isCapturing = false;

  /// 日志捕获回调，供其他日志库调用
  /// 用户可以注册这个回调来将其他日志库的日志传递给检查器
  void Function(LogEntry)? onLogCaptured;

  /// 启动日志捕获
  void start() {
    if (!_isStarted) {
      _isStarted = true;
      _overrideDebugPrint();
      _setupErrorHandling();
    }
  }

  /// 停止日志捕获
  void stop() {
    _isStarted = false;
    _restoreDebugPrint();
  }

  /// 覆盖 debugPrint 函数，自动捕获所有 debugPrint 输出
  void _overrideDebugPrint() {
    _originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (_originalDebugPrint != null) {
        _originalDebugPrint!(message, wrapWidth: wrapWidth);
      }
      final level = _detectLogLevel(message ?? '');
      _captureLog(message ?? '', level);
    };
  }

  /// 恢复原始 debugPrint 函数
  void _restoreDebugPrint() {
    if (_originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
      _originalDebugPrint = null;
    }
  }

  /// 设置错误处理，捕获 Flutter 错误和异常
  void _setupErrorHandling() {
    FlutterError.onError = (FlutterErrorDetails details) {
      _captureLog(details.exception.toString(), LogLevel.error);
      if (details.stack != null) {
        _captureLog(details.stack.toString(), LogLevel.error);
      }
    };

    runZonedGuarded(() {}, (error, stackTrace) {
      _captureLog(error.toString(), LogLevel.error);
      _captureLog(stackTrace.toString(), LogLevel.error);
    });
  }

  /// 捕获日志并添加到服务中
  /// [message] 日志消息
  /// [level] 日志级别，默认为 debug
  /// [tag] 日志标签（可选）
  void _captureLog(String message, LogLevel level, {String? tag}) {
    if (!_isStarted || _isCapturing) return;

    _isCapturing = true;
    try {
      final entry = LogEntry(
        id: _generateId(),
        level: level,
        message: message,
        timestamp: DateTime.now(),
        tag: tag,
      );

      InspectorService.instance.addLogEntry(entry);

      if (onLogCaptured != null) {
        onLogCaptured!(entry);
      }
    } finally {
      _isCapturing = false;
    }
  }

  /// 添加自定义日志
  /// [level] 日志级别
  /// [message] 日志消息
  /// [tag] 日志标签（可选）
  void log(LogLevel level, String message, {String? tag}) {
    _captureLog(message, level, tag: tag);
  }

  /// 添加verbose级别日志
  void verbose(String message, {String? tag}) =>
      log(LogLevel.verbose, message, tag: tag);

  /// 添加debug级别日志
  void debug(String message, {String? tag}) =>
      log(LogLevel.debug, message, tag: tag);

  /// 添加info级别日志
  void info(String message, {String? tag}) =>
      log(LogLevel.info, message, tag: tag);

  /// 添加warning级别日志
  void warning(String message, {String? tag}) =>
      log(LogLevel.warning, message, tag: tag);

  /// 添加error级别日志
  void error(String message, {String? tag}) =>
      log(LogLevel.error, message, tag: tag);

  /// 打印并捕获日志（替代print函数）
  void logPrint(String message) {
    print(message);
    _captureLog(message, LogLevel.debug);
  }

  /// 生成唯一日志ID
  String _generateId() {
    return 'log_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 根据日志内容自动识别日志级别
  /// 支持多种格式：
  /// - [VERBOSE] message
  /// - [DEBUG] message  
  /// - [INFO] message
  /// - [WARNING] / [WARN] message
  /// - [ERROR] / [ERR] message
  /// - [FATAL] / [CRITICAL] message
  /// - Logger库格式：[T] [D] [I] [W] [E] [F]
  /// - Logger库带装饰格式：│ [D] message 或 ├─ [D] message
  /// - Logger库 emoji 格式：📱 [D] message 或 🐛 [D] message
  LogLevel _detectLogLevel(String message) {
    final trimmed = message.trim();
    
    String levelPrefix = '';
    final bracketIndex = trimmed.indexOf('[');
    if (bracketIndex != -1) {
      final endBracketIndex = trimmed.indexOf(']', bracketIndex);
      if (endBracketIndex != -1) {
        levelPrefix = trimmed.substring(bracketIndex, endBracketIndex + 1).toUpperCase();
      }
    }
    
    if (levelPrefix == '[VERBOSE]' || levelPrefix == '[V]' || levelPrefix == '[T]') {
      return LogLevel.verbose;
    }
    if (levelPrefix == '[DEBUG]' || levelPrefix == '[D]') {
      return LogLevel.debug;
    }
    if (levelPrefix == '[INFO]' || levelPrefix == '[I]') {
      return LogLevel.info;
    }
    if (levelPrefix == '[WARNING]' || levelPrefix == '[WARN]' || levelPrefix == '[W]') {
      return LogLevel.warning;
    }
    if (levelPrefix == '[ERROR]' || levelPrefix == '[ERR]' || levelPrefix == '[E]') {
      return LogLevel.error;
    }
    if (levelPrefix == '[FATAL]' || levelPrefix == '[CRITICAL]' || levelPrefix == '[F]') {
      return LogLevel.error;
    }

    return LogLevel.debug;
  }
}

/// 使用检查器 Zone 运行应用，确保所有 print() 调用都能被捕获
/// 推荐在 main() 函数中使用此方法来运行应用
void runInspectorApp(VoidCallback appRunner) {
  InspectorLogInterceptor.instance.start();

  runZonedGuarded(
    appRunner,
    (error, stackTrace) {
      InspectorLogInterceptor.instance._captureLog(
        error.toString(),
        LogLevel.error,
      );
      InspectorLogInterceptor.instance._captureLog(
        stackTrace.toString(),
        LogLevel.error,
      );
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        parent.print(zone, line);
        final level = InspectorLogInterceptor.instance._detectLogLevel(line.toString());
        InspectorLogInterceptor.instance._captureLog(
          line.toString(),
          level,
        );
      },
    ),
  );
}