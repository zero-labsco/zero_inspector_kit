# Route Tracker / 路由追踪

## Overview / 概述

The Route Tracker monitors navigation history, recording all route push, pop, and replacement events.

路由追踪器监控导航历史，记录所有路由 push、pop 和替换事件。

## Auto-Injection / 自动注入

When using `runAppWithInspector()` or `wrapApp()`, the `InspectorRouteObserver` is automatically injected into `MaterialApp`'s `navigatorObservers`.

使用 `runAppWithInspector()` 或 `wrapApp()` 时，`InspectorRouteObserver` 会自动注入到 `MaterialApp` 的 `navigatorObservers` 中。

## Tracked Route Actions / 追踪的路由操作

| Action | Color | Description |
|--------|-------|-------------|
| push | Blue | `Navigator.push()` / 推入新路由 |
| pushNamed | Blue | `Navigator.pushNamed()` / 按名称推入 |
| pop | Orange | `Navigator.pop()` / 弹出路由 |
| popUntil | Orange | `Navigator.popUntil()` / 弹出直到 |
| pushReplacement | Purple | `Navigator.pushReplacement()` / 替换路由 |

## UI Features / UI 功能

### Route List / 路由列表
- Action badge with color / 带颜色的操作徽章
- Route name display / 路由名称显示
- Timestamp display / 时间戳显示
- Left border color indicates action type / 左侧边框颜色表示操作类型

### Route Detail / 路由详情
- Click a route to view details / 点击路由查看详情
- Shows: Action, Route Name, Timestamp, Arguments / 显示：操作、路由名、时间戳、参数
- Arguments displayed as formatted JSON / 参数以 JSON 格式显示

## Manual Setup (Optional) / 手动设置（可选）

If you use a custom Navigator or don't use `MaterialApp`, add the observer manually:

如果使用自定义 Navigator 或不使用 `MaterialApp`，请手动添加观察者：

```dart
MaterialApp(
  navigatorObservers: [InspectorRouteObserver()],
  home: MyHomePage(),
)
```
