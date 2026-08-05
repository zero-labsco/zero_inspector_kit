import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/network_request.dart';
import '../models/log_entry.dart';
import '../models/route_entry.dart';
import '../models/interceptor_rule.dart';

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

  /// 各类数据容量上限（可经 [configure] 调整）/ Per-category capacities (tunable via [configure])
  int _maxNetworkItems = 100;
  int _maxLogItems = 500;
  int _maxRouteItems = 200;

  /// body 预览字节上限，超出部分截断（仅保留头部预览）/ Body preview cap; longer bodies are truncated
  int _maxBodyPreviewBytes = 32 * 1024;

  /// notify 节流定时器 / notify throttling timer
  Timer? _notifyTimer;

  /// 缓存的只读视图，避免每次访问都拷贝 List / Cached read-only views to avoid copying per access
  late final UnmodifiableListView<NetworkRequest> _networkRequestsView =
      UnmodifiableListView(_networkRequests);
  late final UnmodifiableListView<LogEntry> _logEntriesView =
      UnmodifiableListView(_logEntries);
  late final UnmodifiableListView<RouteEntry> _routeEntriesView =
      UnmodifiableListView(_routeEntries);
  late final UnmodifiableListView<RequestInterceptorRule>
      _interceptorRulesView = UnmodifiableListView(_interceptorRules);

  /// 配置容量上限与 body 预览截断长度 / Configure capacities and body preview cap
  /// 应在 [ZeroInspectorKit.init] 中调用，向后兼容（全部命名可选）。
  /// Call from [ZeroInspectorKit.init]; all params are optional and backward compatible.
  void configure({
    int? maxNetworkItems,
    int? maxLogItems,
    int? maxRouteItems,
    int? maxBodyPreviewBytes,
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
    _trimQueue(_networkRequests, _maxNetworkItems);
    _notifyThrottled();
  }

  /// 更新网络请求响应信息 / Update network request response info
  /// [id] 请求唯一ID / Request unique ID
  /// [responseBody] 响应体数据 / Response body data
  /// [statusCode] HTTP状态码 / HTTP status code
  /// [body] 请求体数据 / Request body data
  void updateNetworkRequest(
    String id, {
    dynamic responseBody,
    int? statusCode,
    dynamic body,
  }) {
    final index = _indexOfNetworkRequest(id);
    if (index != -1) {
      final request = _networkRequests.elementAt(index);
      final now = DateTime.now().millisecondsSinceEpoch;
      final responseTime = request.responseTime ?? now;
      final duration = responseTime - request.requestTime;
      _networkRequests
        ..remove(request)
        ..addFirst(
          request.copyWith(
            responseBody: responseBody ?? request.responseBody,
            statusCode: statusCode ?? request.statusCode,
            body: body ?? request.body,
            responseTime: responseTime,
            duration: duration,
            maxBodyBytes: _maxBodyPreviewBytes,
          ),
        );
      _notifyThrottled();
    }
  }

  /// 添加日志条目 / Add log entry
  /// [entry] 日志条目对象 / Log entry object
  void addLogEntry(LogEntry entry) {
    _logEntries.addFirst(entry);
    _trimQueue(_logEntries, _maxLogItems);
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
    notifyListeners();
  }

  /// 清空网络请求记录 / Clear network request records
  void clearNetworkRequests() {
    _networkRequests.clear();
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

  /// 释放资源：取消节流定时器 / Dispose: cancel throttling timer
  void disposeService() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
  }

  /// 节流版 notifyListeners：16ms（约一帧）内合并多次通知。
  /// Throttled notifyListeners: coalesces multiple notifications within ~one frame (16ms).
  void _notifyThrottled() {
    if (_notifyTimer != null && _notifyTimer!.isActive) return;
    _notifyTimer = Timer(const Duration(milliseconds: 16), () {
      notifyListeners();
    });
  }

  /// 裁剪 Queue 到最大条目数（从尾部移除，O(1)）/ Trim Queue to max items (removes from tail, O(1))
  void _trimQueue<T>(ListQueue<T> queue, int max) {
    while (queue.length > max) {
      queue.removeLast();
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
