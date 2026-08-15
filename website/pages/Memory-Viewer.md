# Memory Viewer / 内存监控面板

The Memory Viewer provides comprehensive in-app memory analysis, including trend charts, Dart Heap details, Native memory breakdown, memory leak detection, image cache monitoring, and storage statistics.

内存监控面板提供应用内全面内存分析，包括趋势图、Dart Heap 详情、Native 内存分项、内存泄漏检测、图片缓存监控和存储统计。

> **Available since v1.1.0**
>
> **v1.1.1 起可用**

## Overview / 概览

The Memory Viewer is integrated into the inspector panel. Tap the floating inspector button → "Memory" tab to access.

内存监控面板集成在检查器面板中。点击悬浮检查器按钮 → "Memory" 标签即可访问。

**⚠️ Important**: Memory monitoring is **off by default**. You must toggle on the switch at the top of the panel to start collecting data.

**⚠️ 重要**：内存监控**默认关闭**。必须在面板顶部打开开关才会开始采集数据。

## Master Switch / 总开关

A switch at the top of the Memory panel controls whether monitoring is enabled.

Memory 面板顶部有一个开关，控制是否启用监控。

| State | Behavior |
|-------|----------|
| **OFF (default)** | No timers, no VM Service connection, zero overhead / 无定时器、无 VM Service 连接、零开销 |
| **ON** | Starts RSS collection (500ms), Native memory (3s), storage stats (3s), leak detection (2s), and VM Service connection attempt / 启动 RSS 采集（500ms）、Native 内存（3s）、存储统计（3s）、泄漏检测（2s），并尝试连接 VM Service |

When turned off, all timers are cancelled and the VM Service connection state is cleared, leaving no residual WebSocket overhead.

关闭时所有定时器会被取消，VM Service 连接状态会被清空，不会残留 WebSocket 开销。

## Features / 功能

### 1. Memory Trend Chart / 内存趋势图

- Real-time line chart with 2-minute history window (240 snapshots × 500ms)
- Switchable between 4 metrics via the metric selector chips:
  - **Process RSS** — Process-level RSS (always available)
  - **Dart Heap** — Total Dart Heap usage (requires VM Service)
  - **New Space** — New generation usage (requires VM Service)
  - **Old Space** — Old generation usage (requires VM Service)

实时折线图，2 分钟历史窗口（240 条快照 × 500ms）。可通过指标选择芯片切换 4 种指标。

### 2. Native Memory / Native 内存（真机 100% 可用）

Does not depend on VM Service. Data is collected via Platform Channel:

不依赖 VM Service，通过 Platform Channel 采集：

**Android** (`Debug.MemoryInfo` + `/proc/self/status`):
- Total PSS / Dalvik PSS / Native PSS / Native Private Dirty
- Process RSS (from `/proc/self/status`)
- Device memory status (availMem, threshold, lowMemory)

**iOS** (`mach task_info`):
- Physical Footprint (Apple's recommended metric)
- Internal / Compressed / Resident Size
- Process RSS
- Device available memory

### 3. Dart Heap Overview / Dart Heap 概览（需要 VM Service）

- Heap Usage / Capacity / external usage
- Progress bar showing heap usage ratio
- Three core metrics with bilingual labels

显示 Heap Usage / Capacity / External 三个核心指标 + 进度条。

### 4. Heap Generations / 堆分代详情（需要 VM Service）

- **New Space**: usage / capacity / external
- **Old Space**: usage / capacity / external
- Helps identify allocation patterns (frequent new-space churn vs old-space growth)

显示新生代/老生代的 Usage / Capacity / External 详细数据。

### 5. Manual GC / 手动触发 GC（需要 VM Service）

- "Trigger GC" button forces a full garbage collection
- Disabled (grayed out) when VM Service is unavailable

"Trigger GC" 按钮强制触发完整垃圾回收。VM Service 不可用时按钮变灰禁用。

### 6. Memory Leak Detection / 内存泄漏检测

Based on Dart 2.17+ `WeakReference` and `Finalizer`. Does NOT depend on VM Service.

基于 Dart 2.17+ 的 `WeakReference` 和 `Finalizer`，不依赖 VM Service。

**Four-state transition / 四状态流转**:

| State | Meaning |
|-------|---------|
| `tracking` | Object registered, waiting for expected release time / 对象已注册，等待预期释放时间 |
| `verifying` | Exceeded expected release time, GC verification triggered (if VM Service available) / 超过预期释放时间，触发 GC 验证（VM Service 可用时） |
| `leaked` | Object still exists after GC — **suspected leak** / GC 后对象仍存在——**疑似泄漏** |
| `released` | Object has been garbage collected / 对象已被垃圾回收 |

**API / 接口**:

**Quick shorthand (recommended) / 简化写法（推荐）** — available since v1.1.2 / v1.1.2 起可用:

```dart
// Extension method on Object / Object 上的扩展方法
myBloc.trackMemoryLeak(tag: 'HomePage_myBloc');

// Or top-level function / 或使用顶层函数
trackMemoryLeak(myBloc, tag: 'HomePage_myBloc');

// Cancel tracking / 取消追踪
myBloc.untrackMemoryLeak();
```

**Full form / 完整写法**:

```dart
// Register an object for leak tracking / 注册对象进行泄漏追踪
MemoryInspectorService.instance.trackObject(
  myController,
  tag: 'HomeController_textController',  // optional identifier
  expectedReleaseAfter: const Duration(seconds: 30),  // expected release time
);

// Stop tracking a specific object / 停止追踪特定对象
MemoryInspectorService.instance.untrackObject(myController);

// Clear all records / 清空所有记录
MemoryInspectorService.instance.clearLeakRecords();
```

**Limits / 限制**:
- Max 500 tracked objects (LRU eviction)
- Detection interval: 2 seconds
- `trackObject()` requires user code modification (mild invasion)

### 7. Image Cache / 图片缓存

- Real-time Flutter image cache size and count
- Pending (loading) / Live (in use) image counts
- One-click clear all image cache

实时显示 Flutter 图片缓存大小、数量、加载中/使用中状态。一键清理图片缓存。

### 8. App Storage / 应用存储

- Documents directory size
- Temp cache directory size
- Total database file size
- One-click clear temp cache

显示文档目录、临时缓存、数据库文件大小。一键清理临时缓存。

## ⚠️ VM Service Availability / VM Service 可用性

**Dart Heap data and manual GC require VM Service connection.** When VM Service is unavailable, these features gracefully degrade to show "N/A".

**Dart Heap 数据和手动 GC 需要 VM Service 连接。** VM Service 不可用时，这些功能优雅降级显示 "N/A"。

### When debugging via PC with `flutter run` / 通过 PC 用 `flutter run` 调试时

**Dart VM Heap data may be unavailable (VM: OFF).**

**Dart VM Heap 数据可能不可用（VM: OFF）。**

**Reason / 原因**: When using `flutter run` to debug via PC, the flutter tool sets up port forwarding between PC and device via `adb reverse`, allowing PC-side DevTools to access the device's VM Service. However, `Service.getInfo()` returns a `serverUri` from the PC's perspective; when the app process internally accesses `127.0.0.1:PC_port`, the device doesn't have that port listening locally, resulting in `Connection refused` and VM Service showing OFF.

**原因**：使用 `flutter run` 连接 PC 调试时，flutter tool 会通过 `adb reverse` 在 PC 和设备之间做端口转发，让 PC 上的 DevTools 能访问设备的 VM Service。但应用进程内部 `Service.getInfo()` 返回的 `serverUri` 是 PC 视角的端口，应用进程访问 `127.0.0.1:PC端口` 时设备本地并没有监听该端口，导致 Connection refused，VM Service 显示 OFF。

### When opening debug app directly (no PC) / 直接打开 debug 应用（不连 PC）

**VM Service works normally.** No flutter tool is involved, VM Service listens directly on the device's local port, the app can connect normally, and Dart Heap data displays correctly.

**VM Service 正常工作。** 没有 flutter tool 介入，VM Service 直接监听设备本地端口，应用能正常连接，Dart Heap 数据正常显示。

### Fallback / 降级方案

When VM Service is unavailable:
- ✅ Native memory (Android PSS / iOS physicalFootprint) — still available
- ✅ Process RSS — always available
- ✅ Image cache / storage stats — still available
- ✅ Leak detection — still available (doesn't depend on VM Service)
- ❌ Dart Heap details — shows N/A
- ❌ Manual GC — button disabled

## Platform Support / 平台支持

| Feature | Android | iOS |
|---------|---------|-----|
| Process RSS | ✅ | ✅ |
| Native Memory | ✅ | ✅ |
| Dart Heap (VM Service) | ✅ (no PC) | ✅ (no PC) |
| Manual GC | ✅ (no PC) | ✅ (no PC) |
| Leak Detection | ✅ | ✅ |
| Image Cache | ✅ | ✅ |
| Storage Stats | ✅ | ✅ |

## Refresh Intervals / 刷新间隔

| Data Source | Interval |
|-------------|----------|
| Process RSS / Dart Heap | 500ms |
| Native Memory (Android/iOS) | 3000ms |
| Storage Stats | 3000ms |
| Leak Detection | 2000ms |

## Related / 相关

- [Usage](Usage) — General usage guide
- [FAQ](FAQ) — Common questions
- [Configuration](Configuration) — Configuration options
