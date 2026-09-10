/// 日志级别枚举 / Log level enumeration
enum LogLevel { verbose, debug, info, warning, error }

/// [LogLevel] 的展示文本 / Display text for [LogLevel]
///
/// 单一实现：此前 `LogEntry.levelText` 与 `ExportService` 里各有一份同样的
/// switch，新增级别时极易漏改其中一处。
/// Single implementation: `LogEntry.levelText` and `ExportService` each had a
/// copy of the same switch, so adding a level risked missing one.
extension LogLevelText on LogLevel {
  /// 级别缩写（V / D / I / W / E）/ Level abbreviation (V / D / I / W / E)
  static String of(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return 'V';
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }
}

/// 日志条目模型 / Log entry model
class LogEntry {
  /// 日志唯一ID / Log unique ID
  final String id;

  /// 日志级别 / Log level
  final LogLevel level;

  /// 日志消息内容 / Log message content
  final String message;

  /// 日志时间戳 / Log timestamp
  final DateTime timestamp;

  /// 日志标签 / Log tag
  final String? tag;

  LogEntry({
    required this.id,
    required this.level,
    required this.message,
    required this.timestamp,
    this.tag,
  });

  /// 日志级别缩写文本 / Log level abbreviation text
  String get levelText => LogLevelText.of(level);

  /// 格式化后的时间戳文本 / Formatted timestamp text
  String get timestampText {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  /// 转换为 JSON / Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'level': level.name,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'tag': tag,
    };
  }
}
