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
  bool get isSuccess =>
      statusCode != null && statusCode! >= 200 && statusCode! < 300;

  /// 格式化后的耗时文本 / Formatted duration text
  String get durationText {
    if (duration == null) return '-';
    if (duration! < 1000) return '${duration}ms';
    return '${(duration! / 1000).toStringAsFixed(2)}s';
  }

  /// 转换为 JSON / Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'method': method,
      'url': url,
      'headers': headers,
      'body': body?.toString(),
      'responseBody': responseBody?.toString(),
      'statusCode': statusCode,
      'requestTime': requestTime,
      'responseTime': responseTime,
      'duration': duration,
    };
  }

  /// 复制并可选更新字段。当 [maxBodyBytes] 大于 0 时，对 body/responseBody 做头部预览截断。
  /// Copy with optional field updates. When [maxBodyBytes] > 0, body/responseBody are
  /// truncated to a head preview to cap memory usage.
  NetworkRequest copyWith({
    String? id,
    String? method,
    String? url,
    Map<String, String>? headers,
    dynamic body,
    dynamic responseBody,
    int? statusCode,
    int? requestTime,
    int? responseTime,
    int? duration,
    int maxBodyBytes = 0,
  }) {
    final truncatedBody = maxBodyBytes > 0
        ? _truncate(body, maxBodyBytes)
        : body;
    final truncatedResponse = maxBodyBytes > 0
        ? _truncate(responseBody, maxBodyBytes)
        : responseBody;
    return NetworkRequest(
      id: id ?? this.id,
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      body: truncatedBody,
      responseBody: truncatedResponse,
      statusCode: statusCode ?? this.statusCode,
      requestTime: requestTime ?? this.requestTime,
      responseTime: responseTime ?? this.responseTime,
      duration: duration ?? this.duration,
    );
  }

  /// 将 [value] 截断为不超过 [maxBytes] 字符的头部预览；超长时附截断提示。
  /// Truncate [value] to a head preview no longer than [maxBytes] chars; append a note when clipped.
  static dynamic _truncate(dynamic value, int maxBytes) {
    if (value == null) return value;
    final str = value.toString();
    if (str.length <= maxBytes) return str;
    return '${str.substring(0, maxBytes)}\n'
        '[… truncated ${str.length - maxBytes} chars …]';
  }
}
