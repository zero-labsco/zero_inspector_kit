import '../models/network_request.dart';
import '../models/log_entry.dart';
import '../models/route_entry.dart';

/// 检查器服务，用于管理所有收集的数据
class InspectorService {
  InspectorService._();

  /// 单例实例
  static final InspectorService instance = InspectorService._();

  /// 网络请求列表
  final List<NetworkRequest> _networkRequests = [];

  /// 日志条目列表
  final List<LogEntry> _logEntries = [];

  /// 路由记录列表
  final List<RouteEntry> _routeEntries = [];

  /// 最大存储条目数
  final int _maxItems = 100;

  /// 获取网络请求列表（只读）
  List<NetworkRequest> get networkRequests => List.unmodifiable(_networkRequests);

  /// 获取日志条目列表（只读）
  List<LogEntry> get logEntries => List.unmodifiable(_logEntries);

  /// 获取路由记录列表（只读）
  List<RouteEntry> get routeEntries => List.unmodifiable(_routeEntries);

  /// 添加网络请求记录
  void addNetworkRequest(NetworkRequest request) {
    _networkRequests.insert(0, request);
    _trimList(_networkRequests);
  }

  /// 更新网络请求响应信息
  void updateNetworkRequest(String id, {dynamic responseBody, int? statusCode}) {
    final index = _networkRequests.indexWhere((r) => r.id == id);
    if (index != -1) {
      final request = _networkRequests[index];
      final now = DateTime.now().millisecondsSinceEpoch;
      final duration = request.responseTime != null ? now - request.requestTime : null;
      _networkRequests[index] = NetworkRequest(
        id: request.id,
        method: request.method,
        url: request.url,
        headers: request.headers,
        body: request.body,
        responseBody: responseBody,
        statusCode: statusCode,
        requestTime: request.requestTime,
        responseTime: now,
        duration: duration,
      );
    }
  }

  /// 添加日志条目
  void addLogEntry(LogEntry entry) {
    _logEntries.insert(0, entry);
    _trimList(_logEntries);
  }

  /// 添加路由记录
  void addRouteEntry(RouteEntry entry) {
    _routeEntries.insert(0, entry);
    _trimList(_routeEntries);
  }

  /// 清空所有数据
  void clearAll() {
    _networkRequests.clear();
    _logEntries.clear();
    _routeEntries.clear();
  }

  /// 清空网络请求记录
  void clearNetworkRequests() {
    _networkRequests.clear();
  }

  /// 清空日志记录
  void clearLogs() {
    _logEntries.clear();
  }

  /// 清空路由记录
  void clearRoutes() {
    _routeEntries.clear();
  }

  /// 裁剪列表到最大条目数
  void _trimList(List list) {
    while (list.length > _maxItems) {
      list.removeLast();
    }
  }
}