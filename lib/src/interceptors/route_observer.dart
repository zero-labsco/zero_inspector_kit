import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../models/route_entry.dart';
import '../services/inspector_service.dart';
import '../utils/inspector_internal_log.dart';

/// 路由观察者 / Route observer
/// 监听应用中的路由导航操作并记录 / Listen to route navigation operations in the app and record them
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

  /// 记录路由操作 / Record route operation
  void _logRoute(Route<dynamic> route, RouteAction action) {
    try {
      final routeName = route.settings.name ?? route.runtimeType.toString();
      final entry = RouteEntry(
        id: _generateId(),
        routeName: routeName,
        timestamp: DateTime.now(),
        action: action,
        arguments: _normalizeArguments(route.settings.arguments),
      );
      InspectorService.instance.addRouteEntry(entry);
    } catch (e, stackTrace) {
      // 观察者自身的异常绝不能冒泡进 Navigator：那会中断宿主 App 的这次跳转，
      // 并把 Navigator 留在 _debugLocked 状态，导致之后每次导航都断言失败。
      // An observer failure must never bubble into Navigator: it aborts the host
      // app's navigation and leaves Navigator._debugLocked set, so every later
      // navigation fails its assertion.
      InspectorInternalLog.error(
        'route_observer',
        '记录路由失败 / failed to log route: $e',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// 生成唯一路由记录ID / Generate unique route record ID
  String _generateId() {
    return 'route_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// 规整路由参数 / Normalize route arguments
///
/// [RouteSettings.arguments] 允许是任意对象（自定义页面参数类、数据模型等），
/// 直接强转成 `Map<String, dynamic>` 会在 `didPush` 里抛 `TypeError` 并中断这次导航，
/// 因此这里统一降级成路由面板与会话导出都能安全消化的形式，且永不抛异常：
/// - `null` → `null`
/// - `Map` → 浅拷贝，键统一转成 `String`
/// - 其他对象 → 能 JSON 化（`toJson`）时展开为字段，否则退化为 `toString()` 文本
///
/// `RouteSettings.arguments` may hold any object (custom page-argument classes,
/// data models, …). Casting it to `Map<String, dynamic>` throws a `TypeError`
/// inside `didPush` and aborts that navigation, so arguments are normalized here
/// into a form the route viewer and the session export can consume safely:
/// - `null` → `null`
/// - `Map` → shallow copy with `String` keys
/// - other objects → expanded via JSON (`toJson`) when possible, otherwise
///   degraded to `toString()` text
Map<String, dynamic>? _normalizeArguments(Object? raw) {
  if (raw == null) return null;
  if (raw is Map) return _stringKeyedMap(raw);
  try {
    final decoded = jsonDecode(jsonEncode(raw));
    return decoded is Map
        ? _stringKeyedMap(decoded)
        : <String, dynamic>{'value': decoded};
  } catch (_) {
    return <String, dynamic>{'value': raw.toString()};
  }
}

/// 浅拷贝 Map 并把键统一为 String / Shallow-copy a map with String keys
Map<String, dynamic> _stringKeyedMap(Map<dynamic, dynamic> source) =>
    source.map((key, value) => MapEntry(key.toString(), value));
