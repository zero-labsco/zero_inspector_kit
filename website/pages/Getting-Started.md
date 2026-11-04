# Getting Started / 快速开始

## Quick Start / 快速开始

Integrate with just **1 line of code**:

仅需 **1 行代码** 即可完成集成：

```dart
import 'package:flutter/material.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  // Single line: Initialize inspector, capture print() via Zone, and display floating button
  // 一行代码：初始化检查器、通过 Zone 捕获 print()、自动显示悬浮按钮
  ZeroInspectorKit.runAppWithInspector(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('App')),
        body: const Center(child: Text('Hello World')),
      ),
    );
  }
}
```

## What Happens Automatically / 自动完成的工作

After integration, the inspector automatically does the following **without modifying any other project code**:

集成后，检查器会自动完成以下工作，**无需修改项目其他代码**：

| Feature | Description |
|---------|-------------|
| ✅ **Log Capture** | Auto-capture all `print()`, `debugPrint()` via Zone / 通过 Zone 自动捕获所有日志 |
| ✅ **Network Interception** | Auto-intercept all **http** and **Dio** requests via HttpOverrides / 自动拦截所有网络请求 |
| ✅ **Error Capture** | Aggregate Flutter framework errors & unhandled exceptions, deduped by type + stack (Errors tab) / 聚合 Flutter 框架异常与未捕获异常，按类型+堆栈去重 |
| ✅ **Session Persistence** | Flush logs/network/errors to a disk ring buffer; logs & errors replay on next launch / 日志/网络/异常落盘环形缓冲，启动时回放日志与异常 |
| ✅ **Database Scan** | Auto-scan and register SQLite databases / 自动扫描注册数据库 |
| ✅ **Floating Button** | Auto-displayed via Overlay, not affected by keyboard / 通过 Overlay 自动显示 |
| ✅ **Route Tracking** | Auto-inject `InspectorRouteObserver` into MaterialApp / 自动注入路由观察者 |

> **Note / 说明**: The **Memory** and **FPS** panels are available as tabs but are **off by default** to avoid performance overhead. Toggle the switch at the top of each panel to start collecting data. See [Memory Viewer](Memory-Viewer) and [FPS Viewer](FPS-Viewer) for details.
>
> **Memory** 和 **FPS** 面板作为标签页可用，但**默认关闭**以避免性能开销。在各自面板顶部打开开关才会开始采集数据。详见 [Memory Viewer](Memory-Viewer) 和 [FPS Viewer](FPS-Viewer)。

> **Pre-initialized binding / 提前初始化的 binding**: If you call `WidgetsFlutterBinding.ensureInitialized()` or `await` a platform-channel plugin (e.g. `SharedPreferences`) **before** `runAppWithInspector()`, the binding is already initialized. In that case `runAppWithInspector()` degrades gracefully to a plain `runApp()` (capturing `debugPrint` logs, but not raw `print()`) instead of throwing a "Zone mismatch" assertion. No extra setup is needed.
>
> **binding 已提前初始化**：如果你在 `runAppWithInspector()` **之前**调用了 `WidgetsFlutterBinding.ensureInitialized()` 或 `await` 了会触发 platform channel 的插件（如 `SharedPreferences`），binding 已被初始化。此时 `runAppWithInspector()` 会优雅降级为普通 `runApp()`（仍捕获 `debugPrint` 日志，但不捕获原始 `print()`），而非抛出 "Zone mismatch" 断言。无需额外处理。

## Production Build / 生产构建

The inspector is **automatically disabled** in release mode. You don't need to remove any code — Flutter's tree-shaking will remove all inspector-related code from production builds.

检查器在 release 模式下会**自动禁用**，无需移除任何代码，Flutter 的 tree-shaking 会自动移除所有检查器相关代码。

## Enabling in Release Builds (QA / Internal Testing) / 在 Release 构建中启用（QA / 内部测试）

By default the inspector is **auto-disabled and tree-shaken out of release (AOT) builds** — its code is physically absent from the production binary. If you add **no** `zero_inspector_kit:` config to your app's `pubspec.yaml` at all, it falls back to `debug`, so release builds stay tree-shaken, exactly as before.

默认情况下，检查器在 release（AOT）构建中**自动禁用并被 tree-shake 剔除**。若你的 `pubspec.yaml` 完全不加入 `zero_inspector_kit:` 配置，则回退为 `debug`，release 构建仍被 tree-shake 剔除，与之前完全一致。

To ship a release build that still carries the inspector for QA / internal testers, opt in at **compile time** by adding the following to **your app's** `pubspec.yaml` (the app that depends on this package):

若希望发布仍携带检查器、供 QA / 内部测试的 release 构建，需在**编译期**显式开启：在你的应用（即依赖本包的那个应用）的 `pubspec.yaml` 中加入：

```yaml
zero_inspector_kit:
  inspector_modes: all   # default is `debug`
```

The recommended approach is to keep the config in `pubspec.yaml` and build via the provided helper (it reads `inspector_modes` and injects the flag for you):

推荐做法是在 `pubspec.yaml` 中保留该配置，并通过随包发布的辅助脚本构建（它会读取 `inspector_modes` 并自动注入 flag）：

```bash
# from your app's directory / 在你的应用目录下执行
dart run zero_inspector_kit:build_inspector build apk --release
# or pass the flag directly / 或直接传入 flag：
flutter build apk --release --dart-define=INSPECTOR_MODES=all
```

- `debug` (default): enabled in debug/profile, disabled (tree-shaken) in release. / `debug`（默认）：debug/profile 启用，release 禁用（tree-shake 剔除）。
- `all` / `release`: also bundled and enabled in release builds. / `all` / `release`：release 构建也一并打进并启用。

> **⚠️ What does NOT work in a release build even when enabled / ⚠️ 即便开启，release 下仍无法检查到的内容**
> A release (AOT) build disables the Dart VM Service, so everything that depends on it is unavailable regardless of this flag:
> release（AOT）构建会禁用 Dart VM Service，因此一切依赖它的功能都不可用，与是否开启本开关无关：
> - Memory **allocation histogram** (VM Service `getAllocationProfile`) / 内存**分配直方图**（VM Service 的 `getAllocationProfile`）
> - Deep object-graph / retaining-path analysis / 对象图 / 引用链深度分析
> - Any live VM Service introspection / 任何实时的 VM Service 内省
>
> What still works in release: **HTTP / WebSocket / gRPC inspection, logs, error aggregation, FPS jank tracking, routes, and the bug-report exporter.** If testers need full memory profiling, give them a **`--profile`** build instead — it keeps the VM Service reachable while behaving like release.
> release 下仍然可用：**HTTP / WebSocket / gRPC 检查、日志、错误聚合、FPS 卡顿追踪、路由，以及缺陷报告导出。** 若测试需要完整内存分析，请给他们一个 **`--profile`** 构建——它保留可达的 VM Service，行为却与 release 相近。

## Alternative Integration / 替代集成方式

If you prefer more control, use the two-line approach:

如果需要更多控制权，可以使用两行代码方式：

```dart
void main() {
  ZeroInspectorKit.init();
  runApp(ZeroInspectorKit.wrapApp(const MyApp()));
}
```

## Next Steps / 下一步

- [Installation](Installation) — Detailed installation methods / 详细安装方式
- [Usage](Usage) — Full usage guide / 完整使用指南
- [Configuration](Configuration) — Configuration options / 配置选项
