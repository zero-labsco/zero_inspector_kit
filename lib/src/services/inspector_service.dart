import 'package:flutter/foundation.dart';
import '../models/network_request.dart';
import '../models/log_entry.dart';
import '../models/route_entry.dart';

/// 检查器服务，用于管理所有收集的数据 / Inspector service for managing all collected data
///
/// 该服务继承自 ChangeNotifier，当数据发生变化时会自动通知监听者更新UI
/// This service extends ChangeNotifier and automatically notifies listeners when data changes
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

  /// 网络请求列表 / Network request list
  final List<NetworkRequest> _networkRequests = [];

  /// 日志条目列表 / Log entry list
  final List<LogEntry> _logEntries = [];

  /// 路由记录列表 / Route record list
  final List<RouteEntry> _routeEntries = [];

  /// 最大存储条目数，超过后自动裁剪 / Maximum number of items to store, auto-trim when exceeded
  final int _maxItems = 100;

  /// 获取网络请求列表（只读）/ Get network request list (read-only)
  List<NetworkRequest> get networkRequests =>
      List.unmodifiable(_networkRequests);

  /// 获取日志条目列表（只读）/ Get log entry list (read-only)
  List<LogEntry> get logEntries => List.unmodifiable(_logEntries);

  /// 获取路由记录列表（只读）/ Get route record list (read-only)
  List<RouteEntry> get routeEntries => List.unmodifiable(_routeEntries);

  /// 添加网络请求记录 / Add network request record
  /// [request] 网络请求对象 / Network request object
  void addNetworkRequest(NetworkRequest request) {
    _networkRequests.insert(0, request);
    _trimList(_networkRequests);
    notifyListeners();
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
    final index = _networkRequests.indexWhere((r) => r.id == id);
    if (index != -1) {
      final request = _networkRequests[index];
      final now = DateTime.now().millisecondsSinceEpoch;
      final responseTime = request.responseTime ?? now;
      final duration = responseTime - request.requestTime;
      _networkRequests[index] = NetworkRequest(
        id: request.id,
        method: request.method,
        url: request.url,
        headers: request.headers,
        body: body ?? request.body,
        responseBody: responseBody ?? request.responseBody,
        statusCode: statusCode ?? request.statusCode,
        requestTime: request.requestTime,
        responseTime: responseTime,
        duration: duration,
      );
      notifyListeners();
    }
  }

  /// 添加日志条目 / Add log entry
  /// [entry] 日志条目对象 / Log entry object
  void addLogEntry(LogEntry entry) {
    _logEntries.insert(0, entry);
    _trimList(_logEntries);
    notifyListeners();
  }

  /// 添加路由记录 / Add route record
  /// [entry] 路由记录对象 / Route record object
  void addRouteEntry(RouteEntry entry) {
    _routeEntries.insert(0, entry);
    _trimList(_routeEntries);
    notifyListeners();
  }

  /// 清空所有数据（网络请求、日志、路由）/ Clear all data (network requests, logs, routes)
  void clearAll() {
    _networkRequests.clear();
    _logEntries.clear();
    _routeEntries.clear();
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

  /// 裁剪列表到最大条目数 / Trim list to max items
  void _trimList(List list) {
    while (list.length > _maxItems) {
      list.removeLast();
    }
  }
}
