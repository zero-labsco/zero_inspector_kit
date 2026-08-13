# Zero Inspector Kit

一个功能强大的 Flutter 插件，用于应用内开发者控制台，提供实时调试工具，包括网络请求检查、日志记录、数据库查看、内存监控、FPS 监控和路由追踪。

[![pub version](https://img.shields.io/pub/v/zero_inspector_kit.svg)](https://pub.dev/packages/zero_inspector_kit)
[![pub points](https://img.shields.io/pub/points/zero_inspector_kit.svg)](https://pub.dev/packages/zero_inspector_kit/score)
[![CI](https://github.com/zero-labsco/zero_inspector_kit/actions/workflows/ci.yml/badge.svg)](https://github.com/zero-labsco/zero_inspector_kit/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://github.com/zero-labsco/zero_inspector_kit/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](https://pub.dev/packages/zero_inspector_kit)
[![Flutter](https://img.shields.io/badge/Flutter-✓-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-✓-0175C2?logo=dart)](https://dart.dev)
[![Style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://pub.dev/packages/effective_dart)

> **🔔 推荐升级：** v1.4.0 为检查器带来两项新增 —— **路由追踪穿透**（当根组件是包裹壳，如 `StatelessWidget` / `Container` / `Builder` / `Padding` / `Center` 包着真正的 `MaterialApp` 时，检查器会穿透壳、定位内部 `MaterialApp` 并自动注入 `InspectorRouteObserver`，无需把 `MaterialApp` 直接作为根传入即可启用路由追踪）与**更丰富的网络筛选**（网络查看器新增可展开筛选面板，可按 HTTP Method、状态码区间、拦截状态筛选）。建议所有用户升级到 `^1.4.0`。

🌐 **[官方网站](https://www.zerolabsco.com/)**

📦 **[在 pub.dev 查看](https://pub.dev/packages/zero_inspector_kit)**

🔗 **[查看 GitHub 仓库](https://github.com/zero-labsco/zero_inspector_kit)**

## 功能特性

- **零侵入性**: 仅需一行代码即可集成，无需修改项目任何现有代码。
- **网络检查器**: 实时捕获和查看所有 HTTP 请求，包括请求/响应头、请求体、状态码和延迟时间。支持通过拦截规则修改请求体和请求头（仅 POST/PUT/PATCH 请求）。支持批量选择（批量「Copy as cURL」与批量删除）和一键复制 cURL。工具栏眼睛开关可在导出时遮蔽敏感请求头（`Authorization`、`Cookie` 等）。网络查看器还提供可展开筛选面板 —— 可按 HTTP Method、状态码区间（2xx/3xx/4xx/5xx/Other）、拦截状态（已修改/未修改）筛选，并可与关键词搜索组合使用。
- **日志系统**: 自动捕获应用中的日志，包括 print() 调用、Flutter 错误和异常。支持多种日志级别（verbose、debug、info、warning、error），并支持第三方日志库集成。
- **数据库查看器**: 支持 SQLite 和其他数据库的检查，支持自定义数据库提供者。
- **内存监控**: 实时内存监控，包含趋势图、Dart Heap 详情、Native 内存分项（Android PSS / iOS physicalFootprint）、内存泄漏检测、图片缓存监控和应用存储统计。提供总开关避免性能开销。
- **FPS 监控**: 实时帧率测量、帧耗时统计、掉帧检测、FPS 趋势折线图（30 秒窗口）。提供总开关避免性能开销。
- **路由追踪器**: 监控导航历史和当前路由信息。
- **告警系统**: 可针对网络请求、日志、内存、FPS 定义告警规则，主动暴露问题。悬浮球显示未读告警数红点（打开面板即清零），Alerts 标签页列出已触发的告警。同源节流（基于 source + message 的 1 秒滑动窗口）会在持续超阈值或请求突发时抑制重复告警，同时周期性的重新触发保证持续问题始终可见。
- **悬浮按钮**: 带呼吸动画的可访问悬浮检查按钮，通过根 `Overlay` 渲染，独立于任意页面的 widget 树。拖动松手后自动吸附并"收入"最近的屏幕边缘（仅露出小部分）；点击露出部分会平滑拉出到完整可见，再次点击才打开面板。此设计避免了与系统边缘返回手势的冲突。
- **跨平台**: 支持 Android 和 iOS 平台。

## 安装

### Pub.dev（推荐）

在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  zero_inspector_kit: ^1.4.0
```

### GitHub

或者，你也可以从 GitHub 安装（将 `1.4.0` 替换为你需要的版本号）：

```yaml
dependencies:
  zero_inspector_kit:
    git:
      url: https://github.com/zero-labsco/zero_inspector_kit.git
      ref: release/v1.4.0
```

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

**零侵入性说明**：

集成后，检查器会自动完成以下工作，无需修改项目其他代码：

- ✅ **日志捕获**: 通过 Zone 自动捕获所有 `print()`、`debugPrint()` 调用和 Flutter 错误
- ✅ **网络拦截**: 通过 HttpOverrides 自动拦截 **http 包**和 **Dio** 的所有网络请求（Dio 默认使用 HttpClient）。
- ✅ **数据库扫描**: 自动扫描并注册 SQLite 数据库
- ✅ **悬浮按钮**: 通过 Overlay 自动显示，无需手动添加任何组件
- ✅ **路由追踪**: 通过 `InspectorRouteObserver` 监控导航历史（自动注入到 MaterialApp）

**生产构建**: 检查器在 release 模式下会自动禁用。你不需要移除任何代码 - Flutter 的 tree-shaking 会从生产构建中移除所有检查器相关代码。

### 手动集成（更多控制权）

如果你需要更多控制权（例如要在启动时预开启某些开关，或注册自定义数据源），可以使用手动集成方式：

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

void main() async {
  // 1) 手动初始化（比一行 runAppWithInspector 更可控）
  ZeroInspectorKit.init(
    enableWidgetInspector: true,   // 可选：预开启 Widget Inspector
    enableNetworkTimeline: true,   // 可选：预开启 Network Timeline
  );

  // 2) 注册自定义数据源（一行 API）
  //    SharedPreferences / Hive：本包自身不依赖这两个包，
  //    只要传入的对象暴露对应的读写接口即可（不强制版本）。
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

> **关于依赖**：本包自己不需要 `shared_preferences` / `hive` 依赖；但**你的 app 若要查看这些数据，仍需要在自己的 `pubspec.yaml` 中加入对应包**（上面示例已 import），以便拿到 `prefs` / `box` 实例传给检查器。

两者都会作为 **Database** 标签页下的条目出现，并复用与 SQLite 相同的浏览/导出流程。

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

**自动捕获的日志：**
- `print()` 和 `debugPrint()` 调用
- Flutter 框架错误和异常
- `runZonedGuarded` 捕获的未处理异常

**手动记录日志（可选）：**

如果需要更精确的日志级别控制，可以使用检查器提供的日志方法。这是**可选功能**，不影响自动捕获功能。

简写形式（推荐）：

```dart
InspectorLog.v('详细日志');
InspectorLog.d('调试日志');
InspectorLog.i('信息日志');
InspectorLog.w('警告日志');
InspectorLog.e('错误日志');
```

如有需要，也可以使用完整形式：

```dart
InspectorLogInterceptor.instance.verbose('详细日志');
InspectorLogInterceptor.instance.debug('调试日志');
InspectorLogInterceptor.instance.info('信息日志');
InspectorLogInterceptor.instance.warning('警告日志');
InspectorLogInterceptor.instance.error('错误日志');
```

**第三方日志库集成（自动）：**

**无需任何配置！** 插件会自动捕获所有使用 `print()` 或 `debugPrint()` 的第三方日志库（如 logger、flutter_logger、logcat）的日志。

工作原理：插件通过覆盖 `debugPrint` 和 Zone 机制捕获所有 `print()` 调用，而大多数第三方日志库内部都是通过 `print()` 输出日志的。

这些日志统一归类到 **INFO 级别**，因为每个库都有自己的级别标识（emoji、前缀等），用户可通过日志内容识别级别。

**双向同步（可选）：**

如果需要将检查器捕获的日志同步到第三方日志库（让检查器日志也出现在你的日志服务中），可以使用 `onLogCaptured` 回调：

```dart
import 'package:logger/logger.dart';

final logger = Logger();

InspectorLogInterceptor.instance.onLogCaptured = (entry) {
  logger.log(
    _mapLogLevel(entry.level),
    '${entry.tag != null ? '[${entry.tag}] ' : ''}${entry.message}',
  );
};
```

### 网络请求

所有 HTTP 请求（包括 **http 包**和 **Dio**）在初始化后都会通过 `HttpOverrides` 自动拦截。无需任何额外配置！

**http 包：**
```dart
import 'package:http/http.dart' as http;

// GET 请求（自动捕获）
final response = await http.get(
  Uri.parse('https://api.example.com/data'),
);

// POST 请求（自动捕获）
final response = await http.post(
  Uri.parse('https://api.example.com/data'),
  body: {'key': 'value'},
);
```

**Dio（零侵入）：**
```dart
import 'package:dio/dio.dart';

final Dio dio = Dio();

// GET 请求（自动捕获）
final response = await dio.get('https://api.example.com/data');

// POST 请求（自动捕获）
final response = await dio.post(
  'https://api.example.com/data',
  data: {'key': 'value'},
);
```

**注意：** Dio 默认使用 `IOHttpClientAdapter`，内部使用 `dart:io` 的 `HttpClient`。这使得检查器可以通过 `HttpOverrides` 自动捕获 Dio 请求，无需任何额外配置。

### 网络请求拦截修改

检查器支持通过规则拦截并修改网络请求，适用于测试不同的请求参数而无需修改应用代码。

**使用流程：**
1. 正常发送请求（会被自动捕获到网络面板）
2. 打开请求详情，点击拦截器图标
3. 配置修改规则（URL 匹配模式、HTTP 方法、请求修改内容）
4. 保存规则 — 后续匹配的请求将使用修改后的参数

**支持的修改内容：**
- 请求体和请求头
- 仅支持有请求体的请求方法（POST、PUT、PATCH 等）
- GET 请求仅可查看，无法修改

**为什么 GET 请求不能修改？**
- 拦截修改功能目前仅支持修改请求体和请求头
- GET 请求没有请求体
- 修改 GET 请求参数需要修改 URL
- URL 修改可能导致请求路由和参数编码等意外问题

**规则匹配：**
- URL 匹配模式（精确匹配或正则匹配）
- HTTP 方法过滤（GET、POST、PUT、DELETE、PATCH、HEAD 或任意）

**注意：** 未配置规则或规则被禁用时，所有请求均正常发送，不会进行任何修改。

### 数据库提供者

```dart
DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
```

### 内存监控

内存监控提供全面的内存分析功能，顶部总开关控制数据采集（默认关闭以避免性能开销）。

**总开关：**
- 内存面板顶部开关控制是否启用监控
- 关闭时：停止所有定时器、清空 VM Service 连接（无 WebSocket 开销）
- 开启时：启动数据采集并尝试连接 VM Service

**内存趋势图：**
- 实时折线图，2 分钟历史窗口（240 条快照 × 500ms）
- 可切换 4 种指标：进程 RSS / Dart Heap / 新生代 / 老生代

**Dart Heap 概览（需要 VM Service）：**
- Heap Usage / Capacity / External 三个核心指标 + 进度条
- 新生代/老生代详细数据（Usage / Capacity / External）
- 手动触发 GC 按钮（VM Service 不可用时禁用）

**Native 内存（真机 100% 可用）：**
- Android：Total PSS、Dalvik PSS、Native PSS、Native Private Dirty、设备内存状态
- iOS：Physical Footprint、压缩内存、进程 RSS、设备可用内存
- 低内存警告标识

**内存泄漏检测（基于 Dart 2.17+ WeakReference）：**
- 通过 `trackObject()` API 注册对象进行泄漏追踪
- 四状态流转：tracking → verifying → leaked / released
- 超过预期释放时间自动触发 GC 验证
- UI 显示疑似泄漏（红色高亮）、追踪中、已释放的对象列表

```dart
// 简写形式（推荐）
myBloc.trackMemoryLeak(tag: 'HomePage_myBloc');

// 或使用顶层函数
trackMemoryLeak(myBloc, tag: 'HomePage_myBloc');

// 取消追踪
myBloc.untrackMemoryLeak();

// 如有需要，也可以使用完整形式
MemoryInspectorService.instance.trackObject(
  myBloc,
  tag: 'HomePage_myBloc',
  expectedReleaseAfter: Duration(seconds: 60),
);
MemoryInspectorService.instance.untrackObject(myBloc);

// 清空所有记录
MemoryInspectorService.instance.clearLeakRecords();
```

**图片缓存监控：**
- 实时显示图片缓存大小和数量
- 显示加载中（Pending）和使用中（Live）的图片数量
- 可视化的缓存使用率进度条
- 一键清理所有图片缓存

**应用存储统计：**
- 文档目录大小
- 临时缓存目录大小
- 数据库文件总大小
- 一键清理应用临时缓存

**⚠️ 重要说明：VM Service 可用性**

**通过 PC 使用 `flutter run` 调试时，Dart VM Heap 数据可能不可用（VM: OFF）。**

**原因：** 使用 `flutter run` 连接 PC 调试时，flutter tool 会通过 `adb reverse` 在 PC 和设备之间做端口转发，让 PC 上的 DevTools 能访问设备的 VM Service。但应用进程内部 `Service.getInfo()` 返回的 `serverUri` 是 PC 视角的端口，应用进程访问 `127.0.0.1:PC端口` 时设备本地并没有监听该端口，导致 Connection refused，VM Service 显示 OFF。

**不影响实际使用：** 不连接 PC 直接打开 debug 应用时（没有 flutter tool 介入），VM Service 直接监听设备本地端口，应用能正常连接，Dart Heap 数据正常显示。

**降级方案：** VM Service 不可用时，Native 内存（Android PSS / iOS physicalFootprint）仍然正常显示；进程 RSS 始终可用。仅 Dart Heap 详情和手动 GC 不可用。

### FPS 监控

FPS 监控提供实时帧性能分析，顶部总开关控制数据采集（默认关闭以避免性能开销）。

**总开关：**
- FPS 面板顶部开关控制是否启用监控
- 关闭时：不注册帧回调、无定时器、无性能开销
- 开启时：通过 `WidgetsBinding.instance.addTimingsCallback` 开始采集帧数据

**功能：**
- 当前 FPS、掉帧率、总帧数
- FPS 趋势折线图（30 秒窗口，60 个数据点）
- 掉帧列表（带帧耗时和时间戳，标记 >16ms 的掉帧）
- 重置按钮，清空所有统计

**准确度说明（v1.2.1 起）：**
- 帧时间戳使用 `timing.timestampInMicroseconds(FramePhase.buildStart)` —— 来自 Flutter 引擎的每帧真实开始时间，而非 `DateTime.now()`（后者在批量回调中会让多帧时间戳几乎相同）
- 帧耗时使用 `rasterFinish - buildStart`，**同时包含 build 和 raster（GPU）阶段** —— 能检测 GPU 光栅化卡顿，这是 Flutter 最常见的卡顿类型之一，纯 `buildDuration` 检测完全漏判

**编程式控制（可选）：**

```dart
// 以代码方式启动 / 停止 FPS 监控
FpsService.instance.start();
FpsService.instance.stop();

// 读取当前统计
final fps = FpsService.instance.currentFps;
final jankRate = FpsService.instance.jankRate;
final totalFrames = FpsService.instance.totalFrameCount;
final jankyFrames = FpsService.instance.totalJankyCount;

// 清空历史数据
FpsService.instance.clear();

// 监听数据变化
FpsService.instance.addListener(() {
  // 更新你自己的 UI
});

// 历史数据访问
final history = FpsService.instance.fpsHistory;       // List<double>，60 条
final records = FpsService.instance.frameRecords;      // List<FrameRecord>，不可修改
```

### 自定义数据库提供者

要添加对其他数据库的支持，实现 `DatabaseProvider` 接口：

```dart
class MyCustomDatabaseProvider implements DatabaseProvider {
  @override
  String get name => 'CustomDB';

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    // 返回数据库列表
    return [];
  }

  @override
  Future<QueryResult> queryTable(String dbPath, String tableName, {int limit = 50}) async {
    // 执行查询并返回结果
    return QueryResult(columns: [], rows: []);
  }
}

// 注册提供者
DatabaseRegistry.instance.registerProvider(MyCustomDatabaseProvider());
```

### 🌳 Widget 检查器与网络瀑布流（默认关闭）

两项功能默认关闭，避免在不需要时产生额外开销：

- **Widget Inspector**：在面板中开启后，会**拍一次当前组件树的快照**（构建后回调），并以**面包屑导航**方式浏览（类似文件管理器）：主列表只显示当前层；点击含子节点的项即**下钻**到下一层，顶部分层面包屑可一键跳回任意祖先层；点击叶子节点弹出底部抽屉看详情。**它不是实时的**——开启后不会自动跟随 UI 变化；如需更新，点击工具栏的「刷新」按钮（或关闭再打开开关）重新快照。
- **Network Timeline**：在 Network 面板中开启后，以时间轴瀑布图形式展示请求的发起与响应过程，便于发现并发与长阻塞。**它是实时的**——新请求到达会立即流入时间轴，无需手动刷新。

```dart
ZeroInspectorKit.runAppWithInspector(
  const MyApp(),
  enableWidgetInspector: true,    // 启动时预开启 Widget Inspector
  enableNetworkTimeline: true,    // 启动时预开启 Network Timeline
);
```

即使不预开启，也可以在运行时于面板内手动打开对应开关。

## API 参考

### FloatingInspectorButton

| 参数 | 类型 | 描述 |
|------|------|------|
| enabled | bool | 是否启用检查器（默认：true，release 模式下自动禁用） |

### ConditionalInspector

一个便利组件，根据构建模式自动显示/隐藏检查器。

```dart
ConditionalInspector(
  child: YourAppWidget(),
)
```

| 参数 | 类型 | 描述 |
|------|------|------|
| child | Widget | 子组件 |
| enabled | bool | 是否启用检查器（默认：true） |

### InspectorLogInterceptor

| 方法 | 描述 |
|------|------|
| start() | 开始捕获日志 |
| stop() | 停止捕获日志 |
| log(level, message, tag) | 添加日志条目 |
| verbose(message, tag) | 添加详细日志 |
| debug(message, tag) | 添加调试日志 |
| info(message, tag) | 添加信息日志 |
| warning(message, tag) | 添加警告日志 |
| error(message, tag) | 添加错误日志 |

| 属性 | 类型 | 描述 |
|------|------|------|
| onLogCaptured | `void Function(LogEntry)?` | 日志捕获回调，用于第三方日志库集成 |

### InspectorLog

`InspectorLogInterceptor.instance` 的简写包装类，用于更短的手动日志调用。

| 方法 | 描述 |
|------|------|
| start() | 开始捕获日志 |
| stop() | 停止捕获日志 |
| log(level, message, {tag}) | 添加日志条目 |
| v(message, {tag}) | 添加详细日志 |
| d(message, {tag}) | 添加调试日志 |
| i(message, {tag}) | 添加信息日志 |
| w(message, {tag}) | 添加警告日志 |
| e(message, {tag}) | 添加错误日志 |

| 属性 | 类型 | 描述 |
|------|------|------|
| isRunning | bool | 当前是否正在捕获日志 |

### InspectorRouteObserver

用于追踪路由变化的 Navigator observer。

### FpsService

FPS 监控单例服务，继承自 `ChangeNotifier`。

| 方法 | 描述 |
|------|------|
| start() | 启动 FPS 监控 |
| stop() | 停止 FPS 监控 |
| clear() | 清空所有历史数据和计数 |

| 属性 | 类型 | 描述 |
|------|------|------|
| isRunning | bool | 当前是否正在监控 |
| currentFps | double | 当前 FPS（每 500ms 更新） |
| jankRate | double | 掉帧率（百分比） |
| totalFrameCount | int | 累计总帧数 |
| totalJankyCount | int | 累计掉帧数（>16ms） |
| lastFrameJanky | bool | 最近一帧是否掉帧 |
| fpsHistory | `List<double>` | 最近 60 个 FPS 历史值（不可修改） |
| frameRecords | `List<FrameRecord>` | 最近帧记录（不可修改，最多 3600 条） |

### runInspectorApp

一个辅助函数，使用检查器 Zone 运行应用，启用自动 print() 捕获。

```dart
runInspectorApp(VoidCallback appRunner)
```

| 参数 | 类型 | 描述 |
|------|------|------|
| appRunner | VoidCallback | 运行应用的函数（通常是 `runApp`） |

## 贡献

欢迎贡献代码！提交 issue 或 pull request 前,请先阅读[贡献指南](CONTRIBUTING.md)。

- 🐛 [报告 Bug](https://github.com/zero-labsco/zero_inspector_kit/issues/new?template=bug_report.md)
- 💡 [功能建议](https://github.com/zero-labsco/zero_inspector_kit/issues/new?template=feature_request.md)
- 💬 [参与讨论](https://github.com/zero-labsco/zero_inspector_kit/discussions)
- 📖 [贡献指南](CONTRIBUTING.md)

## 许可证

本项目采用 GNU General Public License v3.0 许可证 - 详见 [LICENSE](LICENSE) 文件。
