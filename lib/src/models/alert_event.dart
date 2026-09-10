/// 告警事件 / Alert event
class AlertEvent {
  /// 来源（url / memory / fps / log）/ Source
  final String source;

  /// 描述 / Description
  final String message;

  /// 触发时间 / Timestamp
  final DateTime time;

  AlertEvent({required this.source, required this.message, DateTime? time})
    : time = time ?? DateTime.now();
}
