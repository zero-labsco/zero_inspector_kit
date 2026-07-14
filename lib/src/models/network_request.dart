/// 网络请求模型
class NetworkRequest {
  /// 请求唯一ID
  final String id;

  /// HTTP方法 (GET, POST, PUT, DELETE等)
  final String method;

  /// 请求URL
  final String url;

  /// 请求头
  final Map<String, String>? headers;

  /// 请求体
  final dynamic body;

  /// 响应体
  final dynamic responseBody;

  /// HTTP状态码
  final int? statusCode;

  /// 请求发送时间戳（毫秒）
  final int requestTime;

  /// 响应接收时间戳（毫秒）
  final int? responseTime;

  /// 请求耗时（毫秒）
  final int? duration;

  NetworkRequest({
    required this.id,
    required this.method,
    required this.url,
    this.headers,
    this.body,
    this.responseBody,
    this.statusCode,
    required this.requestTime,
    this.responseTime,
    this.duration,
  });

  /// 获取状态码，默认为-1
  int get status => statusCode ?? -1;

  /// 判断请求是否成功（200-299）
  bool get isSuccess => statusCode != null && statusCode! >= 200 && statusCode! < 300;

  /// 格式化后的耗时文本
  String get durationText {
    if (duration == null) return '-';
    if (duration! < 1000) return '${duration}ms';
    return '${(duration! / 1000).toStringAsFixed(2)}s';
  }
}