import 'dart:convert';

/// 状态码分组（用于「按状态码区间筛选」维度）。
/// Status-code groups (for the "filter by status-code range" dimension).
enum StatusGroup {
  s2xx(200, 299, '2xx'),
  s3xx(300, 399, '3xx'),
  s4xx(400, 499, '4xx'),
  s5xx(500, 599, '5xx'),
  unknown(-1, -1, 'Other');

  const StatusGroup(this.min, this.max, this.label);

  /// 区间下界（含）/ Inclusive lower bound.
  final int min;

  /// 区间上界（含）/ Inclusive upper bound.
  final int max;

  /// 展示标签 / Display label.
  final String label;

  /// 判断 [code] 是否落入本分组。
  /// [code] 为 null 时仅 [unknown] 命中；[unknown] 命中所有 200-599 之外的码。
  /// Returns true when [code] belongs to this group. A null [code] only matches
  /// [unknown]; [unknown] matches any code outside 200-599.
  bool contains(int? code) {
    if (code == null) return this == unknown;
    if (this == unknown) return code < 200 || code > 599;
    return code >= min && code <= max;
  }
}

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

  /// 该请求是否被某条拦截规则实际修改过（请求体/响应体/状态码等）。
  /// 用于「按拦截状态筛选」。默认 false。
  /// Whether this request was actually modified by an interceptor rule
  /// (request body / response body / status code, etc.). Used by the
  /// "filter by interception status" dimension. Defaults to false.
  final bool isModifiedByInterceptor;

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
    this.isModifiedByInterceptor = false,
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
      'body': _jsonSafe(body),
      'responseBody': _jsonSafe(responseBody),
      'statusCode': statusCode,
      'requestTime': requestTime,
      'responseTime': responseTime,
      'duration': duration,
      'isModifiedByInterceptor': isModifiedByInterceptor,
    };
  }

  /// 将 [value] 安全序列化为 JSON 友好的字符串：Map / List 用 [jsonEncode]，
  /// 其它类型用 [toString]。避免经 Dio 传入的 Map 被 [toString] 成 Dart 字面量、
  /// 导出后无法解析还原。
  /// Serialize [value] into a JSON-friendly string: Map / List via [jsonEncode],
  /// others via [toString]. Avoids Dio-supplied Maps being turned into Dart
  /// literals by [toString] and becoming unparseable after export.
  static dynamic _jsonSafe(dynamic value) {
    if (value == null) return null;
    if (value is Map || value is List) {
      try {
        return jsonEncode(value);
      } catch (_) {
        // 极少数不可 JSON 化的对象回退到 toString。
        // Fall back to toString() for the rare non-JSON-encodable value.
      }
    }
    return value.toString();
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
    bool? isModifiedByInterceptor,
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
      isModifiedByInterceptor:
          isModifiedByInterceptor ?? this.isModifiedByInterceptor,
    );
  }

  /// 将 [value] 截断为不超过 [maxBytes] **字节**（UTF-8）的头部预览；超长时附截断提示。
  /// 此前按 UTF-16 字符数截断，中文 / gzip base64 场景下会低估约 2-3 倍预算，导致
  /// body 实际比上限长很多。现在按真实字节数截断，与全局 body 预算的单位一致。
  /// Truncate [value] to a head preview no longer than [maxBytes] **UTF-8 bytes**.
  /// Previously it counted UTF-16 chars, underestimating the budget ~2-3x for CJK /
  /// gzip base64; now it matches the global body budget's unit (bytes).
  static dynamic _truncate(dynamic value, int maxBytes) {
    if (value == null) return value;
    final str = value.toString();
    final bytes = utf8.encode(str);
    if (bytes.length <= maxBytes) return str;
    // 按字节截断后再解码为合法字符串，避免截断在字符中途产生乱码。
    // Truncate by bytes, then decode back to a valid string (no mid-codeunit split).
    var end = maxBytes;
    while (end > 0) {
      try {
        final slice = utf8.decode(bytes.sublist(0, end));
        return '$slice\n[… truncated ${bytes.length - end} bytes …]';
      } on FormatException {
        end--;
      }
    }
    return '[… truncated ${bytes.length} bytes …]';
  }
}
