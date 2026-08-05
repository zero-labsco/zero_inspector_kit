part of 'http_interceptor.dart';

/// 检查器 HttpClient 代理类 / Inspector HttpClient proxy class
/// 使用代理模式包装原始 HttpClient，拦截请求和响应
/// Use proxy pattern to wrap original HttpClient, intercept requests and responses
class _InspectorHttpClient implements HttpClient {
  final HttpClient _client;
  bool _closed = false;

  _InspectorHttpClient(this._client);

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) {
    final scheme = port == 443 ? 'https' : 'http';
    return openUrl(
      method,
      Uri(scheme: scheme, host: host, port: port, path: path),
    );
  }

  static const String _dioRequestIdHeader = 'x-inspector-request-id';

  /// 判断是否为 WebSocket 升级握手请求 / Check if this is a WebSocket upgrade handshake
  ///
  /// WebSocket 握手本质上是带 Upgrade: websocket 的 HTTP 请求，
  /// 会被 HttpOverrides 拦截并显示在网络列表中，造成刷屏。
  /// WebSocket handshake is essentially an HTTP request with Upgrade: websocket,
  /// which gets intercepted by HttpOverrides and floods the network list.
  /// 这里通过 URL path 以 `/ws` 结尾进行过滤（覆盖 VM Service 等常见端点）
  /// Filters by URL path ending with `/ws` (covers common VM Service endpoints)
  bool _isWebSocketHandshake(Uri url) {
    final path = url.path;
    return path.endsWith('/ws');
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    final isWs = _isWebSocketHandshake(url);

    String? requestId;
    if (!isWs) {
      try {
        requestId =
            'req_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
      } catch (_) {}
    }

    return _client
        .openUrl(method, url)
        .then((request) {
          final dioRequestId = request.headers.value(_dioRequestIdHeader);
          if (dioRequestId != null) {
            return _InspectorRequestProxy(request, dioRequestId);
          }
          // 跳过 WebSocket 握手请求，避免网络列表被 VM Service 等连接刷屏
          // Skip WebSocket handshake requests to avoid flooding the network list
          if (isWs) {
            return _InspectorRequestProxy(request, null);
          }
          try {
            if (requestId != null) {
              InspectorService.instance.addNetworkRequest(
                NetworkRequest(
                  id: requestId,
                  method: method,
                  url: url.toString(),
                  requestTime: DateTime.now().millisecondsSinceEpoch,
                ),
              );
            }
          } catch (_) {}
          return _InspectorRequestProxy(request, requestId);
        })
        .catchError((error, stackTrace) {
          try {
            if (requestId != null) {
              InspectorService.instance.addNetworkRequest(
                NetworkRequest(
                  id: requestId,
                  method: method,
                  url: url.toString(),
                  requestTime: DateTime.now().millisecondsSinceEpoch,
                  responseBody: error.toString(),
                  statusCode: -1,
                ),
              );
            }
          } catch (_) {}
          throw error;
        });
  }

  @override
  void close({bool force = false}) {
    if (!_closed) {
      _closed = true;
      _client.close(force: force);
    }
  }

  @override
  bool get autoUncompress => _client.autoUncompress;

  @override
  set autoUncompress(bool value) => _client.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _client.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _client.connectionTimeout = value;

  @override
  String? get userAgent => _client.userAgent;

  @override
  set userAgent(String? value) => _client.userAgent = value;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) => _client.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) => _client.addProxyCredentials(host, port, realm, credentials);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      open('DELETE', host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => openUrl('DELETE', url);

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      open('GET', host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => openUrl('GET', url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      open('HEAD', host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => openUrl('HEAD', url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      open('PATCH', host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => openUrl('PATCH', url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      open('POST', host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => openUrl('POST', url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      open('PUT', host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => openUrl('PUT', url);

  @override
  Duration get idleTimeout => _client.idleTimeout;

  @override
  set idleTimeout(Duration value) => _client.idleTimeout = value;

  @override
  set authenticate(Future<bool> Function(Uri, String, String?)? f) =>
      _client.authenticate = f;

  @override
  set authenticateProxy(
    Future<bool> Function(String, int, String, String?)? f,
  ) => _client.authenticateProxy = f;

  @override
  set badCertificateCallback(
    bool Function(X509Certificate, String, int)? callback,
  ) => _client.badCertificateCallback = callback;

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri host,
      String? proxyHost,
      int? proxyPort,
    )?
    f,
  ) => _client.connectionFactory = f;

  @override
  set findProxy(String Function(Uri)? f) => _client.findProxy = f;

  @override
  int? get maxConnectionsPerHost => _client.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) =>
      _client.maxConnectionsPerHost = value;

  @override
  set keyLog(void Function(String line)? callback) => _client.keyLog = callback;

  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    var random = DateTime.now().microsecond;
    return List.generate(length, (_) {
      random =
          (random ^ (random << 13)) ^
          ((random ^ (random << 13)) >> 17) ^
          (((random ^ (random << 13)) ^ ((random ^ (random << 13)) >> 17)) <<
              5);
      return chars[random.abs() % chars.length];
    }).join();
  }
}

/// 检查器 HttpClientRequest 代理 / Inspector HttpClientRequest proxy
/// 包装原始 HttpClientRequest，在响应返回时记录响应信息，同时捕获请求体数据
/// 支持在发送前应用拦截规则修改请求参数
/// Wrap original HttpClientRequest, record response info when response is received, capture request body data
/// Support applying interceptor rules to modify request parameters before sending
class _InspectorRequestProxy implements HttpClientRequest {
  final HttpClientRequest _request;
  final String? _requestId;
  final List<int> _bodyBytes = [];
  bool _isClosed = false;

  _InspectorRequestProxy(this._request, this._requestId);

  @override
  Future<HttpClientResponse> close() async {
    if (_isClosed) {
      return _request.done.then(
        (response) => _InspectorResponseProxy(response, _requestId),
      );
    }
    _isClosed = true;

    List<int> finalBodyBytes = List.from(_bodyBytes);
    String? finalBody;

    try {
      final rule = InspectorService.instance.findMatchingRule(
        _request.uri.toString(),
        _request.method,
      );

      if (rule != null) {
        if (rule.requestHeaders != null) {
          for (final entry in rule.requestHeaders!.entries) {
            _request.headers.set(entry.key, entry.value);
          }
        }

        if (rule.requestBody != null) {
          final modifiedBody = rule.requestBody;
          finalBody = modifiedBody is String
              ? modifiedBody
              : jsonEncode(modifiedBody);
          finalBodyBytes = utf8.encode(finalBody);
          _request.contentLength = finalBodyBytes.length;
        }
      }
    } catch (_) {}

    try {
      if (finalBodyBytes.isNotEmpty && _requestId != null) {
        final body = utf8.decode(finalBodyBytes);
        InspectorService.instance.updateNetworkRequest(_requestId, body: body);
      }
    } catch (_) {}

    try {
      await _request.addStream(Stream.value(finalBodyBytes));
    } catch (_) {}

    return _request
        .close()
        .then((response) {
          return _InspectorResponseProxy(
            response,
            _requestId,
            requestUrl: _request.uri.toString(),
            requestMethod: _request.method,
          );
        })
        .catchError((error, stackTrace) {
          try {
            if (_requestId != null) {
              InspectorService.instance.updateNetworkRequest(
                _requestId,
                responseBody: error.toString(),
                statusCode: -1,
              );
            }
          } catch (_) {}
          throw error;
        });
  }

  @override
  void add(List<int> data) {
    if (!_isClosed) {
      _bodyBytes.addAll(data);
    }
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _request.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<List<int>> stream) async {
    if (_isClosed) {
      await _request.addStream(stream);
      return;
    }
    await for (final chunk in stream) {
      _bodyBytes.addAll(chunk);
    }
  }

  @override
  Future<void> flush() => _request.flush();

  @override
  void write(Object? obj) {
    if (!_isClosed) {
      final bytes = utf8.encode(obj?.toString() ?? '');
      _bodyBytes.addAll(bytes);
    }
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    if (!_isClosed) {
      final bytes = utf8.encode(objects.join(separator));
      _bodyBytes.addAll(bytes);
    }
  }

  @override
  void writeCharCode(int charCode) {
    if (!_isClosed) {
      _bodyBytes.add(charCode);
    }
  }

  @override
  void writeln([Object? obj = '']) {
    if (!_isClosed) {
      final bytes = utf8.encode('${obj ?? ''}\n');
      _bodyBytes.addAll(bytes);
    }
  }

  @override
  bool get bufferOutput => _request.bufferOutput;

  @override
  set bufferOutput(bool value) => _request.bufferOutput = value;

  @override
  Encoding get encoding => _request.encoding;

  @override
  set encoding(Encoding value) => _request.encoding = value;

  @override
  HttpHeaders get headers => _request.headers;

  @override
  String get method => _request.method;

  @override
  int get contentLength => _request.contentLength;

  @override
  set contentLength(int value) => _request.contentLength = value;

  @override
  bool get followRedirects => _request.followRedirects;

  @override
  set followRedirects(bool value) => _request.followRedirects = value;

  @override
  int get maxRedirects => _request.maxRedirects;

  @override
  set maxRedirects(int value) => _request.maxRedirects = value;

  @override
  Uri get uri => _request.uri;

  @override
  bool get persistentConnection => _request.persistentConnection;

  @override
  set persistentConnection(bool value) => _request.persistentConnection = value;

  @override
  void abort([Object? exception, StackTrace? stackTrace]) =>
      _request.abort(exception, stackTrace);

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => _request.cookies;

  @override
  Future<HttpClientResponse> get done => _request.done.then(
    (response) => _InspectorResponseProxy(response, _requestId),
  );
}
