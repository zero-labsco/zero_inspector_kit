import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/network_request.dart';
import 'inspector_service.dart';

/// WebSocket 帧类型 / WebSocket frame type
enum WsFrameType {
  /// 文本帧 / Text frame
  text,

  /// 二进制帧 / Binary frame
  binary,

  /// 连接关闭标记帧 / Connection-close marker frame
  close,
}

/// WebSocket / gRPC 等流式协议抓取服务 / Streaming-protocol capture service (WebSocket / gRPC, etc.)
///
/// 设计上与 Memory / FPS 监控一致：**默认关闭、运行时开关**，对没有使用这类协议的
/// App 零影响、零开销。开启后才会记录收发帧。
/// Mirrors the Memory/FPS monitors: **off by default, toggled at runtime**, so apps
/// that don't use these protocols pay nothing. Capture only happens when enabled.
///
/// 两种使用方式 / Two usage modes:
/// 1. 透明包装 [InspectorWebSocket.connect] 替换 `WebSocket.connect`，自动记录收发帧；
///    / Wrap [InspectorWebSocket.connect] in place of `WebSocket.connect` to auto-capture frames.
/// 2. 手动 hook [recordCall]，用于 gRPC、web_socket_channel 等无法被 `dart:io` 透明拦截的栈。
///    / Manual [recordCall] hook for gRPC, web_socket_channel, or anything not transparently
///    interceptable by `dart:io`.
///
/// 抓取的每帧以 [WsFrame] 形式保存在会话中，详情页通过 [framesFor] 读取并渲染
/// （方向 / 类型 / 字节大小 / 时间），不再只是拼接成纯文本。
/// Each captured frame is kept as a [WsFrame] in the session and read by the detail
/// view via [framesFor] (direction / type / byte size / timestamp) instead of a
/// flat text blob.
class WsInspectorService extends ChangeNotifier {
  WsInspectorService._();

  /// 单例实例 / Singleton instance
  static final WsInspectorService instance = WsInspectorService._();

  /// 是否启用抓取（用户开关，默认关闭）/ Whether capture is enabled (user switch, default off)
  bool _isEnabled = false;

  /// 获取是否启用抓取 / Get whether capture is enabled
  bool get isEnabled => _isEnabled;

  /// 设置是否启用抓取 / Set whether capture is enabled
  set isEnabled(bool value) {
    if (_isEnabled == value) return;
    _isEnabled = value;
    notifyListeners();
  }

  /// 开启抓取 / Enable capture
  void enable() => isEnabled = true;

  /// 关闭抓取 / Disable capture
  void disable() => isEnabled = false;

  /// 切换抓取开关 / Toggle capture on/off
  void toggle() => isEnabled = !_isEnabled;

  /// 活跃会话表（sessionId -> 会话）/ Active sessions (sessionId -> session)
  final Map<String, _WsSession> _sessions = {};

  /// 自增计数器，保证 sessionId 唯一 / Monotonic counter for unique session ids
  int _counter = 0;

  /// 生成唯一会话 ID / Generate a unique session id
  String _newId() =>
      'ws_${++_counter}_${DateTime.now().microsecondsSinceEpoch}';

  /// 包装一个已建立的 [WebSocket]，开启抓取时记录收发帧。
  /// Wrap an established [WebSocket]; records frames when capture is enabled.
  InspectorWebSocket _wrap(WebSocket ws, String url) {
    final id = _newId();
    _sessions[id] = _WsSession(
      id: id,
      url: url,
      startTime: DateTime.now().millisecondsSinceEpoch,
    );
    // 在网络列表中插入一条 method='WS' 的记录，复用时间轴与详情页。
    // Insert a method='WS' record into the network list, reusing the timeline & detail view.
    InspectorService.instance.addNetworkRequest(
      NetworkRequest(
        id: id,
        method: 'WS',
        url: url,
        requestTime: _sessions[id]!.startTime,
      ),
    );
    return InspectorWebSocket._(ws, id);
  }

  /// 记录一帧（收发方向 + 原始数据，自动推断类型与字节大小）。
  /// Record a single frame (direction + raw data; type & byte size inferred).
  void _recordFrame(String id, bool outgoing, dynamic data) {
    final session = _sessions[id];
    if (session == null) return;
    final type = _frameTypeOf(data);
    final text = _framePreview(data, type);
    final byteSize = _byteSizeOf(data);
    session.frames.add(
      WsFrame(
        outgoing: outgoing,
        type: type,
        text: text,
        byteSize: byteSize,
        at: DateTime.now(),
      ),
    );

    // 累积到对应网络记录的 responseBody，供详情页/导出查看（向后兼容）。
    // Accumulate into the network record's responseBody for the detail view & export (back-compat).
    final existing = InspectorService.instance.findNetworkRequest(id);
    final prev = existing?.responseBody?.toString() ?? '';
    final arrow = outgoing ? '→' : '←';
    final line = '$arrow $text\n';
    InspectorService.instance.updateNetworkRequest(
      id,
      responseBody: prev + line,
    );
  }

  /// 连接关闭：追加关闭标记帧 / Connection closed: append a close marker frame
  void _onClose(String id) {
    final session = _sessions[id];
    if (session == null) return;
    session.closed = true;
    session.frames.add(
      WsFrame(
        outgoing: false,
        type: WsFrameType.close,
        text: '[connection closed]',
        byteSize: 0,
        at: DateTime.now(),
      ),
    );
    final existing = InspectorService.instance.findNetworkRequest(id);
    final prev = existing?.responseBody?.toString() ?? '';
    InspectorService.instance.updateNetworkRequest(
      id,
      responseBody: '$prev[connection closed]\n',
    );
  }

  /// 获取某会话已抓取的帧列表（按时间顺序）；会话不存在或已被淘汰时返回 null。
  /// 同时用于**惰性淘汰**：当对应网络记录已被 [InspectorService] 裁剪出列表后，
  /// 这里会释放会话，避免内存泄漏（详见 [_trimNetworkRequests]）。
  /// Get captured frames for a session (chronological); returns null if the
  /// session doesn't exist or has been evicted. Also lazily evicts sessions whose
  /// network record has been trimmed from [InspectorService] to avoid leaks.
  List<WsFrame>? framesFor(String id) {
    if (!_sessions.containsKey(id)) return null;
    if (InspectorService.instance.findNetworkRequest(id) == null) {
      _sessions.remove(id);
      return null;
    }
    return List.unmodifiable(_sessions[id]!.frames);
  }

  /// 推断帧类型：字符串为文本帧，List 为二进制帧，其余按文本处理。
  /// Infer frame type: String -> text, List -> binary, else text.
  static WsFrameType _frameTypeOf(dynamic data) {
    if (data is String) return WsFrameType.text;
    if (data is List) return WsFrameType.binary;
    return WsFrameType.text;
  }

  /// 计算帧字节大小 / Compute frame byte size
  static int _byteSizeOf(dynamic data) {
    if (data is String) return data.length;
    if (data is List) return data.length;
    return data?.toString().length ?? 0;
  }

  /// 生成帧预览文本；二进制帧给出前 16 字节的十六进制预览。
  /// Build frame preview text; binary frames get a 16-byte hex preview.
  static String _framePreview(dynamic data, WsFrameType type) {
    if (type == WsFrameType.binary && data is List) {
      final bytes = data
          .take(16)
          .map((b) => (b as int).toRadixString(16).padLeft(2, '0'))
          .join(' ');
      final overflow = data.length > 16 ? ' …(+${data.length - 16})' : '';
      return '$bytes$overflow';
    }
    return data?.toString() ?? '';
  }

  /// 手动记录一次调用（gRPC / 自定义协议等）。
  /// Manually record a call (gRPC / custom protocols, etc.).
  ///
  /// 关闭抓取时直接返回，不产生任何记录（零开销）。
  /// No-ops when capture is disabled (zero overhead).
  ///
  /// [name] 调用标识（如 service/method 名）/ Call identifier (e.g. service/method name)
  /// [request] 请求内容（可选）/ Request payload (optional)
  /// [response] 响应内容（可选）/ Response payload (optional)
  /// [protocol] 协议标签，默认 'gRPC'（出现在网络列表 method 列）
  ///   / Protocol label, default 'gRPC' (shown in the network list's method column)
  void recordCall({
    required String name,
    String? request,
    String? response,
    String protocol = 'gRPC',
  }) {
    if (!_isEnabled) return;
    final id = _newId();
    final now = DateTime.now().millisecondsSinceEpoch;
    InspectorService.instance.addNetworkRequest(
      NetworkRequest(
        id: id,
        method: protocol,
        url: name,
        requestTime: now,
        body: request,
      ),
    );
    InspectorService.instance.updateNetworkRequest(id, responseBody: response);
  }

  /// 清空本地会话表（网络记录本身由 [InspectorService.clearNetworkRequests] 清理）。
  /// Clear local session table (the network records are cleared via
  /// [InspectorService.clearNetworkRequests]).
  void reset() {
    _sessions.clear();
    notifyListeners();
  }
}

/// WebSocket 会话（内部）/ WebSocket session (internal)
class _WsSession {
  /// 会话唯一 ID / Unique session id
  final String id;

  /// 连接 URL / Connection URL
  final String url;

  /// 开始时间戳（毫秒）/ Start timestamp (ms)
  final int startTime;

  /// 收发帧记录 / Captured frames
  final List<WsFrame> frames = [];

  /// 是否已关闭 / Whether the connection is closed
  bool closed = false;

  _WsSession({required this.id, required this.url, required this.startTime});
}

/// 单帧记录（WebSocket 抓取） / A single captured WebSocket frame
class WsFrame {
  /// 是否出站（true=发送 / false=接收）/ Outgoing when true, incoming when false
  final bool outgoing;

  /// 帧类型（文本 / 二进制 / 关闭标记）/ Frame type (text / binary / close)
  final WsFrameType type;

  /// 帧预览文本（二进制帧为十六进制预览）/ Frame preview text (hex preview for binary)
  final String text;

  /// 帧字节大小 / Frame byte size
  final int byteSize;

  /// 时间戳 / Timestamp
  final DateTime at;

  WsFrame({
    required this.outgoing,
    required this.type,
    required this.text,
    required this.byteSize,
    required this.at,
  });
}

/// 可监控的 WebSocket 包装器 / Monitorable WebSocket wrapper
///
/// 替换 `WebSocket.connect` 使用即可；仅在 [WsInspectorService] 开启时记录收发帧，
/// 关闭时直接透传，性能零损耗。
/// Use in place of `WebSocket.connect`; records frames only when [WsInspectorService]
/// is enabled, otherwise passes through with zero overhead.
///
/// 注意：本包装覆盖 `dart:io` 的 `WebSocket.connect` 路径。对于 web_socket_channel、
/// gRPC 等独立实现，请改用 [WsInspectorService.recordCall] 手动 hook。
/// Note: this wrapper covers the `dart:io` `WebSocket.connect` path. For
/// web_socket_channel, gRPC, or other independent stacks, use
/// [WsInspectorService.recordCall] instead.
class InspectorWebSocket extends Stream<dynamic>
    implements StreamSink<dynamic> {
  final WebSocket _inner;
  final String? _sessionId;

  InspectorWebSocket._(this._inner, this._sessionId);

  /// 建立连接（等价 `WebSocket.connect`）/ Connect (equivalent to `WebSocket.connect`)
  ///
  /// [url] ws/wss 地址 / ws/wss URL
  /// 其余参数与 `WebSocket.connect` 一致 / Remaining params mirror `WebSocket.connect`
  static Future<InspectorWebSocket> connect(
    String url, {
    Iterable<String>? protocols,
    HttpClient? customClient,
    CompressionOptions compression = CompressionOptions.compressionDefault,
  }) async {
    // 用 runZoned 标记当前连接为 WebSocket 握手，让 HttpOverrides 拦截器跳过
    // 对底层 HTTP GET 握手的记录（它由本服务以 WS 条目单独呈现）。
    // Wrap in a zone flagged as a WS handshake so the HttpOverrides interceptor
    // skips recording the underlying HTTP GET (this service shows it as a WS entry).
    final ws = await runZoned(
      () => WebSocket.connect(
        url,
        protocols: protocols,
        customClient: customClient,
        compression: compression,
      ),
      zoneValues: {wsHandshakeZoneKey: true},
    );
    // 未开启抓取时不创建会话，后续 add/listen 均为空操作（零开销）。
    // When capture is off, no session is created, so add/listen become no-ops.
    if (!WsInspectorService.instance.isEnabled) {
      return InspectorWebSocket._(ws, null);
    }
    return WsInspectorService.instance._wrap(ws, url);
  }

  void _recordFrame(bool outgoing, dynamic data) {
    if (_sessionId == null) return;
    WsInspectorService.instance._recordFrame(_sessionId, outgoing, data);
  }

  void _onClose() {
    if (_sessionId == null) return;
    WsInspectorService.instance._onClose(_sessionId);
  }

  // ==================== Stream<dynamic> ====================

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return _inner.listen(
      (data) {
        _recordFrame(false, data);
        onData?.call(data);
      },
      onError: onError,
      onDone: () {
        _onClose();
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
  }

  // ==================== StreamSink<dynamic> ====================

  @override
  void add(dynamic data) {
    _recordFrame(true, data);
    _inner.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _inner.addError(error, stackTrace);

  @override
  Future<void> addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<void> close([int? closeCode, String? closeReason]) {
    _onClose();
    return _inner.close(closeCode, closeReason);
  }

  // ==================== 透传常用成员 / Forward common members ====================

  /// 连接关闭 Future / Future resolved when the connection closes
  @override
  Future<void> get done => _inner.done;

  /// 协商的协议 / Negotiated protocol
  String? get protocol => _inner.protocol;

  /// 关闭码 / Close code
  int? get closeCode => _inner.closeCode;

  /// 关闭原因 / Close reason
  String? get closeReason => _inner.closeReason;

  /// 扩展 / Extensions
  String? get extensions => _inner.extensions;

  /// 就绪状态 / Ready state
  int get readyState => _inner.readyState;

  /// 心跳间隔 / Ping interval
  Duration? get pingInterval => _inner.pingInterval;

  /// 设置心跳间隔 / Set ping interval
  set pingInterval(Duration? value) => _inner.pingInterval = value;
}
