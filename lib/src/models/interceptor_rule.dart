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

  /// 编译后的正则（惰性、按实例缓存）/ Compiled regex (lazy, per-instance cache)
  ///
  /// `matches()` 会被热路径反复调用：`_InspectorResponseProxy._getRule()` 在
  /// `statusCode` / `headers` / `contentLength` / `_wrappedStream` 四处被调用，
  /// 而只读一次状态码就会走到两次全规则遍历 —— 每次都重新 `RegExp(pattern)`
  /// 编译一份，是纯粹的浪费。[urlPattern] 是 final，缓存永远有效。
  /// `matches()` runs on a hot path: `_InspectorResponseProxy._getRule()` is called
  /// from `statusCode` / `headers` / `contentLength` / `_wrappedStream`, and
  /// reading the status code once already triggers two full rule scans — each of
  /// which used to recompile `RegExp(pattern)`. [urlPattern] is final, so the
  /// cache is always valid.
  RegExp? _cachedRegex;
  bool _regexCompiled = false;

  RegExp? get _regex {
    if (!_regexCompiled) {
      _regexCompiled = true;
      try {
        _cachedRegex = RegExp(urlPattern);
      } catch (_) {
        _cachedRegex = null;
      }
    }
    return _cachedRegex;
  }

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
      final regex = _regex;
      return regex?.hasMatch(url) ?? false;
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
