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
