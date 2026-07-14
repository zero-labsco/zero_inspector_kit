/// 路由条目模型
class RouteEntry {
  /// 路由记录唯一ID
  final String id;

  /// 路由名称
  final String routeName;

  /// 路由操作时间戳
  final DateTime timestamp;

  /// 路由操作类型
  final RouteAction action;

  /// 路由参数
  final Map<String, dynamic>? arguments;

  RouteEntry({
    required this.id,
    required this.routeName,
    required this.timestamp,
    required this.action,
    this.arguments,
  });

  /// 路由操作类型文本
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

/// 路由操作类型枚举
enum RouteAction {
  push,
  pop,
  pushReplacement,
  popUntil,
  pushNamed,
  unknown,
}