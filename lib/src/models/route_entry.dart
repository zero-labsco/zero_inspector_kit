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
      case RouteAction.remove:
        return 'Remove';
      case RouteAction.unknown:
        return 'Unknown';
    }
  }
}

/// 路由操作类型枚举 / Route action type enumeration
///
/// [remove] 是新增值，对应 `NavigatorObserver.didRemove` —— 它既不是 push 也不是
/// pop（`pushReplacement` / `removeRoute` / 页面被替换后销毁都会触发），此前被
/// 错误地记成 `pop`。
/// [remove] is a new value for `NavigatorObserver.didRemove`, which is neither a
/// push nor a pop (it fires for `pushReplacement` / `removeRoute` / a page being
/// destroyed after being replaced) and used to be mislabeled as `pop`.
///
/// 注意：新增枚举值对写了对本类型做**穷尽 switch 且无 default** 的调用方是
/// 源码级不兼容的（Dart 3 会报未穷尽），因此放在 minor 版本而非补丁版本。
/// Note: adding an enum value is source-incompatible for callers with an
/// exhaustive switch and no `default`, which is why this ships in a minor release.
enum RouteAction {
  push,
  pop,
  pushReplacement,
  popUntil,
  pushNamed,
  unknown,
  remove,
}
