import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/network_request.dart';
import '../models/log_entry.dart';
import '../models/route_entry.dart';
import '../models/interceptor_rule.dart';
import 'alert_service.dart';
import 'persistence_service.dart';

/// Zone 标记键：当前连接是 WebSocket 握手。
/// 由 [InspectorWebSocket.connect] 在调用 `WebSocket.connect` 时用 `runZoned` 设置，
/// 拦截器的 [openUrl] 据此跳过对握手原始 HTTP GET 的记录（它由 WsInspectorService
/// 以 WS 条目单独记录，避免成功时刷屏、失败时漏成 OS Error status -1 的 GET）。
/// Zone key marking the current connection as a WebSocket handshake. Set by
/// [InspectorWebSocket.connect] via runZoned around `WebSocket.connect`, so the
/// interceptor's openUrl skips recording the raw handshake GET (it is recorded
/// separately as a WS entry by WsInspectorService).
final Object wsHandshakeZoneKey = Object();

/// 帧对齐、带"无监听者不调度"的轻量通知器。
/// Frame-aligned, no-listener-no-schedule notifier.
///
/// 与 [ChangeNotifier] 不同：同一帧内的多次 [notifyThrottled] 合并为一次
/// （下一帧绘制后触发），且当没有任何监听者（面板未挂载）时完全不调度，省电。
/// Unlike [ChangeNotifier], repeated [notifyThrottled] in the same frame coalesce
/// into one (fired after the next frame paint), and when there is no listener
/// (panel not mounted) it schedules nothing — saving power.
class ThrottledNotifier extends ChangeNotifier {
  bool _frameScheduled = false;

  /// 帧对齐版 notifyListeners：合并同帧多次通知，无监听者时不调度。
  /// Frame-aligned notifyListeners: coalesces same-frame notifications, no-op without listeners.
  void notifyThrottled() {
    if (_frameScheduled) return;
    // 面板未挂载（无监听者）时不调度，省电；数据仍可通过 getter 在挂载时读取。
    // Skip scheduling when no listener is attached (panel not mounted) to save
    // power; data is still readable via getters once the panel is mounted.
    if (!hasListeners) return;
    _frameScheduled = true;
    try {
      final binding = SchedulerBinding.instance;
      binding.scheduleFrame();
      binding.addPostFrameCallback((_) {
        _frameScheduled = false;
        notifyListeners();
      });
    } catch (_) {
      // 无绑定可用：退回 Timer 兜底。
      // No binding available: fall back to a Timer.
      Timer(const Duration(milliseconds: 16), () {
        _frameScheduled = false;
        notifyListeners();
      });
    }
  }

  /// 重置帧排程标志（dispose 时调用）/ Reset the frame-scheduling flag (on dispose)
  void resetScheduled() => _frameScheduled = false;
}

/// 检查器服务，用于管理所有收集的数据 / Inspector service for managing all collected data
///
/// 数据采用 ListQueue 存储（addFirst/removeLast 均为 O(1)），网络请求额外维护
/// id 索引 Map 做 O(1) 查找；各分类通过独立 notifier（[networkNotifier] /
/// [logNotifier] / [routeNotifier] / [interceptorNotifier]）通知，缩小重建范围。
/// Data is stored in ListQueues (O(1) addFirst/removeLast); network requests keep
/// an extra id-index Map for O(1) lookup. Each category notifies via its own
/// notifier to narrow rebuild scope.
///
/// 使用方式 / Usage:
/// ```dart
/// InspectorService.instance.addLogEntry(logEntry);
/// InspectorService.instance.addNetworkRequest(request);
/// ```
class InspectorService {
  InspectorService._();

  /// 单例实例 / Singleton instance
  static final InspectorService instance = InspectorService._();

  /// 数据流拆分通知器：network / log / route / interceptor 各自独立，
  /// 避免任一数据写入触发全部 viewer 重建（面板用 IndexedStack 常驻挂载时尤其明显）。
  /// Decoupled notifiers: network / log / route / interceptor are separate so a
  /// write to one category rebuilds only its own viewer, not all of them.
  final ThrottledNotifier networkNotifier = ThrottledNotifier();
  final ThrottledNotifier logNotifier = ThrottledNotifier();
  final ThrottledNotifier routeNotifier = ThrottledNotifier();
  final ThrottledNotifier interceptorNotifier = ThrottledNotifier();

  /// 网络请求有序 ID 列表（头部插入，最新在前）/ Ordered network request ids (head insert, newest first)
  /// 网络请求 id 的有序表（最新在前）/ Ordered network request ids (newest first)
  ///
  /// 用 [ListQueue] 而非 [List]：此前用 `_networkOrder.insert(0, ...)` 头插，
  /// 每次都要整体搬移元素（O(n)），高频请求下是纯浪费。
  /// A [ListQueue] rather than a [List]: head-insertion via `insert(0, ...)`
  /// shifted every element (O(n)) on each request.
  final ListQueue<String> _networkOrder = ListQueue();

  /// [networkRequests] 的缓存，变更时置 null 失效 / Cache for [networkRequests]; nulled on mutation
  List<NetworkRequest>? _networkRequestsCache;

  /// 网络请求索引（id -> 请求），O(1) 查找，避免 WS 高频帧的线性扫描。
  /// Index (id -> request) for O(1) lookup, avoids the linear scan on WS high-freq frames.
  final Map<String, NetworkRequest> _networkById = {};

  /// 日志条目列表 / Log entry list
  final ListQueue<LogEntry> _logEntries = ListQueue();

  /// 路由记录列表 / Route record list
  final ListQueue<RouteEntry> _routeEntries = ListQueue();

  /// 拦截规则列表 / Interceptor rule list
  final List<RequestInterceptorRule> _interceptorRules = [];

  /// 拦截总开关 / Interceptor master switch
  bool _interceptorEnabled = false;

  /// 网络瀑布图（Timeline）默认开启偏好 / Network timeline default-on preference
  /// 由 [ZeroInspectorKit.init] 预置，供 NetworkViewer 初始化总开关。
  /// Seeded by init(); read by NetworkViewer to pre-set its master switch.
  bool preferNetworkTimeline = false;

  /// 各类数据容量上限（可经 [configure] 调整）/ Per-category capacities (tunable via [configure])
  int _maxNetworkItems = 100;
  int _maxLogItems = 500;
  int _maxRouteItems = 200;

  /// body 预览字节上限，超出部分截断（仅保留头部预览）/ Body preview cap; longer bodies are truncated
  int _maxBodyPreviewBytes = 32 * 1024;

  /// 缓存的只读视图，避免每次访问都拷贝 List / Cached read-only views to avoid copying per access
  late final UnmodifiableListView<LogEntry> _logEntriesView =
      UnmodifiableListView(_logEntries);
  late final UnmodifiableListView<RouteEntry> _routeEntriesView =
      UnmodifiableListView(_routeEntries);
  late final UnmodifiableListView<RequestInterceptorRule>
  _interceptorRulesView = UnmodifiableListView(_interceptorRules);

  /// 全局 body 内存预算（所有请求累计缓冲上限）。超过后代理侧停止继续缓冲 body，
  /// 已落库的 body 在请求被淘汰 / 清除时释放，从而把总内存控制在可预期范围内。
  /// Global body memory budget (total buffered across all requests). When exceeded the
  /// proxies stop buffering more body; stored bodies are released on eviction/clear so
  /// total memory stays bounded and predictable.
  static const int _defaultMaxGlobalBodyBytes = 16 * 1024 * 1024; // 16 MB

  /// 当前全局 body 预算上限 / Current global body budget cap
  int _maxGlobalBodyBytes = _defaultMaxGlobalBodyBytes;

  /// 当前已缓冲的 body 字节数（近似值，按字符串长度估算）/ Currently buffered body bytes (approx, by string length)
  int _globalBodyBytes = 0;

  /// 剩余可用全局 body 预算 / Remaining global body budget
  int get globalBodyRemaining => _maxGlobalBodyBytes - _globalBodyBytes < 0
      ? 0
      : _maxGlobalBodyBytes - _globalBodyBytes;

  /// 估算一条请求的 body 字节占用（字符数近似）/ Estimate a request's buffered body bytes (char-count approximation)
  static int _bodyBytesOf(NetworkRequest r) {
    var n = 0;
    if (r.body != null) n += r.body.toString().length;
    if (r.responseBody != null) n += r.responseBody.toString().length;
    return n;
  }

  /// 配置容量上限与 body 预览截断长度 / Configure capacities and body preview cap
  /// 应在 [ZeroInspectorKit.init] 中调用，向后兼容（全部命名可选）。
  /// Call from [ZeroInspectorKit.init]; all params are optional and backward compatible.
  void configure({
    int? maxNetworkItems,
    int? maxLogItems,
    int? maxRouteItems,
    int? maxBodyPreviewBytes,
    int? maxGlobalBodyBytes,
  }) {
    if (maxNetworkItems != null && maxNetworkItems > 0) {
      _maxNetworkItems = maxNetworkItems;
    }
    if (maxLogItems != null && maxLogItems > 0) {
      _maxLogItems = maxLogItems;
    }
    if (maxRouteItems != null && maxRouteItems > 0) {
      _maxRouteItems = maxRouteItems;
    }
    if (maxBodyPreviewBytes != null && maxBodyPreviewBytes > 0) {
      _maxBodyPreviewBytes = maxBodyPreviewBytes;
    }
    if (maxGlobalBodyBytes != null && maxGlobalBodyBytes > 0) {
      _maxGlobalBodyBytes = maxGlobalBodyBytes;
    }
    // 上限被调小后立即裁剪，否则旧数据会一直留在列表里。
    // Trim right away when a cap shrank, otherwise stale entries linger.
    if (maxNetworkItems != null) _trimNetworkRequests();
    if (maxLogItems != null) _trimQueue(_logEntries, _maxLogItems);
    if (maxRouteItems != null) _trimQueue(_routeEntries, _maxRouteItems);
  }

  /// 获取拦截总开关状态 / Get interceptor master switch state
  bool get isInterceptorEnabled => _interceptorEnabled;

  /// 设置拦截总开关 / Set interceptor master switch
  set isInterceptorEnabled(bool value) {
    _interceptorEnabled = value;
    interceptorNotifier.notifyThrottled();
  }

  /// 获取网络请求列表（按时间倒序，最新在前）。
  /// Get network requests newest-first.
  ///
  /// 结果带缓存：UI 一次构建会访问该 getter 多达 7 次（其中一次仅为取
  /// `.length`），此前每次都重建整个 List。变更时缓存失效。
  /// Cached: a single UI build can hit this getter up to 7 times (one of them
  /// just for `.length`), and each access used to rebuild the whole list. The
  /// cache is invalidated on every mutation.
  UnmodifiableListView<NetworkRequest> get networkRequests {
    final cached = _networkRequestsCache;
    if (cached != null) return UnmodifiableListView(cached);
    final built = <NetworkRequest>[
      for (final id in _networkOrder) ?_networkById[id],
    ];
    _networkRequestsCache = built;
    return UnmodifiableListView(built);
  }

  /// 使网络列表缓存失效 / Invalidate the network list cache
  void _invalidateNetworkCache() => _networkRequestsCache = null;

  /// 获取拦截规则列表（只读视图）/ Get interceptor rule list (read-only view)
  UnmodifiableListView<RequestInterceptorRule> get interceptorRules =>
      _interceptorRulesView;

  /// 获取日志条目列表（只读视图）/ Get log entry list (read-only view)
  UnmodifiableListView<LogEntry> get logEntries => _logEntriesView;

  /// 获取路由记录列表（只读视图）/ Get route record list (read-only view)
  UnmodifiableListView<RouteEntry> get routeEntries => _routeEntriesView;

  /// 轻量计数 getter，避免为取 .length 而拷贝 List / Lightweight count getters
  int get networkRequestCount => _networkOrder.length;
  int get logEntryCount => _logEntries.length;
  int get routeEntryCount => _routeEntries.length;
  int get interceptorRuleCount => _interceptorRules.length;

  /// 按 id 查找最新网络请求（O(1) 索引查找）/ Look up the latest request by id (O(1) index lookup)
  NetworkRequest? findNetworkRequest(String id) => _networkById[id];

  /// 添加网络请求记录 / Add network request record
  /// [request] 网络请求对象 / Network request object
  void addNetworkRequest(NetworkRequest request) {
    // 同一 id 重复登记会让列表出现重复行（历史上有过 ID 碰撞的先例），
    // 这里做兜底去重。Guard against duplicate ids, which would otherwise show
    // up as duplicate rows (ID collisions have happened before).
    _networkOrder.remove(request.id);
    _networkOrder.addFirst(request.id);
    _invalidateNetworkCache();
    _networkById[request.id] = request;
    _trimNetworkRequests();
    _globalBodyBytes += _bodyBytesOf(request);
    AlertService.instance.checkNetwork(request);
    // 异步落盘（磁盘环形缓冲，崩溃后可读回）/ Async persist (disk ring buffer)
    PersistenceService.instance.enqueueNetwork(request);
    networkNotifier.notifyThrottled();
  }

  /// 更新网络请求响应信息 / Update network request response info
  /// [id] 请求唯一ID / Request unique ID
  /// [responseBody] 响应体数据 / Response body data
  /// [statusCode] HTTP状态码 / HTTP status code
  /// [body] 请求体数据 / Request body data
  ///
  /// 仅当 [statusCode] 非空时才视为"响应已到达"并设置 responseTime / duration；
  /// 仅更新请求体（body）时不会过早标记请求已完成。
  /// Only treats the update as a response arrival when [statusCode] is non-null;
  /// updating only the request body (body) will not prematurely mark the request complete.
  void updateNetworkRequest(
    String id, {
    dynamic responseBody,
    int? statusCode,
    dynamic body,
    bool? modified,
  }) {
    final request = _networkById[id];
    if (request == null) return;

    // 仅当 statusCode 被提供时，才视为响应到达，更新 responseTime / duration。
    // 仅提供 body（请求体捕获）时不应设置 responseTime，否则会导致耗时计算错误。
    // Only set responseTime when statusCode is provided (indicates response arrival).
    // Providing only body (request body capture) must not set responseTime,
    // otherwise duration is calculated incorrectly.
    final int? responseTime;
    final int? duration;
    if (statusCode != null) {
      final now = DateTime.now().millisecondsSinceEpoch;
      responseTime = request.responseTime ?? now;
      duration = responseTime - request.requestTime;
    } else {
      responseTime = request.responseTime;
      duration = request.duration;
    }

    final updated = request.copyWith(
      responseBody: responseBody ?? request.responseBody,
      statusCode: statusCode ?? request.statusCode,
      body: body ?? request.body,
      responseTime: responseTime,
      duration: duration,
      // 拦截标记：只在命中规则并实际修改时才置 true，不会把已有 true 清零。
      // Interception flag: only set to true when a rule actually modified the
      // request; never clears an existing true (modified stays sticky).
      isModifiedByInterceptor: modified ?? false
          ? true
          : request.isModifiedByInterceptor,
      maxBodyBytes: _maxBodyPreviewBytes,
    );
    final oldSize = _bodyBytesOf(request);
    final newSize = _bodyBytesOf(updated);
    _globalBodyBytes = _globalBodyBytes - oldSize + newSize < 0
        ? 0
        : _globalBodyBytes - oldSize + newSize;
    // 请求对象被替换，缓存里的旧引用失效。
    // The request object is replaced, so cached references go stale.
    _invalidateNetworkCache();
    // O(1) 就地更新索引中的请求；不再为每次 WS 帧做 remove/addFirst 重排。
    // O(1) in-place index update; no per-WS-frame remove/addFirst reorder.
    _networkById[id] = updated;
    // 仅在响应真正到达时落盘：WS 会逐帧触发 update，逐帧写盘开销过大。
    // Persist only on real response arrival: WS fires update per frame, which
    // would be too expensive to write every time.
    if (statusCode != null) {
      PersistenceService.instance.enqueueNetwork(updated);
    }
    AlertService.instance.checkNetwork(updated);
    networkNotifier.notifyThrottled();
  }

  /// 同一逻辑多行日志（第三方库逐行 print 的 box/缩进内容）在极短时间内
  /// 合并为同一条，避免被拆成多段、且各段 ID 碰撞导致点击详情错乱。
  /// Reassemble a logical multi-line log (e.g. a third-party lib printing a
  /// box/indented block line-by-line) into a single entry within a tiny window,
  /// so it is not fragmented and each segment stays independently clickable.
  static const int _logReassembleWindowMs = 60;

  /// Box 制图符（续行的强信号）/ Box-drawing glyphs (strong continuation signal)
  static const String _boxContinuationChars = '│├┌└┐┘─┤┴┬┼';

  /// 行以 Box 制图符开头（强续行：正常独立日志几乎不以这些字符开头）。
  /// Line starts with a box-drawing glyph (strong: standalone logs almost never
  /// begin with these glyphs).
  bool _isBoxGlyphStart(String line) {
    if (line.isEmpty) return false;
    return _boxContinuationChars.contains(line[0]);
  }

  /// 行以空白/制表符开头（弱续行：也可能是独立日志自身的缩进）。
  /// Line starts with whitespace/tab (weak: may also be a standalone log's own indentation).
  bool _isIndentStart(String line) {
    if (line.isEmpty) return false;
    final c = line[0];
    return c == ' ' || c == '\t';
  }

  bool _isWithinReassembleWindow(DateTime prev, DateTime cur) {
    return cur.difference(prev).abs().inMilliseconds < _logReassembleWindowMs;
  }

  /// 跨帧拆出的"重复片段"判定：新行是上一条多行文本的某一行（前面有换行符），
  /// 判定为 debugPrint 拆行/换行包裹产生的重复片段。
  /// 只匹配"内部某一行"而非任意子串：两条内容完全相同但独立相邻的日志
  /// （如循环里重复打印同一文本）不会被误吞。
  /// A "split fragment" is a line that already exists inside the previous
  /// multi-line text (preceded by a newline) — e.g. a duplicate produced by
  /// debugPrint line-splitting. Only inner lines count, not arbitrary
  /// substrings, so two genuinely separate identical logs (e.g. a loop printing
  /// the same text twice) are never swallowed.
  bool _isSplitFragment(String previous, String line) {
    return line.isNotEmpty && previous.contains('\n$line');
  }

  /// 添加日志条目 / Add log entry
  /// [entry] 日志条目对象 / Log entry object
  void addLogEntry(LogEntry entry) {
    final last = _logEntries.isNotEmpty ? _logEntries.first : null;
    if (last != null &&
        _isWithinReassembleWindow(last.timestamp, entry.timestamp)) {
      final msg = entry.message;
      // 两条日志是否来自同一数据流 / Whether the two entries share a stream.
      final sameTag = last.tag == entry.tag;
      // 同流的"重复片段"（新行是上一条多行文本内的某一行，即 debugPrint
      // 拆行产生的重复）先丢弃，与续行形状无关；两条各自完整、内容恰好相同
      // 的独立日志不会被误吞。
      // Drop a same-stream duplicate fragment (a line already inside the
      // previous multi-line text, e.g. a debugPrint wrap split); independent
      // logs whose whole message happens to match are never swallowed.
      if (sameTag && _isSplitFragment(last.message, msg)) {
        return;
      }
      // 续行合并身份判定 / Reassembly identity check:
      //  - 两侧 tag 相同（含均无 tag）→ 同流候选；
      //  - 但 print/debugPrint 直出的日志 tag 恒为 null，此时"同 tag"是空真
      //    （null == null），不能作为身份凭据。无 tag 流只信任以 Box 制图符
      //    开头的强续行；纯空格/制表符开头不足以证明与上一条同属一块，
      //    避免把"本身以空格开头的独立无 tag 日志"误并进上一条。
      //  - 有 tag 的流保留完整重组（缩进与 Box 开头均可合并）。
      // Same-tag (incl. both-null) marks a same-stream candidate. But print /
      // debugPrint output always has a null tag, making "same tag" vacuous
      // (null == null) there — so an untagged stream only trusts a box-glyph
      // start (strong continuation); bare space/tab indentation is not enough
      // proof of identity and must not swallow an independent indented log.
      final canReassemble = _isBoxGlyphStart(msg)
          ? sameTag
          : (sameTag && last.tag != null && _isIndentStart(msg));
      if (canReassemble) {
        // 续行则合并到上一条 / Merge continuation lines into the previous entry.
        final merged = LogEntry(
          id: last.id,
          level: last.level,
          message: '${last.message}\n$msg',
          timestamp: entry.timestamp,
          tag: entry.tag ?? last.tag,
        );
        _logEntries.removeFirst();
        _logEntries.addFirst(merged);
        AlertService.instance.checkLog(merged);
        PersistenceService.instance.enqueueLog(merged);
        logNotifier.notifyThrottled();
        return;
      }
    }
    _logEntries.addFirst(entry);
    _trimQueue(_logEntries, _maxLogItems);
    AlertService.instance.checkLog(entry);
    PersistenceService.instance.enqueueLog(entry);
    logNotifier.notifyThrottled();
  }

  /// 恢复持久化日志（跨重启不丢）。
  /// Restore persisted logs (survives restarts).
  ///
  /// 与 [addLogEntry] 不同：直接追加，不参与续行合并判定，避免把磁盘回放的
  /// 历史日志错误地合并到实时日志里。
  /// Unlike [addLogEntry], this appends directly without continuation
  /// reassembly so replayed history is never mis-merged into live logs.
  ///
  /// [logs] 必须按"最新在前"排列（[PersistenceService.loadLogs] 的返回顺序）。
  /// [logs] must be newest-first (the order returned by
  /// [PersistenceService.loadLogs]).
  void restoreLogs(Iterable<LogEntry> logs) {
    for (final l in logs) {
      _logEntries.addLast(l);
    }
    _trimQueue(_logEntries, _maxLogItems);
    logNotifier.notifyThrottled();
  }

  /// 添加路由记录 / Add route record
  /// [entry] 路由记录对象 / Route record object
  void addRouteEntry(RouteEntry entry) {
    _routeEntries.addFirst(entry);
    _trimQueue(_routeEntries, _maxRouteItems);
    routeNotifier.notifyThrottled();
  }

  /// 添加拦截规则 / Add interceptor rule
  /// [rule] 拦截规则对象 / Interceptor rule object
  void addInterceptorRule(RequestInterceptorRule rule) {
    final index = _interceptorRules.indexWhere((r) => r.id == rule.id);
    if (index != -1) {
      _interceptorRules[index] = rule;
    } else {
      _interceptorRules.add(rule);
    }
    interceptorNotifier.notifyThrottled();
  }

  /// 删除拦截规则 / Remove interceptor rule
  /// [id] 规则ID / Rule ID
  void removeInterceptorRule(String id) {
    _interceptorRules.removeWhere((r) => r.id == id);
    interceptorNotifier.notifyThrottled();
  }

  /// 更新拦截规则 / Update interceptor rule
  /// [rule] 更新后的规则 / Updated rule
  void updateInterceptorRule(RequestInterceptorRule rule) {
    addInterceptorRule(rule);
  }

  /// 查找匹配指定请求的规则 / Find matching rule for specified request
  /// [url] 请求URL / Request URL
  /// [method] 请求方法 / Request method
  RequestInterceptorRule? findMatchingRule(String url, String method) {
    if (!_interceptorEnabled) return null;
    for (final rule in _interceptorRules) {
      if (rule.matches(url, method)) {
        return rule;
      }
    }
    return null;
  }

  /// 清空所有数据（网络请求、日志、路由、拦截规则）/ Clear all data
  void clearAll() {
    _networkOrder.clear();
    _networkById.clear();
    _logEntries.clear();
    _routeEntries.clear();
    _interceptorRules.clear();
    _globalBodyBytes = 0;
    _invalidateNetworkCache();
    networkNotifier.notifyThrottled();
    logNotifier.notifyThrottled();
    routeNotifier.notifyThrottled();
    interceptorNotifier.notifyThrottled();
  }

  /// 清空网络请求记录 / Clear network request records
  void clearNetworkRequests() {
    _networkOrder.clear();
    _networkById.clear();
    _globalBodyBytes = 0;
    _invalidateNetworkCache();
    networkNotifier.notifyThrottled();
  }

  /// 按 id 删除单条网络请求（批量删除用）/ Remove a single request by id
  void removeNetworkRequest(String id) {
    _networkOrder.remove(id);
    final removed = _networkById.remove(id);
    // 释放被删请求占用的全局 body 预算，否则预算只增不减，
    // 会让代理侧提前停止缓冲 body。
    // Release the removed request's share of the global body budget; otherwise
    // the budget only ever grows and the proxy stops buffering bodies early.
    if (removed != null) {
      _globalBodyBytes = _globalBodyBytes - _bodyBytesOf(removed) < 0
          ? 0
          : _globalBodyBytes - _bodyBytesOf(removed);
    }
    _invalidateNetworkCache();
    networkNotifier.notifyThrottled();
  }

  /// 清空日志记录 / Clear log records
  void clearLogs() {
    _logEntries.clear();
    logNotifier.notifyThrottled();
  }

  /// 清空路由记录 / Clear route records
  void clearRoutes() {
    _routeEntries.clear();
    routeNotifier.notifyThrottled();
  }

  /// 释放资源：重置各 notifier 的帧排程标志 / Dispose: reset each notifier's frame flag
  void disposeService() {
    networkNotifier.resetScheduled();
    logNotifier.resetScheduled();
    routeNotifier.resetScheduled();
    interceptorNotifier.resetScheduled();
  }

  /// 裁剪 Queue 到最大条目数（从尾部移除，O(1)）/ Trim Queue to max items (removes from tail, O(1))
  void _trimQueue<T>(ListQueue<T> queue, int max) {
    while (queue.length > max) {
      queue.removeLast();
    }
  }

  /// 裁剪网络请求队列到最大条目数，并从全局 body 预算中释放被淘汰请求的占用。
  /// Trim network request queue to the cap, releasing evicted requests' body budget.
  void _trimNetworkRequests() {
    if (_networkOrder.length <= _maxNetworkItems) return;
    while (_networkOrder.length > _maxNetworkItems) {
      final removedId = _networkOrder.removeLast();
      final removed = _networkById.remove(removedId);
      if (removed != null) {
        final freed = _bodyBytesOf(removed);
        _globalBodyBytes = _globalBodyBytes - freed < 0
            ? 0
            : _globalBodyBytes - freed;
      }
    }
    _invalidateNetworkCache();
  }
}
