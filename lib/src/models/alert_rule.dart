/// 告警规则类型 / Alert rule kinds
enum AlertKind {
  /// 网络响应状态码 >= 阈值（默认 500）/ HTTP status >= threshold (default 500)
  httpStatus,

  /// 网络耗时超过阈值（毫秒）/ Request duration exceeds threshold (ms)
  requestDuration,

  /// 日志级别达到阈值（ERROR 及以上）/ Log level reaches threshold (ERROR+)
  logLevel,

  /// 内存占用超过阈值（MB）/ Memory usage exceeds threshold (MB)
  memoryMb,

  /// FPS 低于阈值 / FPS drops below threshold
  fpsLow,
}

/// 单条告警规则 / A single alert rule
///
/// 当采集数据命中 [kind] 且超过/达到 [threshold] 时触发告警。
/// Fires when collected data matches [kind] and crosses [threshold].
class AlertRule {
  /// 唯一ID / Unique ID
  final String id;

  /// 规则类型 / Rule kind
  final AlertKind kind;

  /// 阈值 / Threshold value
  final double threshold;

  /// 是否启用 / Enabled
  final bool enabled;

  const AlertRule({
    required this.id,
    required this.kind,
    required this.threshold,
    this.enabled = true,
  });

  /// 默认规则集合：5xx、慢请求 1s、ERROR 日志、内存 200MB、FPS<50
  /// Default rules: 5xx, slow request 1s, ERROR logs, 200MB memory, FPS<50
  static const List<AlertRule> defaults = [
    AlertRule(id: 'def-status', kind: AlertKind.httpStatus, threshold: 500),
    AlertRule(
      id: 'def-duration',
      kind: AlertKind.requestDuration,
      threshold: 1000,
    ),
    AlertRule(id: 'def-log', kind: AlertKind.logLevel, threshold: 4),
    AlertRule(id: 'def-mem', kind: AlertKind.memoryMb, threshold: 200),
    AlertRule(id: 'def-fps', kind: AlertKind.fpsLow, threshold: 50),
  ];
}
