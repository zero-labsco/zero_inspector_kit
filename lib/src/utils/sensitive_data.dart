/// 敏感数据脱敏 / Sensitive data masking
///
/// 集中处理导出 / 复制 / 分享前的脱敏，覆盖三个此前完全没覆盖的泄漏面：
/// Centralizes masking for export / copy / share, covering three surfaces that
/// were previously not masked at all:
///
/// 1. **请求头** —— 此前是硬编码的 7 个名字且只做全等匹配，`x-api-key`、
///    `x-auth-token-v2` 这类变体全部漏网。
///    **Headers** — previously 7 hardcoded names matched by equality only, so
///    variants like `x-api-key` / `x-auth-token-v2` slipped through.
/// 2. **URL query** —— `?token=...` / `?sig=...` 此前原样导出。
///    **URL query** — `?token=...` / `?sig=...` were exported verbatim.
/// 3. **请求 / 响应体** —— JSON 里的 `password` / `access_token` 此前原样导出。
///    **Request / response body** — `password` / `access_token` inside JSON were
///    exported verbatim.
///
/// 宿主 App 可通过 [extraSensitiveHeaderNames] / [extraSensitiveHeaderPatterns]
/// / [extraSensitiveKeys] 追加自己的敏感字段（例如内部私有头）。
/// Host apps can register their own sensitive fields (e.g. private internal
/// headers) via [extraSensitiveHeaderNames] / [extraSensitiveHeaderPatterns] /
/// [extraSensitiveKeys].
class SensitiveData {
  SensitiveData._();

  /// 脱敏占位符 / Mask placeholder
  static const String placeholder = '***';

  /// 精确匹配的敏感请求头（小写）/ Sensitive header names matched exactly (lowercase)
  static const Set<String> sensitiveHeaderNames = {
    'authorization',
    'proxy-authorization',
    'www-authenticate',
    'cookie',
    'set-cookie',
    'x-auth-token',
    'x-csrf-token',
    'x-xsrf-token',
    'x-api-key',
    'api-key',
    'authentication',
    'x-session-token',
    'x-refresh-token',
    'x-amz-security-token',
    'x-goog-api-key',
    'x-firebase-auth',
    'x-shopify-access-token',
    // 检查器自身的关联头：既不该出现在面板里，也不该被导出 / 重放。
    // The inspector's own correlation header: it belongs neither in the panel
    // nor in exports / replays.
    'x-inspector-request-id',
  };

  /// 包含匹配的敏感请求头模式（不区分大小写）
  /// Sensitive header name patterns matched by containment (case-insensitive)
  ///
  /// 覆盖 `x-auth-token-v2`、`x-my-secret-header` 这类命名变体。
  /// Covers naming variants such as `x-auth-token-v2` / `x-my-secret-header`.
  static final List<RegExp> sensitiveHeaderPatterns = [
    RegExp(r'auth', caseSensitive: false),
    RegExp(r'token', caseSensitive: false),
    RegExp(r'cookie', caseSensitive: false),
    RegExp(r'secret', caseSensitive: false),
    RegExp(r'passw(or)?d|passwd|pwd', caseSensitive: false),
    RegExp(r'api[-_]?key', caseSensitive: false),
    RegExp(r'credential', caseSensitive: false),
    RegExp(r'signature|\bsig\b', caseSensitive: false),
    RegExp(r'^x-inspector-', caseSensitive: false),
  ];

  /// 精确匹配的敏感键名（用于 URL query 与 JSON body）
  /// Sensitive key names matched exactly (for URL query and JSON body)
  static final Set<String> sensitiveKeys = {
    'token',
    'access_token',
    'accesstoken',
    'refresh_token',
    'refreshtoken',
    'id_token',
    'idtoken',
    'auth',
    'authorization',
    'password',
    'passwd',
    'pwd',
    'secret',
    'client_secret',
    'api_key',
    'apikey',
    'key',
    'sig',
    'signature',
    'session_token',
    'sessiontoken',
    'csrf',
    'xsrf',
  };

  /// 宿主可追加的敏感请求头名 / Extra sensitive header names contributed by the host
  static final Set<String> extraSensitiveHeaderNames = {};

  /// 宿主可追加的敏感请求头模式 / Extra sensitive header patterns from the host
  static final List<RegExp> extraSensitiveHeaderPatterns = [];

  /// 宿主可追加的敏感键名 / Extra sensitive key names from the host
  static final Set<String> extraSensitiveKeys = {};

  /// 判断请求头名是否敏感 / Whether a header name is sensitive
  static bool isSensitiveHeader(String name) {
    final lower = name.toLowerCase();
    if (sensitiveHeaderNames.contains(lower)) return true;
    if (extraSensitiveHeaderNames.contains(lower)) return true;
    for (final p in sensitiveHeaderPatterns) {
      if (p.hasMatch(name)) return true;
    }
    for (final p in extraSensitiveHeaderPatterns) {
      if (p.hasMatch(name)) return true;
    }
    return false;
  }

  /// 判断数据键名（URL query 参数名 / JSON 字段名）是否敏感
  /// Whether a data key (URL query param / JSON field) is sensitive
  static bool isSensitiveKey(String key) {
    final lower = key.toLowerCase();
    if (sensitiveKeys.contains(lower)) return true;
    if (extraSensitiveKeys.contains(lower)) return true;
    return isSensitiveHeader(lower);
  }

  /// 遮蔽请求头 Map 中的敏感项 / Mask sensitive entries in a header map
  static Map<String, String> maskHeaders(Map<String, String> headers) {
    return headers.map(
      (key, value) =>
          MapEntry(key, isSensitiveHeader(key) ? placeholder : value),
    );
  }

  /// 遮蔽 URL 中的敏感 query 参数值 / Mask sensitive query values in a URL
  ///
  /// 无法解析或没有 query 时原样返回（不因脱敏而破坏 URL）。
  /// Returns the input unchanged when it cannot be parsed or has no query, so
  /// masking never corrupts a URL.
  static String maskUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    final query = uri.queryParameters;
    if (query.isEmpty) return url;
    var changed = false;
    final masked = <String, String>{};
    for (final entry in query.entries) {
      if (isSensitiveKey(entry.key)) {
        masked[entry.key] = placeholder;
        changed = true;
      } else {
        masked[entry.key] = entry.value;
      }
    }
    if (!changed) return url;
    try {
      return uri.replace(queryParameters: masked).toString();
    } catch (_) {
      // queryParameters 替换失败（如含非常规字符）时退化为字符串级替换。
      // Fall back to string-level replacement when queryParameters rewrite
      // fails (e.g. unusual characters).
      var out = url;
      for (final entry in query.entries) {
        if (isSensitiveKey(entry.key)) {
          out = out.replaceAll(
            '${entry.key}=${Uri.encodeComponent(entry.value)}',
            '${entry.key}=$placeholder',
          );
          out = out.replaceAll(
            '${entry.key}=${entry.value}',
            '${entry.key}=$placeholder',
          );
        }
      }
      return out;
    }
  }

  /// JSON `"key": "value"` 对（值可能是任意 JSON 字面量）
  /// JSON `"key": "value"` pairs (value may be any JSON literal)
  static final RegExp _jsonPair = RegExp(
    r'("(?:[^"\\]|\\.)*")(\s*:\s*)("(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?|true|false|null)',
  );

  /// `Bearer <token>` 形式的凭据 / `Bearer <token>` credentials
  static final RegExp _bearer = RegExp(
    r'(Bearer\s+)[A-Za-z0-9\-._~+/=]+',
    caseSensitive: false,
  );

  /// JWT（三段 base64url，以 `ey` 开头）/ JWT (three base64url segments, starting with `ey`)
  static final RegExp _jwt = RegExp(
    r'\bey[A-Za-z0-9_-]{6,}\.[A-Za-z0-9_-]{4,}\.[A-Za-z0-9_-]{4,}',
  );

  /// 遮蔽 body 中的敏感内容 / Mask sensitive content in a body
  ///
  /// 先按 JSON 字段脱敏，再兜底处理 Bearer 凭据与 JWT，
  /// 最后失败时原样返回（脱敏不应导致内容丢失）。
  /// Masks JSON fields first, then falls back to Bearer credentials and JWTs,
  /// returning the input unchanged on failure (masking must not lose content).
  static String maskBody(String body) {
    if (body.isEmpty) return body;
    try {
      var out = body.replaceAllMapped(_jsonPair, (m) {
        final rawKey = m.group(1)!;
        final key = rawKey.substring(1, rawKey.length - 1);
        if (!isSensitiveKey(key)) return m.group(0)!;
        final value = m.group(3)!;
        // 字符串值替换为带引号的占位符，其余字面量直接替换，保持 JSON 合法。
        // Quote the placeholder for string values, replace literals as-is, so
        // the result stays valid JSON.
        final maskedValue = value.startsWith('"') ? '"$placeholder"' : 'null';
        return '$rawKey${m.group(2)}$maskedValue';
      });
      out = out.replaceAllMapped(_bearer, (m) => '${m.group(1)}$placeholder');
      out = out.replaceAllMapped(_jwt, (_) => placeholder);
      return out;
    } catch (_) {
      return body;
    }
  }

  /// 对任意文本做兜底脱敏（Bearer / JWT），用于非 JSON 内容
  /// Best-effort masking (Bearer / JWT) for non-JSON content
  static String maskText(String text) {
    if (text.isEmpty) return text;
    try {
      var out = text.replaceAllMapped(
        _bearer,
        (m) => '${m.group(1)}$placeholder',
      );
      out = out.replaceAllMapped(_jwt, (_) => placeholder);
      return out;
    } catch (_) {
      return text;
    }
  }

  /// 按内容类型选择脱敏策略：JSON 走字段级，其余走文本级。
  /// Pick the masking strategy by content: field-level for JSON, text otherwise.
  static String maskBodyByContent(String body) {
    final trimmed = body.trimLeft();
    if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
      return maskBody(body);
    }
    return maskText(body);
  }
}
