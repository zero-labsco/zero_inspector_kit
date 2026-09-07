# Configuration / 配置说明

## ZeroInspectorKit.init() Parameters / 初始化参数

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enable` | bool | `true` | Enable inspector (auto `false` in release mode) / 启用检查器 |
| `enableLogCapture` | bool | `true` | Enable log capture / 启用日志捕获 |
| `enableNetworkCapture` | bool | `true` | Enable network interception / 启用网络拦截 |
| `enableErrorCapture` | bool | `true` | Enable error aggregation (Errors tab) / 启用异常聚合（Errors 标签页） |
| `enablePersistence` | bool | `true` | Persist logs/network/errors to a SQLite ring buffer; logs & errors replay on launch / 将日志/网络/异常落盘到 SQLite 环形缓冲，启动时回放日志与异常 |
| `enableFlutterLeakTracker` | bool | `true` | Bridge Flutter's official `MemoryAllocations` as a second leak-detection source / 桥接 Flutter 官方 `MemoryAllocations` 作为泄漏检测第二来源 |
| `enableDatabaseScan` | bool | `true` | Enable database scan / 启用数据库扫描 |
| `enableRouteTracking` | bool | `true` | Enable route tracking / 启用路由追踪 |
| `enableWidgetInspector` | bool | `true` | Enable Widget tree snapshot / 启用 Widget 树快照 |
| `enableNetworkTimeline` | bool | `true` | Prefer the network timeline (waterfall) in request details / 网络详情页默认展示时间轴（瀑布图） |
| `customButton` | Widget? | `null` | Custom floating button widget / 自定义悬浮按钮 |
| `onLogCaptured` | `void Function(LogEntry)?` | `null` | Log capture callback for third-party integration / 日志捕获回调 |
| `maxNetworkItems` | int? | `100` | Network request cache cap / 网络请求缓存上限 |
| `maxLogItems` | int? | `500` | Log entry cache cap / 日志条目缓存上限 |
| `maxRouteItems` | int? | `200` | Route record cache cap / 路由记录缓存上限 |
| `maxBodyPreviewBytes` | int? | `32KB` | Body preview cap, longer bodies truncated / body 预览字节上限，超出截断 |

> `enableWidgetInspector` / `enableNetworkTimeline` are also exposed on `runAppWithInspector()`. (`wrapApp()` takes only `enable`.)
>
> `enableWidgetInspector` / `enableNetworkTimeline` 也可在 `runAppWithInspector()` 上设置（`wrapApp()` 仅接受 `enable`）。

## Usage Examples / 使用示例

### Disable Specific Features / 禁用特定功能

```dart
ZeroInspectorKit.init(
  enableLogCapture: true,
  enableNetworkCapture: false,  // Disable network monitoring / 禁用网络监控
  enableDatabaseScan: true,
  enableRouteTracking: false,   // Disable route tracking / 禁用路由追踪
);
```

### With Log Callback / 带日志回调

```dart
ZeroInspectorKit.init(
  onLogCaptured: (entry) {
    // Forward to your logging service / 转发到你的日志服务
    myLogger.log(entry.message);
  },
);
```

## ConditionalInspector / 条件检查器组件

A convenience widget that automatically shows/hides the inspector based on build mode.

根据构建模式自动显示/隐藏检查器的便利组件。

```dart
ConditionalInspector(
  child: YourAppWidget(),
)
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `child` | Widget | required | Child widget / 子组件 |
| `enabled` | bool | `true` | Enable inspector / 启用检查器 |

## FloatingInspectorButton / 悬浮检查器按钮

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enabled` | bool | `true` | Enable button (auto `false` in release mode) / 启用按钮 |

## InspectorLogInterceptor / 日志拦截器

| Method | Description |
|--------|-------------|
| `start()` | Start capturing logs / 开始捕获日志 |
| `stop()` | Stop capturing logs / 停止捕获日志 |
| `log(level, message, tag)` | Add a log entry / 添加日志条目 |
| `verbose(message, tag)` | Add verbose log / 添加详细日志 |
| `debug(message, tag)` | Add debug log / 添加调试日志 |
| `info(message, tag)` | Add info log / 添加信息日志 |
| `warning(message, tag)` | Add warning log / 添加警告日志 |
| `error(message, tag)` | Add error log / 添加错误日志 |

| Property | Type | Description |
|----------|------|-------------|
| `onLogCaptured` | `void Function(LogEntry)?` | Callback when a log is captured / 日志捕获回调 |

## InspectorRouteObserver / 路由观察者

Navigator observer for tracking route changes. Auto-injected when using `runAppWithInspector()` or `wrapApp()`.

用于追踪路由变化的 Navigator 观察者。使用 `runAppWithInspector()` 或 `wrapApp()` 时自动注入。

```dart
MaterialApp(
  navigatorObservers: [InspectorRouteObserver()],
  home: MyHomePage(),
)
```

## DatabaseRegistry / 数据库注册表

Register custom database providers:

注册自定义数据库提供者：

```dart
DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
```

See [Custom Database Provider](Custom-Database-Provider) for more details.

详见 [自定义数据库提供者](Custom-Database-Provider)。

## InspectorLog / 简化日志 API

> Available since v1.1.2 / v1.1.2 起可用

A static wrapper around `InspectorLogInterceptor.instance` for shorter log calls.

`InspectorLogInterceptor.instance` 的静态包装，用于更简短的日志调用。

```dart
InspectorLog.v('Verbose log');
InspectorLog.d('Debug log');
InspectorLog.i('Info log', tag: 'Auth');
InspectorLog.w('Warning log');
InspectorLog.e('Error log');
```

| Method | Description |
|--------|-------------|
| `start()` | Start capturing logs / 开始捕获日志 |
| `stop()` | Stop capturing logs / 停止捕获日志 |
| `log(level, message, {tag})` | Add a log entry / 添加日志条目 |
| `v(message, {tag})` | Add verbose log / 添加详细日志 |
| `d(message, {tag})` | Add debug log / 添加调试日志 |
| `i(message, {tag})` | Add info log / 添加信息日志 |
| `w(message, {tag})` | Add warning log / 添加警告日志 |
| `e(message, {tag})` | Add error log / 添加错误日志 |

| Property | Type | Description |
|----------|------|-------------|
| `isRunning` | bool | Whether log capture is currently active / 日志捕获是否正在运行 |

## MemoryInspectorService / 内存监控服务

> Available since v1.1.0 / v1.1.0 起可用

Singleton service for memory monitoring and leak detection, extends `ChangeNotifier`.

内存监控与泄漏检测单例服务，继承 `ChangeNotifier`。

### Full API / 完整接口

```dart
// Leak tracking (full form) / 泄漏追踪（完整写法）
MemoryInspectorService.instance.trackObject(
  myController,
  tag: 'HomeController_textController',
  expectedReleaseAfter: const Duration(seconds: 30),
);
MemoryInspectorService.instance.untrackObject(myController);
MemoryInspectorService.instance.clearLeakRecords();
```

### Simplified API / 简化接口

> Available since v1.1.2 / v1.1.2 起可用

```dart
// Extension method on Object / Object 上的扩展方法
myBloc.trackMemoryLeak(tag: 'HomePage_myBloc');

// Top-level function / 顶层函数
trackMemoryLeak(myBloc, tag: 'HomePage_myBloc');

// Cancel tracking / 取消追踪
myBloc.untrackMemoryLeak();
```

See [Memory Viewer](Memory-Viewer) for full feature details.

完整功能详情见 [Memory Viewer](Memory-Viewer)。

### Flutter MemoryAllocations Bridge / 官方泄漏追踪桥接

> Available since v1.9.0 / v1.9.0 起可用

The leak detector's own `WeakReference` state machine has a blind spot: an object whose `dispose()` ran but which has not been GC'd yet still resolves through the weak reference and is flagged as a suspected leak (false positive). `LeakTrackerBridge` subscribes to Flutter's official `FlutterMemoryAllocations` (the data source behind `leak_tracker`) as a **second source**: once the official stream reports `disposed`, the object is treated as released (awaiting GC) even if the weak reference still resolves — cutting false positives.

自研泄漏检测的 `WeakReference` 状态机有一个盲点：对象已调用 `dispose()` 但尚未被 GC 时，弱引用仍存活，会被判定为"疑似泄漏"（误报）。`LeakTrackerBridge` 订阅 Flutter 官方的 `FlutterMemoryAllocations`（`leak_tracker` 背后的数据源）作为**第二来源**：只要官方上报了 `disposed`，即便弱引用仍存活也判定为已释放（等待 GC），从而显著降低误报。

- Enabled by default via `ZeroInspectorKit.init()`'s `enableFlutterLeakTracker` / 通过 `init()` 的 `enableFlutterLeakTracker` 默认启用
- Official events only cover framework types that report to `FlutterMemoryAllocations` (Image / Picture / Layer …) — it **supplements**, not replaces, the custom detector / 官方事件只覆盖会上报给 `FlutterMemoryAllocations` 的框架类型（如 Image / Picture / Layer），因此是**补充**而非替代自研方案

## ErrorService / 异常聚合服务

> Available since v1.9.0 / v1.9.0 起可用

Singleton service for aggregated error capture, extends `ChangeNotifier`. Hooks `FlutterError.onError` (keeping the default red error behavior) and dedups each exception by type + stack signature. See [Errors](Errors) for full feature details.

异常聚合单例服务，继承 `ChangeNotifier`。接管 `FlutterError.onError`（保留默认红色报错行为），按类型 + 堆栈签名去重聚合。完整功能见 [Errors](Errors)。

```dart
// Report an exception manually (gRPC / custom protocols) / 手动上报异常
ErrorService.instance.report(error, stackTrace, 'myModule');

// Read aggregated records (newest first) / 读取聚合记录（最新在前）
final ErrorRecord r = ErrorService.instance.errors.first;

// Toggle capture / 切换抓取开关
ErrorService.instance.isEnabled = false;

// Clear all records / 清空全部记录
ErrorService.instance.clear();
```

| Member | Description |
|--------|-------------|
| `errors` | `List<ErrorRecord>` — aggregated records, newest first / 聚合记录，最新在前 |
| `errorCount` | `int` — aggregated record count / 聚合记录条数 |
| `isEnabled` | `bool` — capture toggle (programmatic) / 抓取开关（代码控制） |
| `report(exception, stack, [context])` | Manually report an exception / 手动上报异常 |
| `restore(records)` | Restore persisted records (replay on launch) / 恢复持久化记录（启动回放） |
| `clear()` | Clear all aggregated records / 清空所有聚合记录 |
| `install()` / `uninstall()` | Hook / restore `FlutterError.onError` / 接管 / 还原 `FlutterError.onError` |

## PersistenceService / 持久化服务

> Available since v1.9.0 / v1.9.0 起可用

Singleton service that async-flushes logs, network requests, and aggregated errors to a local SQLite **ring buffer** (`zero_inspector_kit.db`) so data survives app restarts. On launch, **logs and aggregated errors replay into their tabs**; network requests stay archived on disk for later export. Everything is guarded and degrades gracefully: if the DB is unavailable (e.g. desktop without sqflite FFI) `isEnabled` is `false` and writes become no-ops, never affecting the host app.

单例服务，将日志、网络请求与聚合异常异步落盘到本地 SQLite **环形缓冲**（`zero_inspector_kit.db`），使数据跨重启不丢。启动时**日志与聚合异常回放入各自标签页**；网络请求保留在磁盘存档，供之后导出。所有操作都有保护并优雅降级：数据库不可用（如桌面端未配置 sqflite FFI）时 `isEnabled` 为 `false`，写入变为空操作，绝不影响宿主应用。

### Tuning / 调参

```dart
await PersistenceService.instance.init(
  maxRowsPerTable: 5000,                      // rows kept per table / 每表保留行数
  retention: const Duration(days: 7),         // retention window / 保留时长
  flushInterval: const Duration(seconds: 2),  // disk flush interval / 刷盘间隔
);
```

> Enabled by default via `ZeroInspectorKit.init()`'s `enablePersistence` — the ring buffer flushes automatically, so no manual `init()` call is needed in normal use.
>
> 通过 `init()` 的 `enablePersistence` 默认启用——环形缓冲会自动刷盘，常规使用无需手动调用 `init()`。

| Member | Description |
|--------|-------------|
| `isEnabled` | `bool` — whether the DB is available / 数据库是否可用 |
| `maxRowsPerTable` | `int` — row cap per table (ring-buffer trim line) / 每表行数上限 |
| `enqueueLog(e)` / `enqueueNetwork(r)` / `enqueueError(e)` | Enqueue an item for async flush / 入队待异步落盘 |
| `flush()` | Flush the buffer to disk and trim / 刷盘并按环形缓冲裁剪 |
| `loadLogs()` / `loadErrors()` / `loadNetworkJson()` | Load persisted data, newest first / 读取已持久化数据（最新在前） |
| `buildSessionArchiveJson()` | Build the full-session archive JSON (logs + errors + network) / 构建完整会话存档 JSON |
| `exportSessionArchiveAndShare()` | Export & share the full-session archive via the system share sheet / 导出并分享完整会话存档 |
| `clearAll()` | Clear persisted data on disk / 清空磁盘上的持久化数据 |
| `dispose()` | Flush then close / 先刷盘再关闭 |

### Persisted Data Manager / 持久化数据管理

Tap the **storage icon** in the panel header to open the **Persisted data** sheet: it shows the current row counts per category (`logs / network / errors`), the per-table cap, and whether the data will be replayed on the next launch. Actions:

点击面板头部的**存储图标**打开 **Persisted data** 管理弹层：展示各类别当前行数（`logs / network / errors`）、每表上限，以及下次启动是否会回放。支持的操作：

- **Export & share session archive** — share a JSON snapshot of the whole session / **导出并分享会话存档**——分享本次会话完整 JSON 快照
- **Clear disk** — wipe persisted rows so the next launch replays nothing / **清空磁盘**——清空持久化数据，下次启动干净
- **Clear disk & lists** — wipe disk and the in-memory lists together / **同时清空磁盘与列表**——连同内存列表一并清空

## FpsService / FPS 监控服务

> Available since v1.2.0 / v1.2.0 起可用

Singleton service for FPS monitoring, extends `ChangeNotifier`.

FPS 监控单例服务，继承 `ChangeNotifier`。

```dart
FpsService.instance.start();
FpsService.instance.stop();
FpsService.instance.clear();

final fps = FpsService.instance.currentFps;
final jankRate = FpsService.instance.jankRate;
```

| Method | Description |
|--------|-------------|
| `start()` | Start FPS monitoring / 开始 FPS 监控 |
| `stop()` | Stop FPS monitoring / 停止 FPS 监控 |
| `clear()` | Clear all historical data and counters / 清空所有历史数据和计数器 |

| Property | Type | Description |
|----------|------|-------------|
| `isRunning` | bool | Whether monitoring is currently active / 是否正在监控 |
| `currentFps` | double | Current FPS (updated every 500ms) / 当前 FPS（每 500ms 更新） |
| `jankRate` | double | Jank rate as percentage / 卡顿率（百分比） |
| `totalFrameCount` | int | Total frames captured / 总帧数 |
| `totalJankyCount` | int | Total janky frames (>16ms) / 总卡顿帧数（>16ms） |
| `lastFrameJanky` | bool | Whether the most recent frame was janky / 最近一帧是否卡顿 |
| `fpsHistory` | `List<double>` | Recent 60 FPS values (unmodifiable) / 最近 60 个 FPS 值（不可变） |
| `frameRecords` | `List<FrameRecord>` | Recent frame records (unmodifiable, up to 3600) / 最近帧记录（不可变，最多 3600 条） |

See [FPS Viewer](FPS-Viewer) for full feature details.

完整功能详情见 [FPS Viewer](FPS-Viewer)。
