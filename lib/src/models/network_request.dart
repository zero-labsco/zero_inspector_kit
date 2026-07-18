/// 网络请求模型 / Network request model
class NetworkRequest {
  /// 请求唯一ID / Request unique ID
  final String id;

  /// HTTP方法 (GET, POST, PUT, DELETE等) / HTTP method (GET, POST, PUT, DELETE, etc.)
  final String method;

  /// 请求URL / Request URL
  final String url;

  /// 请求头 / Request headers
  final Map<String, String>? headers;

  /// 请求体 / Request body
  final dynamic body;

  /// 响应体 / Response body
  final dynamic responseBody;

  /// HTTP状态码 / HTTP status code
  final int? statusCode;

  /// 请求发送时间戳（毫秒）/ Request send timestamp (milliseconds)
  final int requestTime;

  /// 响应接收时间戳（毫秒）/ Response receive timestamp (milliseconds)
  final int? responseTime;

  /// 请求耗时（毫秒）/ Request duration (milliseconds)
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

  /// 获取状态码，默认为-1 / Get status code, default is -1
  int get status => statusCode ?? -1;

  /// 判断请求是否成功（200-299）/ Check if request is successful (200-299)
  bool get isSuccess => statusCode != null && statusCode! >= 200 && statusCode! < 300;

  /// 格式化后的耗时文本 / Formatted duration text
  String get durationText {
    if (duration == null) return '-';
    if (duration! < 1000) return '${duration}ms';
    return '${(duration! / 1000).toStringAsFixed(2)}s';
  }
}