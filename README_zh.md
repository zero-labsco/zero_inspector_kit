# Zero Inspector Kit

<div align="center">

**简体中文** &nbsp;|&nbsp; [English](README.md)

</div>

一个功能强大的 Flutter 插件，用于应用内开发者控制台，提供实时调试工具：网络请求检查、日志记录、数据库查看、内存监控、FPS 监控和路由追踪。

[![pub version](https://img.shields.io/pub/v/zero_inspector_kit.svg)](https://pub.dev/packages/zero_inspector_kit)
[![pub points](https://img.shields.io/pub/points/zero_inspector_kit.svg)](https://pub.dev/packages/zero_inspector_kit/score)
[![CI](https://github.com/zero-labsco/zero_inspector_kit/actions/workflows/ci.yml/badge.svg)](https://github.com/zero-labsco/zero_inspector_kit/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://github.com/zero-labsco/zero_inspector_kit/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](https://pub.dev/packages/zero_inspector_kit)
[![Flutter](https://img.shields.io/badge/Flutter-✓-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-✓-0175C2?logo=dart)](https://dart.dev)
[![Style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://pub.dev/packages/effective_dart)

> **🔔 推荐升级：** v1.5.3 修复了悬浮检查器按钮的可见性（华为 `trimMemory` 抑制 Timer 导致不显示），并解决了所有查看器在任意设备尺寸与系统字号下的 RenderFlex 溢出问题。建议所有 1.5.2 用户升级到 `^1.5.3`。

🌐 **[官方网站](https://www.zerolabsco.com/)** &nbsp;·&nbsp; 📦 **[在 pub.dev 查看](https://pub.dev/packages/zero_inspector_kit)** &nbsp;·&nbsp; 🔗 **[查看 GitHub 仓库](https://github.com/zero-labsco/zero_inspector_kit)**

---

## 目录

- [功能特性](#功能特性)
- [安装](#安装)
- [使用方法](#使用方法)
  - [零侵入集成](#零侵入集成推荐)
  - [日志记录](#日志记录)
  - [网络请求](#网络请求)
  - [网络请求拦截修改](#网络请求拦截修改)
  - [数据库提供者](#数据库提供者)
  - [内存监控](#内存监控)
  - [FPS 监控](#fps-监控)
  - [自定义数据库提供者](#自定义数据库提供者)
  - [Widget 检查器与网络瀑布流](#widget-检查器与网络瀑布流默认关闭)
- [API 参考](#api-参考)
- [贡献](#贡献)
- [许可证](#许可证)

---

## 功能特性

- **零侵入集成**：一行代码，无需改动现有项目代码。
- **网络检查器**：实时捕获所有 HTTP（http & Dio）请求；通过拦截规则修改请求体/请求头；批量复制 cURL；敏感请求头遮蔽；可按方法/状态码/拦截状态筛选。
- **日志系统**：自动捕获 `print()`、Flutter 错误及自定义日志，支持多级别与第三方日志库集成；新增自动滚动（可暂停）、正则搜索、按标签过滤与单条日志一键复制。
- **数据库查看器**：支持 SQLite 及其他数据库，可自定义提供者。
- **内存监控**：趋势图、Dart Heap、Native 内存分项、泄漏检测、图片缓存与存储统计（总开关避免开销）。
- **FPS 监控**：实时帧率、掉帧检测、趋势图、帧记录（总开关避免开销）。
- **路由追踪器**：导航历史与当前路由。
- **告警系统**：针对网络/日志/内存/FPS 的告警规则，带未读红点与节流。
- **悬浮按钮**：呼吸动画的 Overlay 按钮，自动吸附屏幕边缘，避免返回手势冲突。
- **现代化 UI**：深色主题 + 渐变，集中式可定制配色。
- **跨平台**：支持 Android 与 iOS。

---

## 安装

### Pub.dev（推荐）

```yaml
dependencies:
  zero_inspector_kit: ^1.5.3
```

### GitHub

```yaml
dependencies:
  zero_inspector_kit:
    git:
      url: https://github.com/zero-labsco/zero_inspector_kit.git
      ref: release/v1.5.3   # 将 1.5.3 替换为你需要的版本号
```

---

## 使用方法

### 零侵入集成（推荐）

只需**一行代码**即可完成集成，无需修改项目任何现有代码：

```dart
import 'package:flutter/material.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  // 一行代码：初始化检查器、通过 Zone 捕获 print()、自动显示悬浮按钮
  ZeroInspectorKit.runAppWithInspector(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [InspectorRouteObserver()],
      home: Scaffold(
        appBar: AppBar(title: const Text('App')),
        body: const Center(child: Text('Hello World')),
      ),
    );
  }
}
```

**检查器自动完成的工作（无需改动其他代码）：**

| 能力 | 实现方式 |
|------|----------|
| ✅ 日志捕获 | 通过 Zone 捕获所有 `print()` / `debugPrint()` 与 Flutter 错误 |
| ✅ 网络拦截 | 通过 `HttpOverrides` 拦截 **http** 与 **Dio** 请求（Dio 使用 `HttpClient`） |
| ✅ 数据库扫描 | 自动扫描并注册 SQLite 数据库 |
| ✅ 悬浮按钮 | 通过 `Overlay` 自动显示，无需手动添加组件 |
| ✅ 路由追踪 | 通过 `InspectorRouteObserver`（自动注入 `MaterialApp`） |

**生产构建**：检查器在 release 模式下会自动禁用——tree-shaking 会移除所有相关代码，你无需删除任何代码。

### 手动集成（更多控制权）

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

void main() async {
  // 1) 手动初始化（比一行助手更可控）
  ZeroInspectorKit.init(
    enableWidgetInspector: true,   // 可选：预开启 Widget Inspector
    enableNetworkTimeline: true,   // 可选：预开启 Network Timeline
  );

  // 2) 注册自定义数据源（一行 API）
  final prefs = await SharedPreferences.getInstance();
  ZeroInspectorKit.registerSharedPrefs(SharedPreferencesAdapter(prefs));

  final settings = await Hive.openBox('settings');
  final cache = await Hive.openBox('cache');
  ZeroInspectorKit.registerHive({
    'settings': HiveBoxAdapter(settings),
    'cache': HiveBoxAdapter(cache),
  });

  // 3) 用 wrapApp 包裹你的应用
  runApp(ZeroInspectorKit.wrapApp(const MyApp()));
}
```

> **关于依赖**：本包自身不依赖 `shared_preferences` / `hive`；但**你的 app 若要查看这些数据，仍需在自己的 `pubspec.yaml` 中加入对应包**。两者都会作为 **Database** 标签页下的条目出现，并复用与 SQLite 相同的浏览/导出流程。

<details>
<summary>想用更底层的 API？也可以自行注册提供者。</summary>

```dart
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  ZeroInspectorKit.init();
  DatabaseRegistry.instance.registerProvider(SharedPrefsProvider(prefs: prefs));
  DatabaseRegistry.instance.registerProvider(HiveProvider(box: box, name: 'settings'));
  runApp(ZeroInspectorKit.wrapApp(const MyApp()));
}
```

</details>

### 日志记录

启动后自动从多个来源捕获日志：

```dart
InspectorLogInterceptor.instance.start();
```

**自动捕获：** `print()` / `debugPrint()` 调用、Flutter 框架错误、`runZonedGuarded` 捕获的未处理异常。

**手动记录（可选）：**

```dart
InspectorLog.v('详细'); InspectorLog.d('调试');
InspectorLog.i('信息'); InspectorLog.w('警告');
InspectorLog.e('错误');
```

使用 `print()`/`debugPrint()` 的第三方日志库（如 `logger`、`flutter_logger`）会被自动捕获，无需配置。用 `onLogCaptured` 可将捕获的日志同步回你自己的日志服务：

```dart
import 'package:logger/logger.dart';
final logger = Logger();

InspectorLogInterceptor.instance.onLogCaptured = (entry) {
  logger.log(_mapLogLevel(entry.level),
    '${entry.tag != null ? '[${entry.tag}] ' : ''}${entry.message}');
};
```

### 网络请求

所有 HTTP 请求（包括 **http 包**和 **Dio**）在初始化后都会通过 `HttpOverrides` 自动拦截，无需额外配置。

```dart
import 'package:http/http.dart' as http;
final r = await http.get(Uri.parse('https://api.example.com/data')); // 自动捕获
```

```dart
import 'package:dio/dio.dart';
final dio = Dio();
final r = await dio.get('https://api.example.com/data'); // 自动捕获
```

> **注意：** Dio 默认使用 `IOHttpClientAdapter`（内部使用 `dart:io` 的 `HttpClient`），因此可被检查器自动捕获，无需额外配置。

### 网络请求拦截修改

通过规则拦截并修改网络请求，适用于测试不同参数而无需修改应用代码。

**使用流程：** 正常发送请求 → 打开详情 → 点击拦截器图标 → 配置规则（URL 匹配、方法、请求体/请求头修改）→ 保存。后续匹配的请求将使用修改后的参数。

| 项目 | 说明 |
|------|------|
| 支持的修改 | 请求体与请求头（仅 POST/PUT/PATCH） |
| GET 请求 | 仅可查看，无法修改（无请求体） |
| 规则匹配 | 精确或正则 URL 匹配；方法过滤（GET/POST/PUT/DELETE/PATCH/HEAD/任意） |

未配置规则或规则被禁用时，所有请求均正常发送，不会进行任何修改。

### 数据库提供者

```dart
DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
```

### 内存监控

全面的内存分析功能，顶部总开关控制数据采集（默认关闭以避免性能开销）。

- **总开关**：内存面板顶部开关；关闭时停止所有定时器、断开 VM Service 连接。
- **趋势图**：2 分钟历史窗口（240 条快照 × 500ms），可切换 进程 RSS / Dart Heap / 新生代 / 老生代。
- **Dart Heap（需 VM Service）**：使用量/容量/外部 进度条；新生代/老生代明细；手动 GC 按钮。
- **Native 内存（真机 100% 可用）**：Android PSS 分项；iOS 物理内存/压缩内存/RSS；低内存警告。
- **泄漏检测（基于 Dart 2.17+ WeakReference）**：`trackObject()` 四状态流转；超时自动触发 GC 验证；UI 显示疑似/追踪中/已释放对象。

```dart
myBloc.trackMemoryLeak(tag: 'HomePage_myBloc');   // 简写
// 或：trackMemoryLeak(myBloc, tag: 'HomePage_myBloc');
myBloc.untrackMemoryLeak();                        // 取消追踪
MemoryInspectorService.instance.clearLeakRecords(); // 清空所有
```

- **图片缓存**：实时大小/数量，加载中 vs 使用中，使用率进度条，一键清理。
- **应用存储**：文档/缓存/数据库大小，一键清理临时缓存。

> **⚠️ VM Service 可用性：** 通过 PC 使用 `flutter run` 调试时，Dart VM Heap 可能显示 `VM: OFF`（端口转发限制）。Native 内存与进程 RSS 仍正常显示。直接在真机打开 debug 应用时 Heap 数据正常。

### FPS 监控

实时帧性能分析，顶部总开关控制数据采集（默认关闭以避免性能开销）。

- **总开关**：FPS 面板顶部开关；关闭时无帧回调、零开销。
- **指标**：当前 FPS、掉帧率、总帧数、30 秒趋势图（60 点）、掉帧列表（>16ms）。
- **准确度（v1.2.1 起）**：使用真实 `buildStart` 时间戳（非 `DateTime.now()`），帧耗时取 `rasterFinish - buildStart`，可检测 GPU 光栅化卡顿。

```dart
FpsService.instance.start();
final fps = FpsService.instance.currentFps;
final jank = FpsService.instance.jankRate;
FpsService.instance.clear();
```

### 自定义数据库提供者

实现 `DatabaseProvider` 接口以支持其他数据库：

```dart
class MyCustomDatabaseProvider implements DatabaseProvider {
  @override
  String get name => 'CustomDB';

  @override
  Future<List<DatabaseInfo>> getDatabases() async => [];

  @override
  Future<QueryResult> queryTable(String dbPath, String tableName, {int limit = 50}) async =>
      QueryResult(columns: [], rows: []);
}

DatabaseRegistry.instance.registerProvider(MyCustomDatabaseProvider());
```

### Widget 检查器与网络瀑布流（默认关闭）

两项功能默认关闭，避免在不需要时产生开销。启动时预开启：

```dart
ZeroInspectorKit.runAppWithInspector(
  const MyApp(),
  enableWidgetInspector: true,    // 拍一次组件树快照 + 面包屑导航
  enableNetworkTimeline: true,    // 实时请求瀑布流
);
```

- **Widget Inspector**：开启后拍一次快照，以面包屑方式浏览（非实时；点「刷新」重新快照）。
- **Network Timeline**：实时瀑布流，新请求自动流入，无需手动刷新。

---

## API 参考

### FloatingInspectorButton

| 参数 | 类型 | 描述 |
|------|------|------|
| `enabled` | `bool` | 是否启用检查器（默认：`true`，release 模式下自动禁用） |

### ConditionalInspector

根据构建模式自动显示/隐藏检查器的便利组件。

```dart
ConditionalInspector(child: YourAppWidget())
```

| 参数 | 类型 | 描述 |
|------|------|------|
| `child` | `Widget` | 子组件 |
| `enabled` | `bool` | 是否启用检查器（默认：`true`） |

### InspectorLogInterceptor

| 方法 | 描述 |
|------|------|
| `start()` / `stop()` | 开始 / 停止捕获日志 |
| `log(level, message, tag)` | 添加日志条目 |
| `verbose/debug/info/warning/error(message, tag)` | 按级别添加日志 |

| 属性 | 类型 | 描述 |
|------|------|------|
| `onLogCaptured` | `void Function(LogEntry)?` | 日志捕获回调，用于第三方日志库集成 |

### InspectorLog

`InspectorLogInterceptor.instance` 的简写包装类。

| 方法 | 描述 |
|------|------|
| `start()` / `stop()` | 开始 / 停止捕获日志 |
| `log(level, message, {tag})` | 添加日志条目 |
| `v/d/i/w/e(message, {tag})` | 按级别添加日志 |

| 属性 | 类型 | 描述 |
|------|------|------|
| `isRunning` | `bool` | 当前是否正在捕获日志 |

### InspectorRouteObserver

用于追踪路由变化的 Navigator observer。

### FpsService

FPS 监控单例服务，继承自 `ChangeNotifier`。

| 方法 | 描述 |
|------|------|
| `start()` / `stop()` | 启动 / 停止监控 |
| `clear()` | 清空所有历史数据和计数 |

| 属性 | 类型 | 描述 |
|------|------|------|
| `isRunning` | `bool` | 当前是否正在监控 |
| `currentFps` | `double` | 当前 FPS（每 500ms 更新） |
| `jankRate` | `double` | 掉帧率（百分比） |
| `totalFrameCount` | `int` | 累计总帧数 |
| `totalJankyCount` | `int` | 累计掉帧数（>16ms） |
| `lastFrameJanky` | `bool` | 最近一帧是否掉帧 |
| `fpsHistory` | `List<double>` | 最近 60 个 FPS 历史值（不可修改） |
| `frameRecords` | `List<FrameRecord>` | 最近帧记录（不可修改，最多 3600 条） |

### runInspectorApp

使用检查器 Zone 运行应用，启用自动 `print()` 捕获。

```dart
runInspectorApp(VoidCallback appRunner)
```

| 参数 | 类型 | 描述 |
|------|------|------|
| `appRunner` | `VoidCallback` | 运行应用的函数（通常是 `runApp`） |

---

## 贡献

欢迎贡献代码！提交 issue 或 pull request 前，请先阅读[贡献指南](CONTRIBUTING.md)。

- 🐛 [报告 Bug](https://github.com/zero-labsco/zero_inspector_kit/issues/new?template=bug_report.md)
- 💡 [功能建议](https://github.com/zero-labsco/zero_inspector_kit/issues/new?template=feature_request.md)
- 💬 [参与讨论](https://github.com/zero-labsco/zero_inspector_kit/discussions)
- 📖 [贡献指南](CONTRIBUTING.md)

---

## 许可证

本项目采用 GNU General Public License v3.0 许可证 - 详见 [LICENSE](LICENSE) 文件。

本插件采用 GPL-3.0 授权，允许商业使用；任何对本插件进行修改并再分发的衍生项目，必须以相同许可证公开其完整源代码。

本插件按"原样"提供，不提供任何担保。作者不对修改版或衍生项目的功能、安全性及任何使用后果承担责任。
