import 'package:flutter/widgets.dart';
import '../models/route_entry.dart';
import '../services/inspector_service.dart';

/// 路由观察者
/// 监听应用中的路由导航操作并记录
class InspectorRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _logRoute(route, RouteAction.push);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _logRoute(route, RouteAction.pop);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) {
      _logRoute(newRoute, RouteAction.pushReplacement);
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _logRoute(route, RouteAction.pop);
  }

  /// 记录路由操作
  void _logRoute(Route<dynamic> route, RouteAction action) {
    final routeName = route.settings.name ?? route.runtimeType.toString();
    final entry = RouteEntry(
      id: _generateId(),
      routeName: routeName,
      timestamp: DateTime.now(),
      action: action,
      arguments: route.settings.arguments as Map<String, dynamic>?,
    );
    InspectorService.instance.addRouteEntry(entry);
  }

  /// 生成唯一路由记录ID
  String _generateId() {
    return 'route_${DateTime.now().millisecondsSinceEpoch}';
  }
}