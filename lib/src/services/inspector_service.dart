import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import '../models/network_request.dart';
import '../models/log_entry.dart';
import '../models/route_entry.dart';
import '../models/interceptor_rule.dart';
import 'alert_service.dart';

/// 检查器服务，用于管理所有收集的数据 / Inspector service for managing all collected data
///
/// 该服务继承自 ChangeNotifier，当数据发生变化时会自动通知监听者更新UI。
/// 数据采用 ListQueue 存储（addFirst/removeLast 均为 O(1)），且 notifyListeners
/// 通过 16ms 节流合并，避免高频写入场景下的 UI 每帧多次重建。
/// This service extends ChangeNotifier. Data is stored in ListQueue (O(1) addFirst/removeLast)
/// and notifyListeners is throttled at ~16ms to avoid per-frame rebuild storms under high volume.
///
/// 使用方式 / Usage:
/// ```dart
/// InspectorService.instance.addLogEntry(logEntry);
/// InspectorService.instance.addNetworkRequest(request);
/// ```
class InspectorService extends ChangeNotifier {
  InspectorService._();

  /// 单例实例 / Singleton instance
  static final InspectorService instance = InspectorService._();

  /// 网络请求列表（ListQueue，头部插入 O(1)）/ Network request list (ListQueue, O(1) head insert)
  final ListQueue<NetworkRequest> _networkRequests = ListQueue();

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

  /// 是否已排程下一帧的 notify（帧对齐合并标志）/ whether a frame-aligned notify is already scheduled
  bool _frameScheduled = false;

  /// 缓存的只读视图，避免每次访问都拷贝 List / Cached read-only views to avoid copying per access
  late final UnmodifiableListView<NetworkRequest> _networkRequestsView =
      UnmodifiableListView(_networkRequests);
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
  }

  /// 获取拦截总开关状态 / Get interceptor master switch state
  bool get isInterceptorEnabled => _interceptorEnabled;

  /// 设置拦截总开关 / Set interceptor master switch
  set isInterceptorEnabled(bool value) {
    _interceptorEnabled = value;
    notifyListeners();
  }

  /// 获取网络请求列表（只读视图，零拷贝）/ Get network request list (read-only view, zero-copy)
  UnmodifiableListView<NetworkRequest> get networkRequests =>
      _networkRequestsView;

  /// 获取拦截规则列表（只读视图）/ Get interceptor rule list (read-only view)
  UnmodifiableListView<RequestInterceptorRule> get interceptorRules =>
      _interceptorRulesView;

  /// 获取日志条目列表（只读视图）/ Get log entry list (read-only view)
  UnmodifiableListView<LogEntry> get logEntries => _logEntriesView;

  /// 获取路由记录列表（只读视图）/ Get route record list (read-only view)
  UnmodifiableListView<RouteEntry> get routeEntries => _routeEntriesView;

  /// 轻量计数 getter，避免为取 .length 而拷贝 List / Lightweight count getters
  int get networkRequestCount => _networkRequests.length;
  int get logEntryCount => _logEntries.length;
  int get routeEntryCount => _routeEntries.length;
  int get interceptorRuleCount => _interceptorRules.length;

  /// 按 id 查找最新网络请求（修复陈旧引用问题）/ Look up the latest request by id
  NetworkRequest? findNetworkRequest(String id) {
    for (final r in _networkRequests) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// 添加网络请求记录 / Add network request record
  /// [request] 网络请求对象 / Network request object
  void addNetworkRequest(NetworkRequest request) {
    _networkRequests.addFirst(request);
    _trimNetworkRequests();
    _globalBodyBytes += _bodyBytesOf(request);
    AlertService.instance.checkNetwork(request);
    _notifyThrottled();
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
    final index = _indexOfNetworkRequest(id);
    if (index != -1) {
      final request = _networkRequests.elementAt(index);

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
      _networkRequests
        ..remove(request)
        ..addFirst(updated);
      AlertService.instance.checkNetwork(updated);
      _notifyThrottled();
    }
  }

  /// 同一逻辑多行日志（第三方库逐行 print 的 box/缩进内容）在极短时间内
  /// 合并为同一条，避免被拆成多段、且各段 ID 碰撞导致点击详情错乱。
  /// Reassemble a logical multi-line log (e.g. a third-party lib printing a
  /// box/indented block line-by-line) into a single entry within a tiny window,
  /// so it is not fragmented and each segment stays independently clickable.
  static const int _logReassembleWindowMs = 60;

  /// 续行判定：以空白/制表符或 Box 绘制字符开头的行视为上一条日志的延续。
  /// A line starting with whitespace/tab or a box-drawing glyph is treated as
  /// a continuation of the previous log entry.
  static const String _boxContinuationChars = '│├┌└┐┘─┤┴┬┼';

  bool _isReassembleContinuation(String line) {
    if (line.isEmpty) return false;
    final c = line[0];
    if (c == ' ' || c == '\t') return true;
    return _boxContinuationChars.contains(c);
  }

  bool _isWithinReassembleWindow(DateTime prev, DateTime cur) {
    return cur.difference(prev).abs().inMilliseconds < _logReassembleWindowMs;
  }

  /// 添加日志条目 / Add log entry
  /// [entry] 日志条目对象 / Log entry object
  void addLogEntry(LogEntry entry) {
    final last = _logEntries.isNotEmpty ? _logEntries.first : null;
    if (last != null &&
        _isWithinReassembleWindow(last.timestamp, entry.timestamp)) {
      final msg = entry.message;
      // 若新行已是上一条的子集（如 debugPrint 拆行/换行包裹产生的重复片段），
      // 直接丢弃，避免与完整日志重复。
      // If the new line is already a substring of the previous entry (e.g. a
      // fragment produced by debugPrint line-splitting / wrap), drop it.
      if (msg.isNotEmpty && last.message.contains(msg)) {
        return;
      }
      // 续行则合并到上一条 / Merge continuation lines into the previous entry.
      if (_isReassembleContinuation(msg)) {
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
        _notifyThrottled();
        return;
      }
    }
    _logEntries.addFirst(entry);
    _trimQueue(_logEntries, _maxLogItems);
    AlertService.instance.checkLog(entry);
    _notifyThrottled();
  }

  /// 添加路由记录 / Add route record
  /// [entry] 路由记录对象 / Route record object
  void addRouteEntry(RouteEntry entry) {
    _routeEntries.addFirst(entry);
    _trimQueue(_routeEntries, _maxRouteItems);
    _notifyThrottled();
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
    notifyListeners();
  }

  /// 删除拦截规则 / Remove interceptor rule
  /// [id] 规则ID / Rule ID
  void removeInterceptorRule(String id) {
    _interceptorRules.removeWhere((r) => r.id == id);
    notifyListeners();
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
    _networkRequests.clear();
    _logEntries.clear();
    _routeEntries.clear();
    _interceptorRules.clear();
    _globalBodyBytes = 0;
    notifyListeners();
  }

  /// 清空网络请求记录 / Clear network request records
  void clearNetworkRequests() {
    _networkRequests.clear();
    _globalBodyBytes = 0;
    notifyListeners();
  }

  /// 按 id 删除单条网络请求（批量删除用）/ Remove a single request by id
  void removeNetworkRequest(String id) {
    _networkRequests.removeWhere((r) => r.id == id);
    notifyListeners();
  }

  /// 清空日志记录 / Clear log records
  void clearLogs() {
    _logEntries.clear();
    notifyListeners();
  }

  /// 清空路由记录 / Clear route records
  void clearRoutes() {
    _routeEntries.clear();
    notifyListeners();
  }

  /// 释放资源：重置帧排程标志 / Dispose: reset the frame-scheduling flag
  void disposeService() {
    _frameScheduled = false;
  }

  /// 帧对齐版 notifyListeners：把同一帧内的多次通知合并为一次，在下一帧绘制后触发，
  /// 避免每帧多次重建，也不在每次变更都分配 Timer。
  /// Frame-aligned notifyListeners: coalesces multiple notifications in the same frame
  /// into one fired after the next frame paint — avoids per-frame rebuild storms and
  /// per-change Timer allocations.
  void _notifyThrottled() {
    if (_frameScheduled) return;
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

  /// 裁剪 Queue 到最大条目数（从尾部移除，O(1)）/ Trim Queue to max items (removes from tail, O(1))
  void _trimQueue<T>(ListQueue<T> queue, int max) {
    while (queue.length > max) {
      queue.removeLast();
    }
  }

  /// 裁剪网络请求队列到最大条目数，并从全局 body 预算中释放被淘汰请求的占用。
  /// Trim network request queue to the cap, releasing evicted requests' body budget.
  void _trimNetworkRequests() {
    while (_networkRequests.length > _maxNetworkItems) {
      final removed = _networkRequests.removeLast();
      final freed = _bodyBytesOf(removed);
      _globalBodyBytes = _globalBodyBytes - freed < 0
          ? 0
          : _globalBodyBytes - freed;
    }
  }

  /// 在 Queue 中按 id 定位索引（用于 updateNetworkRequest）/ Locate index by id in the Queue
  int _indexOfNetworkRequest(String id) {
    var i = 0;
    for (final r in _networkRequests) {
      if (r.id == id) return i;
      i++;
    }
    return -1;
  }
}
