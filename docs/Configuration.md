# Configuration / 配置说明

## ZeroInspectorKit.init() Parameters / 初始化参数

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `enable` | bool | `true` | Enable inspector (auto `false` in release mode) / 启用检查器 |
| `enableLogCapture` | bool | `true` | Enable log capture / 启用日志捕获 |
| `enableNetworkCapture` | bool | `true` | Enable network interception / 启用网络拦截 |
| `enableDatabaseScan` | bool | `true` | Enable database scan / 启用数据库扫描 |
| `enableRouteTracking` | bool | `true` | Enable route tracking / 启用路由追踪 |
| `customButton` | Widget? | `null` | Custom floating button widget / 自定义悬浮按钮 |
| `onLogCaptured` | `void Function(LogEntry)?` | `null` | Log capture callback for third-party integration / 日志捕获回调 |

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
