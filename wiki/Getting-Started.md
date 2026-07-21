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
| ✅ **Log Capture** | Auto-capture all `print()`, `debugPrint()` and Flutter errors via Zone / 通过 Zone 自动捕获所有日志 |
| ✅ **Network Interception** | Auto-intercept all **http** and **Dio** requests via HttpOverrides / 自动拦截所有网络请求 |
| ✅ **Database Scan** | Auto-scan and register SQLite databases / 自动扫描注册数据库 |
| ✅ **Floating Button** | Auto-displayed via Overlay, not affected by keyboard / 通过 Overlay 自动显示 |
| ✅ **Route Tracking** | Auto-inject `InspectorRouteObserver` into MaterialApp / 自动注入路由观察者 |

## Production Build / 生产构建

The inspector is **automatically disabled** in release mode. You don't need to remove any code — Flutter's tree-shaking will remove all inspector-related code from production builds.

检查器在 release 模式下会**自动禁用**，无需移除任何代码，Flutter 的 tree-shaking 会自动移除所有检查器相关代码。

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
