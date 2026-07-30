# FPS Viewer / FPS 监控面板

The FPS Viewer provides real-time frame performance analysis, including current FPS, jank rate, frame duration stats, and an FPS trend chart.

FPS 监控面板提供实时帧性能分析，包括当前 FPS、卡顿率、帧耗时统计和 FPS 趋势图。

> **Available since v1.2.0**
>
> **v1.2.0 起可用**

## Overview / 概览

The FPS Viewer is integrated into the inspector panel. Tap the floating inspector button → "FPS" tab to access.

FPS 监控面板集成在检查器面板中。点击悬浮检查器按钮 → "FPS" 标签即可访问。

**⚠️ Important**: FPS monitoring is **off by default**. You must toggle on the switch at the top of the panel to start collecting data.

**⚠️ 重要**：FPS 监控**默认关闭**。必须在面板顶部打开开关才会开始采集数据。

## Master Switch / 总开关

A switch at the top of the FPS panel controls whether monitoring is enabled.

FPS 面板顶部有一个开关，控制是否启用监控。

| State | Behavior |
|-------|----------|
| **OFF (default)** | No frame timings callbacks, no timer, zero overhead / 无帧回调、无定时器、零开销 |
| **ON** | Starts collecting frame data via `WidgetsBinding.instance.addTimingsCallback` / 通过 `addTimingsCallback` 开始采集帧数据 |

When turned off, all callbacks and timers are cancelled, leaving no residual overhead.

关闭时所有回调和定时器会被取消，不会残留开销。

## Features / 功能

### 1. Current Stats / 当前统计

- **Current FPS** — Updated every 500ms / 每 500ms 更新
- **Jank Rate** — Percentage of janky frames (>16ms) / 卡顿帧占比（>16ms 视为卡顿）
- **Total Frame Count** — All frames captured since start / 自启动以来的总帧数
- **Total Janky Count** — All janky frames captured / 自启动以来的总卡顿帧数
- **Last Frame Janky** — Whether the most recent frame was janky / 最近一帧是否卡顿

显示当前 FPS、卡顿率、总帧数、总卡顿帧数、最近一帧是否卡顿。

### 2. FPS Trend Chart / FPS 趋势图

- Real-time line chart with 30-second history window (60 data points × 500ms)
- Y-axis dynamically scales to `max(60, maxFps)` to avoid overflow when FPS spikes
- Janky frame region marked in red
- Time axis labels: `-30s` / `-15s` / `Now`

实时折线图，30 秒历史窗口（60 个数据点 × 500ms）。Y 轴动态缩放为 `max(60, maxFps)` 避免 FPS 飙升时溢出。卡顿区域以红色标记。

### 3. Janky Frame List / 卡顿帧列表

- Lists frames exceeding 16ms duration / 列出耗时超过 16ms 的帧
- Each item shows frame duration and timestamp / 每项显示帧耗时和时间戳
- Helps identify specific jank spikes / 帮助定位具体卡顿点

列出耗时超过 16ms 的帧，每项显示帧耗时和时间戳，帮助定位具体卡顿点。

### 4. Reset / 重置

- "Reset" button clears all statistics and historical data / "Reset" 按钮清空所有统计和历史数据
- Useful for measuring a specific interaction scenario / 适合测量特定交互场景

"Reset" 按钮清空所有统计和历史数据，适合测量特定交互场景。

## How It Works / 工作原理

FPS monitoring uses Flutter's `WidgetsBinding.instance.addTimingsCallback` to receive frame timing information from the engine. The callback is **batched** — it may return multiple `FrameTiming` objects per call, so each frame is recorded individually inside the loop to ensure accurate FPS calculation.

FPS 监控使用 Flutter 的 `WidgetsBinding.instance.addTimingsCallback` 接收引擎的帧时序信息。该回调是**批量**的——每次调用可能返回多个 `FrameTiming` 对象，因此在循环内部为每帧单独记录时间戳，确保 FPS 计算准确。

**Jank threshold / 卡顿阈值**: A frame is considered janky if its duration exceeds 16ms (the 60 FPS budget of ~16.67ms per frame).

**卡顿阈值**：帧耗时超过 16ms（60 FPS 每帧预算约 16.67ms）即视为卡顿。

## Programmatic Control (Optional) / 编程式控制（可选）

If you need to start/stop monitoring from code (e.g., for automated testing), use `FpsService`:

如需从代码控制监控（如自动化测试），使用 `FpsService`：

```dart
// Start / Stop FPS monitoring / 开始 / 停止 FPS 监控
FpsService.instance.start();
FpsService.instance.stop();

// Read current stats / 读取当前统计
final fps = FpsService.instance.currentFps;
final jankRate = FpsService.instance.jankRate;
final totalFrames = FpsService.instance.totalFrameCount;
final jankyFrames = FpsService.instance.totalJankyCount;

// Clear historical data / 清空历史数据
FpsService.instance.clear();

// Listen to updates / 监听更新
FpsService.instance.addListener(() {
  // Update your own UI / 更新你自己的 UI
});

// Historical data access / 历史数据访问
final history = FpsService.instance.fpsHistory;       // List<double>, 60 entries / 60 条
final records = FpsService.instance.frameRecords;      // List<FrameRecord>, unmodifiable / 不可变，最多 3600 条
```

## FpsService API / FpsService 接口

Singleton service extending `ChangeNotifier`.

继承 `ChangeNotifier` 的单例服务。

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
| `totalJankyCount` | int | Total janky frames captured (>16ms) / 总卡顿帧数（>16ms） |
| `lastFrameJanky` | bool | Whether the most recent frame was janky / 最近一帧是否卡顿 |
| `fpsHistory` | `List<double>` | Recent 60 FPS values (unmodifiable) / 最近 60 个 FPS 值（不可变） |
| `frameRecords` | `List<FrameRecord>` | Recent frame records (unmodifiable, up to 3600) / 最近帧记录（不可变，最多 3600 条） |

## Performance Considerations / 性能说明

- **Off by default / 默认关闭**: Zero overhead when disabled / 关闭时零开销
- **Lightweight callbacks / 轻量回调**: Only processes frame timing data, no heavy computation / 仅处理帧时序数据，无重计算
- **Bounded history / 有界历史**: Trend chart keeps only 60 points, frame records capped at 3600 / 趋势图仅保留 60 个点，帧记录上限 3600 条
- **Safe with other features / 与其他功能兼容**: Can run alongside Memory Viewer monitoring / 可与 Memory Viewer 监控同时运行

## Platform Support / 平台支持

| Feature | Android | iOS | Desktop |
|---------|---------|-----|---------|
| FPS Monitoring | ✅ | ✅ | ✅ |
| Jank Detection | ✅ | ✅ | ✅ |
| Trend Chart | ✅ | ✅ | ✅ |

> FPS monitoring uses Flutter engine APIs and works on all platforms supported by Flutter.
>
> FPS 监控使用 Flutter 引擎 API，在 Flutter 支持的所有平台上均可用。

## Demo / 演示

The Example App includes an FPS demo module with three scenarios:

Example App 包含 FPS 演示模块，提供三种场景：

| Demo | Description |
|------|-------------|
| **Trigger Jank** | Blocks the main thread for 100-500ms to simulate jank / 阻塞主线程 100-500ms 模拟卡顿 |
| **Heavy Animations** | 80 simultaneously rotating+scaling widgets to intentionally trigger jank / 80 个同时旋转+缩放的 widget 故意触发卡顿 |
| **Smooth Animation** | Single lightweight compound animation, demonstrates stable 60 FPS / 单个轻量复合动画，演示稳定 60 FPS |

## Related / 相关

- [Usage](Usage) — General usage guide / 通用使用指南
- [FAQ](FAQ) — Common questions / 常见问题
- [Configuration](Configuration) — Configuration options / 配置选项
