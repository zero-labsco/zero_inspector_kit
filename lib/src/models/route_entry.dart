/// 路由条目模型 / Route entry model
class RouteEntry {
  /// 路由记录唯一ID / Route record unique ID
  final String id;

  /// 路由名称 / Route name
  final String routeName;

  /// 路由操作时间戳 / Route operation timestamp
  final DateTime timestamp;

  /// 路由操作类型 / Route operation type
  final RouteAction action;

  /// 路由参数 / Route arguments
  final Map<String, dynamic>? arguments;

  RouteEntry({
    required this.id,
    required this.routeName,
    required this.timestamp,
    required this.action,
    this.arguments,
  });

  /// 路由操作类型文本 / Route action text
  String get actionText {
    switch (action) {
      case RouteAction.push:
        return 'Push';
      case RouteAction.pop:
        return 'Pop';
      case RouteAction.pushReplacement:
        return 'Push Replacement';
      case RouteAction.popUntil:
        return 'Pop Until';
      case RouteAction.pushNamed:
        return 'Push Named';
      case RouteAction.unknown:
        return 'Unknown';
    }
  }
}

/// 路由操作类型枚举 / Route action type enumeration
enum RouteAction {
  push,
  pop,
  pushReplacement,
  popUntil,
  pushNamed,
  unknown,
}