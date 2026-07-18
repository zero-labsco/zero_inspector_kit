import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/log_entry.dart';
import '../services/inspector_service.dart';

/// 日志拦截器类
/// 负责自动捕获应用中的所有日志输出，包括：
/// - print() / debugPrint() 调用
/// - Flutter 错误和异常
/// - 第三方日志库（如 logger）通过 print() 输出的日志
class InspectorLogInterceptor {
  /// 私有构造函数
  InspectorLogInterceptor._();

  /// 单例实例
  static final InspectorLogInterceptor instance = InspectorLogInterceptor._();

  /// 是否已启动日志捕获
  bool _isStarted = false;

  /// 原始的 debugPrint 函数引用
  DebugPrintCallback? _originalDebugPrint;

  /// 是否正在捕获日志（防止递归调用）
  bool _isCapturing = false;

  /// 日志捕获回调，供外部日志库集成使用
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

  /// 覆盖 debugPrint 函数，实现日志捕获
  void _overrideDebugPrint() {
    _originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      // 先调用原始的 debugPrint 确保日志正常输出到控制台
      if (_originalDebugPrint != null) {
        _originalDebugPrint!(message, wrapWidth: wrapWidth);
      }
      // 识别日志级别并捕获
      final level = detectLogLevel(message ?? '');
      captureLog(message ?? '', level);
    };
  }

  /// 恢复原始的 debugPrint 函数
  void _restoreDebugPrint() {
    if (_originalDebugPrint != null) {
      debugPrint = _originalDebugPrint!;
      _originalDebugPrint = null;
    }
  }

  /// 设置错误处理，捕获 Flutter 错误和异常
  void _setupErrorHandling() {
    // 捕获 Flutter 框架级别的错误
    FlutterError.onError = (FlutterErrorDetails details) {
      captureLog(details.exception.toString(), LogLevel.error);
      if (details.stack != null) {
        captureLog(details.stack.toString(), LogLevel.error);
      }
    };

    // 捕获未处理的异常
    runZonedGuarded(() {}, (error, stackTrace) {
      captureLog(error.toString(), LogLevel.error);
      captureLog(stackTrace.toString(), LogLevel.error);
    });
  }

  /// 捕获日志并添加到服务中
  /// [message] 日志消息
  /// [level] 日志级别
  /// [tag] 日志标签（可选）
  void captureLog(String message, LogLevel level, {String? tag}) {
    // 如果未启动或正在捕获中，直接返回（防止递归调用）
    if (!_isStarted || _isCapturing) return;

    _isCapturing = true;
    try {
      // 创建日志条目
      final entry = LogEntry(
        id: _generateId(),
        level: level,
        message: message,
        timestamp: DateTime.now(),
        tag: tag,
      );

      // 添加到检查器服务
      InspectorService.instance.addLogEntry(entry);

      // 触发回调（供外部日志库集成）
      if (onLogCaptured != null) {
        onLogCaptured!(entry);
      }
    } finally {
      _isCapturing = false;
    }
  }

  /// 通用日志方法
  /// [level] 日志级别
  /// [message] 日志消息
  /// [tag] 日志标签（可选）
  void log(LogLevel level, String message, {String? tag}) {
    captureLog(message, level, tag: tag);
  }

  /// 输出 VERBOSE 级别的日志
  void verbose(String message, {String? tag}) =>
      log(LogLevel.verbose, message, tag: tag);

  /// 输出 DEBUG 级别的日志
  void debug(String message, {String? tag}) =>
      log(LogLevel.debug, message, tag: tag);

  /// 输出 INFO 级别的日志
  void info(String message, {String? tag}) =>
      log(LogLevel.info, message, tag: tag);

  /// 输出 WARNING 级别的日志
  void warning(String message, {String? tag}) =>
      log(LogLevel.warning, message, tag: tag);

  /// 输出 ERROR 级别的日志
  void error(String message, {String? tag}) =>
      log(LogLevel.error, message, tag: tag);

  /// 通过 print 输出日志并捕获
  void logPrint(String message) {
    print(message);
    captureLog(message, LogLevel.debug);
  }

  /// 生成唯一的日志 ID
  String _generateId() {
    return 'log_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// 根据日志内容自动识别日志级别
  /// 支持以下标准格式（方括号级别标记）：
  /// - [VERBOSE] message / [V] message / [T] message (trace)
  /// - [DEBUG] message / [D] message
  /// - [INFO] message / [I] message
  /// - [WARNING] message / [WARN] message / [W] message
  /// - [ERROR] message / [ERR] message / [E] message
  /// - [FATAL] message / [CRITICAL] message / [F] message
  ///
  /// 对于第三方日志库（如 logger、logcat 等），由于其格式各不相同且自带标识，
  /// 统一归类到 INFO 级别，用户可通过日志内容中的标识自行识别级别。
  LogLevel detectLogLevel(String message) {
    // 去除首尾空白
    var processed = message.trim();

    // 移除 ANSI 颜色代码（如 [34m[D] message[0m）
    processed = processed.replaceAll(RegExp(r'\x1B\[[0-9;]*[A-Za-z]'), '');

    // 提取级别前缀（如 [D], [INFO]）
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

    // 根据级别前缀判断日志级别
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

    // 第三方日志库（如 logger、logcat 等）统一归类到 INFO 级别
    // 第三方库自己已经有标识（emoji、前缀等），用户可通过日志内容识别级别
    return LogLevel.info;
  }
}

/// 使用检查器 Zone 运行应用
/// 通过 ZoneSpecification 捕获所有 print() 调用
/// [appRunner] 应用运行回调
void runInspectorApp(VoidCallback appRunner) {
  InspectorLogInterceptor.instance.start();

  runZonedGuarded(
    appRunner,
    (error, stackTrace) {
      InspectorLogInterceptor.instance.captureLog(
        error.toString(),
        LogLevel.error,
      );
      InspectorLogInterceptor.instance.captureLog(
        stackTrace.toString(),
        LogLevel.error,
      );
    },
    zoneSpecification: ZoneSpecification(
      print: (self, parent, zone, line) {
        // 先调用原始的 print 确保日志正常输出到控制台
        parent.print(zone, line);
        // 识别日志级别并捕获
        final level = InspectorLogInterceptor.instance.detectLogLevel(
          line.toString(),
        );
        InspectorLogInterceptor.instance.captureLog(line.toString(), level);
      },
    ),
  );
}
