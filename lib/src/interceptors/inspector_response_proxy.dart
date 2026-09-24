part of 'http_interceptor.dart';

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
  bool _bodyCaptured = false;
  bool _statusCaptured = false;

  /// 响应体最大捕获字节数 / Max response body capture size in bytes
  ///
  /// 超过此大小的响应体不再完整缓冲，避免大文件下载导致 OOM
  /// Response bodies exceeding this size are not fully buffered to avoid OOM on large downloads
  static const int _maxCaptureBytes = 512 * 1024; // 512 KB

  /// 是否已超过捕获限制 / Whether capture limit has been exceeded
  bool _captureExceeded = false;

  _InspectorResponseProxy(
    this._response,
    this._requestId, {
    String? requestUrl,
    String? requestMethod,
  }) : _requestUrl = requestUrl,
       _requestMethod = requestMethod;

  /// 解析后的状态码（命中响应规则时取规则值，否则取原始值）。
  /// Resolved status code (rule value when a response rule matches, else original).
  int get _statusCodeResolved {
    final rule = _getRule();
    return rule?.responseStatusCode ?? _response.statusCode;
  }

  /// 落状态码（幂等、规则感知）：statusCode getter 首次访问时即调用，不依赖 body
  /// 流是否被消费，确保记录值与规则值一致。
  /// Persist the status code (idempotent, rule-aware): called on first access to
  /// the statusCode getter, independent of body consumption, so the recorded value
  /// matches the rule-aware value.
  void _captureStatusCode() {
    if (_statusCaptured) return;
    _statusCaptured = true;
    final id = _requestId;
    if (id == null) return;
    try {
      InspectorService.instance.updateNetworkRequest(
        id,
        statusCode: _statusCodeResolved,
      );
    } catch (_) {}
  }

  /// 落响应体（幂等）。若调用方只消费流、从不读 getter，这里兜底补一次状态码。
  /// Persist the response body (idempotent). If the caller only consumes the stream
  /// without reading the getter, capture the status code here too.
  void _captureBody() {
    if (_bodyCaptured) return;
    _bodyCaptured = true;
    final id = _requestId;
    if (id == null) return;
    // 兜底：确保状态码已落库。
    _captureStatusCode();
    try {
      final String body;
      if (_captureExceeded) {
        // contentLength 为 -1 表示 chunked 传输或无 Content-Length 头，
        // 此时不要把 -1 当作字节数显示给用户。
        // contentLength == -1 means chunked transfer or no Content-Length
        // header; don't display "-1 bytes" to the user.
        final len = _response.contentLength;
        final lenText = len > 0 ? '$len' : 'unknown size';
        body = '[Response body too large to capture ($lenText)]';
      } else {
        body = _decodeBodyOrHexPreview(
          _bodyBytes,
          maxChars: InspectorService.instance.maxBodyPreviewBytes,
        );
      }
      InspectorService.instance.updateNetworkRequest(id, responseBody: body);
    } catch (_) {}
  }

  /// 按 UTF-8 解码，失败时降级为"字节数 + 前若干字节 hex 预览"。
  /// Decode as UTF-8, falling back to a byte count + leading hex preview.
  ///
  /// 覆盖 gzip / br / protobuf / 图片等二进制响应：此前这些响应会直接抛异常，
  /// 导致整条记录（含状态码）丢失。
  /// Covers gzip / brotli / protobuf / image responses, which previously threw
  /// and lost the whole record (status code included).
  /// 小体积二进制响应改用 base64 承载，让面板能直接预览图片等内容
  /// Small binary responses are carried as base64 so the panel can preview them
  /// (images, etc.) instead of only showing a hex dump.
  static const int _maxBase64PreviewBytes = 64 * 1024; // 64 KB

  /// [maxChars] 为面板的预览字符上限：解码前先按它剪掉多余的尾部字节
  /// （见 [_bytesForPreviewDecode]）。base64 / hex 分支始终基于原始 [bytes]，
  /// 与预览截断无关。
  /// [maxChars] is the panel's preview char cap: trailing bytes beyond it are
  /// trimmed before decoding (see [_bytesForPreviewDecode]). The base64 / hex
  /// fallbacks always use the original [bytes] and are unaffected by trimming.
  static String _decodeBodyOrHexPreview(List<int> bytes, {int maxChars = 0}) {
    if (bytes.isEmpty) return '';
    final source = _bytesForPreviewDecode(bytes, maxChars);
    try {
      return utf8.decode(source);
    } catch (_) {
      const previewBytes = 64;
      final header =
          '[Binary response — ${bytes.length} bytes, not valid UTF-8]';
      if (bytes.length <= _maxBase64PreviewBytes) {
        // 小体积：给出完整 base64，UI 可据此渲染图片 / 还原二进制。
        // Small enough: emit full base64 so the UI can render previews.
        return '$header\nbase64: ${base64Encode(bytes)}';
      }
      final shown = bytes.sublist(0, previewBytes);
      final hex = shown
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      return '$header\nhex: $hex …';
    }
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
    _captureStatusCode();
    return _statusCodeResolved;
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
          if (!_captureExceeded &&
              _bodyBytes.length + chunk.length <= _maxCaptureBytes &&
              InspectorService.instance.globalBodyRemaining > 0) {
            _bodyBytes.addAll(chunk);
          } else if (!_captureExceeded) {
            // 超过限制，截断到最大值并标记 / Exceeded limit, truncate to max and mark
            final remaining = _maxCaptureBytes - _bodyBytes.length;
            if (remaining > 0) {
              _bodyBytes.addAll(chunk.sublist(0, remaining));
            }
            _captureExceeded = true;
          }
          sink.add(chunk);
        },
        handleDone: (sink) {
          _captureBody();
          sink.close();
        },
        handleError: (error, stackTrace, sink) {
          _captureBody();
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
          // 命中响应拦截规则（修改了响应体或状态码）→ 标记已被拦截修改。
          // Matched a response rule (modified body/status code) → mark modified.
          modified: true,
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
