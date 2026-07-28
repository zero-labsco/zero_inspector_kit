import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/network_request.dart';
import '../models/interceptor_rule.dart';
import '../services/inspector_service.dart';

/// HTTP 请求拦截器 / HTTP request interceptor
/// 通过 HttpOverrides 机制实现全局 HTTP 请求拦截 / Implement global HTTP request interception via HttpOverrides mechanism
///
/// 使用方式：/ Usage:
/// 1. 调用 start() 方法启用全局拦截 / Call start() to enable global interception
/// 2. 使用 http.get() / http.post() / http.put() / http.delete() / http.patch() / http.head() 等方法发送请求，会自动被捕获
///    / Use http.get() / http.post() / http.put() / http.delete() / http.patch() / http.head() etc., requests will be auto-captured
///
/// 注意：此拦截器工作在 dart:io 的 HttpClient 层，因此可以同时捕获：/ Note: This interceptor works at the dart:io HttpClient level, so it can capture:
/// - http 包发起的所有请求（get/post/put/delete/patch/head）/ - All requests from http package (get/post/put/delete/patch/head)
/// - Dio 发起的所有请求（Dio 默认使用 IOHttpClientAdapter，底层也是 HttpClient）/ - All requests from Dio (Dio uses IOHttpClientAdapter by default)
/// - 任何其他使用 HttpClient 的库发起的请求 / - Any requests from other libraries using HttpClient
class InspectorHttpInterceptor {
  InspectorHttpInterceptor._();

  static final InspectorHttpInterceptor instance = InspectorHttpInterceptor._();

  bool _started = false;

  /// 启动全局 HTTP 请求拦截 / Start global HTTP request interception
  /// 通过 HttpOverrides 机制，自动捕获应用中所有使用 HttpClient 的网络请求
  /// Auto-capture all network requests using HttpClient via HttpOverrides mechanism
  void start() {
    if (_started) return;
    _started = true;
    HttpOverrides.global = _InspectorHttpOverrides();
  }

  /// 停止全局 HTTP 请求拦截 / Stop global HTTP request interception
  void stop() {
    if (!_started) return;
    _started = false;
    HttpOverrides.global = null;
  }

  /// 是否已启动全局拦截 / Whether global interception has started
  bool get isStarted => _started;
}

/// HTTP 请求覆盖类 / HTTP request override class
/// 通过 HttpOverrides 机制实现全局 HTTP 请求拦截 / Implement global HTTP request interception via HttpOverrides mechanism
class _InspectorHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _InspectorHttpClient(super.createHttpClient(context));
  }
}

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

/// 检查器 HttpClientResponse 代理 / Inspector HttpClientResponse proxy
/// 包装原始 HttpClientResponse，在响应返回时记录响应信息到检查器服务
/// 支持应用拦截规则修改响应参数
/// Wrap original HttpClientResponse, record response info to inspector service when received
/// Support applying interceptor rules to modify response parameters
class _InspectorResponseProxy implements HttpClientResponse {
  final HttpClientResponse _response;
  final String? _requestId;
  final String? _requestUrl;
  final String? _requestMethod;
  final List<int> _bodyBytes = [];
  bool _isCaptured = false;

  _InspectorResponseProxy(
    this._response,
    this._requestId, {
    String? requestUrl,
    String? requestMethod,
  }) : _requestUrl = requestUrl,
       _requestMethod = requestMethod;

  void _captureResponse([bool isError = false]) {
    if (_isCaptured) return;
    _isCaptured = true;
    try {
      if (_requestId != null) {
        final body = utf8.decode(_bodyBytes);
        InspectorService.instance.updateNetworkRequest(
          _requestId,
          statusCode: _response.statusCode,
          responseBody: body,
        );
      }
    } catch (_) {}
  }

  RequestInterceptorRule? _getRule() {
    if (_requestUrl == null || _requestMethod == null) return null;
    return InspectorService.instance.findMatchingRule(
      _requestUrl,
      _requestMethod,
    );
  }

  @override
  int get statusCode {
    final rule = _getRule();
    if (rule?.responseStatusCode != null) {
      return rule!.responseStatusCode!;
    }
    return _response.statusCode;
  }

  @override
  String get reasonPhrase => _response.reasonPhrase;

  @override
  HttpHeaders get headers => _response.headers;

  @override
  int get contentLength {
    final rule = _getRule();
    if (rule?.responseBody != null) {
      final body = rule!.responseBody;
      final bodyStr = body is String ? body : jsonEncode(body);
      return utf8.encode(bodyStr).length;
    }
    return _response.contentLength;
  }

  @override
  bool get isRedirect => _response.isRedirect;

  @override
  List<RedirectInfo> get redirects => _response.redirects;

  @override
  X509Certificate? get certificate => _response.certificate;

  @override
  HttpClientResponseCompressionState get compressionState =>
      _response.compressionState;

  @override
  bool get persistentConnection => _response.persistentConnection;

  @override
  Future<Socket> detachSocket() => _response.detachSocket();

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) => _response.redirect(method, url, followLoops);

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  List<Cookie> get cookies => _response.cookies;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _wrappedStream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  bool get isBroadcast => _response.isBroadcast;

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(List<int> event) convert) =>
      _wrappedStream.asyncExpand(convert);

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(List<int> event) convert) =>
      _wrappedStream.asyncMap(convert);

  @override
  Stream<List<int>> asBroadcastStream({
    void Function(StreamSubscription<List<int>>)? onListen,
    void Function(StreamSubscription<List<int>>)? onCancel,
  }) =>
      _wrappedStream.asBroadcastStream(onListen: onListen, onCancel: onCancel);

  @override
  Future<bool> contains(Object? needle) => _wrappedStream.contains(needle);

  @override
  Future<bool> any(bool Function(List<int> element) test) =>
      _wrappedStream.any(test);

  @override
  Stream<List<int>> handleError(
    Function onError, {
    bool Function(dynamic error)? test,
  }) => _wrappedStream.handleError(onError, test: test);

  @override
  Stream<E> map<E>(E Function(List<int> event) convert) =>
      _wrappedStream.map(convert);

  @override
  Stream<List<int>> skip(int count) => _wrappedStream.skip(count);

  @override
  Stream<List<int>> take(int count) => _wrappedStream.take(count);

  @override
  Stream<List<int>> where(bool Function(List<int> element) test) =>
      _wrappedStream.where(test);

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) =>
      _wrappedStream.transform(streamTransformer);

  Stream<List<int>> get _wrappedStream {
    final rule = _getRule();

    if (rule?.responseBody != null) {
      return Stream.fromFuture(_getModifiedResponse(rule!));
    }

    return _response.transform(
      StreamTransformer<List<int>, List<int>>.fromHandlers(
        handleData: (chunk, sink) {
          _bodyBytes.addAll(chunk);
          sink.add(chunk);
        },
        handleDone: (sink) {
          _captureResponse();
          sink.close();
        },
        handleError: (error, stackTrace, sink) {
          _captureResponse(true);
          sink.addError(error, stackTrace);
        },
      ),
    );
  }

  Future<List<int>> _getModifiedResponse(RequestInterceptorRule rule) async {
    await _consumeOriginalResponse();

    try {
      if (_requestId != null) {
        final body = rule.responseBody;
        final bodyStr = body is String ? body : jsonEncode(body);
        InspectorService.instance.updateNetworkRequest(
          _requestId,
          statusCode: rule.responseStatusCode ?? _response.statusCode,
          responseBody: bodyStr,
        );
      }
    } catch (_) {}

    final body = rule.responseBody;
    final bodyStr = body is String ? body : jsonEncode(body);
    return utf8.encode(bodyStr);
  }

  Future<void> _consumeOriginalResponse() async {
    try {
      await _response.drain();
    } catch (_) {}
  }

  @override
  Future<List<List<int>>> toList() => _wrappedStream.toList();

  @override
  Future<String> join([String separator = '']) =>
      _wrappedStream.join(separator);

  @override
  Future<T> fold<T>(
    T initialValue,
    T Function(T previous, List<int> element) combine,
  ) => _wrappedStream.fold(initialValue, combine);

  @override
  Future<bool> every(bool Function(List<int> element) test) =>
      _wrappedStream.every(test);

  @override
  Future<List<int>> firstWhere(
    bool Function(List<int> element) test, {
    List<int> Function()? orElse,
  }) => _wrappedStream.firstWhere(test, orElse: orElse);

  @override
  Future<List<int>> lastWhere(
    bool Function(List<int> element) test, {
    List<int> Function()? orElse,
  }) => _wrappedStream.lastWhere(test, orElse: orElse);

  @override
  Future<List<int>> singleWhere(
    bool Function(List<int> element) test, {
    List<int> Function()? orElse,
  }) => _wrappedStream.singleWhere(test, orElse: orElse);

  @override
  Future<List<int>> get first => _wrappedStream.first;

  @override
  Future<List<int>> get last => _wrappedStream.last;

  @override
  Future<bool> get isEmpty => _wrappedStream.isEmpty;

  @override
  Future<int> get length => _wrappedStream.length;

  @override
  Future<List<int>> get single => _wrappedStream.single;

  @override
  Future<List<int>> reduce(
    List<int> Function(List<int> previous, List<int> element) combine,
  ) => _wrappedStream.reduce(combine);

  @override
  Future<void> forEach(void Function(List<int> element) action) =>
      _wrappedStream.forEach(action);

  @override
  Stream<S> expand<S>(Iterable<S> Function(List<int> element) expand) =>
      _wrappedStream.expand(expand);

  @override
  Stream<List<int>> skipWhile(bool Function(List<int> element) test) =>
      _wrappedStream.skipWhile(test);

  @override
  Stream<List<int>> takeWhile(bool Function(List<int> element) test) =>
      _wrappedStream.takeWhile(test);

  @override
  Stream<List<int>> distinct([
    bool Function(List<int> previous, List<int> next)? equals,
  ]) => _wrappedStream.distinct(equals);

  @override
  Stream<List<int>> timeout(
    Duration timeLimit, {
    void Function(EventSink<List<int>> sink)? onTimeout,
  }) => _wrappedStream.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<T> drain<T>([T? futureValue]) => _wrappedStream.drain(futureValue);

  @override
  Future<List<int>> elementAt(int index) => _wrappedStream.elementAt(index);

  @override
  Future pipe(StreamConsumer<List<int>> streamConsumer) =>
      _wrappedStream.pipe(streamConsumer);

  @override
  Future<Set<List<int>>> toSet() => _wrappedStream.toSet();

  @override
  Stream<T> cast<T>() => _wrappedStream.cast<T>();
}
