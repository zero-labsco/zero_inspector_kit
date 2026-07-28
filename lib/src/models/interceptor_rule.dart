/// 请求拦截规则模型 / Request interceptor rule model
///
/// 用于定义网络请求的修改规则，支持：
/// - URL + Method 匹配
/// - 请求参数修改（headers、body）
/// - 响应参数修改（statusCode、headers、body）
///
/// Used to define modification rules for network requests, supporting:
/// - URL + Method matching
/// - Request parameter modification (headers, body)
/// - Response parameter modification (statusCode, headers, body)
class RequestInterceptorRule {
  /// 规则唯一ID / Rule unique ID
  final String id;

  /// 规则名称 / Rule name
  final String name;

  /// URL匹配模式 / URL matching pattern
  final String urlPattern;

  /// HTTP方法（GET、POST、PUT、DELETE等，为空则匹配所有方法）
  /// HTTP method (GET, POST, PUT, DELETE, etc., empty matches all)
  final String method;

  /// 是否启用 / Whether enabled
  final bool enabled;

  /// 是否使用正则匹配URL / Whether to use regex for URL matching
  final bool useRegex;

  /// 请求头修改（键值对，为空则不修改）/ Request headers modification
  final Map<String, String>? requestHeaders;

  /// 请求体修改（为空则不修改）/ Request body modification
  final dynamic requestBody;

  /// 响应状态码修改（为空则不修改）/ Response status code modification
  final int? responseStatusCode;

  /// 响应头修改（键值对，为空则不修改）/ Response headers modification
  final Map<String, String>? responseHeaders;

  /// 响应体修改（为空则不修改）/ Response body modification
  final dynamic responseBody;

  RequestInterceptorRule({
    required this.id,
    required this.name,
    required this.urlPattern,
    this.method = '',
    this.enabled = true,
    this.useRegex = false,
    this.requestHeaders,
    this.requestBody,
    this.responseStatusCode,
    this.responseHeaders,
    this.responseBody,
  });

  /// 判断是否匹配指定的请求 / Check if matches the specified request
  /// [url] 请求URL / Request URL
  /// [method] 请求方法 / Request method
  bool matches(String url, String method) {
    if (!enabled) return false;

    final methodMatches =
        this.method.isEmpty ||
        this.method.toUpperCase() == method.toUpperCase();
    if (!methodMatches) return false;

    if (useRegex) {
      try {
        final regex = RegExp(urlPattern);
        return regex.hasMatch(url);
      } catch (_) {
        return false;
      }
    } else {
      return url == urlPattern;
    }
  }

  /// 创建副本 / Create a copy
  RequestInterceptorRule copyWith({
    String? id,
    String? name,
    String? urlPattern,
    String? method,
    bool? enabled,
    bool? useRegex,
    Map<String, String>? requestHeaders,
    dynamic requestBody,
    int? responseStatusCode,
    Map<String, String>? responseHeaders,
    dynamic responseBody,
  }) {
    return RequestInterceptorRule(
      id: id ?? this.id,
      name: name ?? this.name,
      urlPattern: urlPattern ?? this.urlPattern,
      method: method ?? this.method,
      enabled: enabled ?? this.enabled,
      useRegex: useRegex ?? this.useRegex,
      requestHeaders: requestHeaders ?? this.requestHeaders,
      requestBody: requestBody ?? this.requestBody,
      responseStatusCode: responseStatusCode ?? this.responseStatusCode,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
    );
  }
}
