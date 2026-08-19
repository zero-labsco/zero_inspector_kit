# FAQ / 常见问题

## General / 通用

### Q: Does the inspector affect production builds? / 检查器会影响生产构建吗？

**A:** No. The inspector is automatically disabled in release mode via `kReleaseMode`. Flutter's tree-shaking removes all inspector-related code from production builds. You don't need to remove any code.

**不会。** 检查器在 release 模式下通过 `kReleaseMode` 自动禁用。Flutter 的 tree-shaking 会移除所有检查器相关代码，无需手动移除。

---

### Q: What platforms are supported? / 支持哪些平台？

**A:** Android and iOS.

支持 Android 和 iOS。

---

### Q: What Flutter/Dart versions are required? / 需要什么 Flutter/Dart 版本？

**A:** Flutter >= 3.3.0, Dart SDK >= 3.11.0 < 4.0.0.

Flutter >= 3.3.0，Dart SDK >= 3.11.0 < 4.0.0。

---

## Network / 网络

### Q: Do I need to manually add interceptors for Dio? / 需要为 Dio 手动添加拦截器吗？

**A:** No. Dio uses `IOHttpClientAdapter` internally, which uses `dart:io`'s `HttpClient`. The inspector captures all requests via `HttpOverrides` automatically, making it truly zero-invasion for both http package and Dio.

**不需要。** Dio 内部使用 `IOHttpClientAdapter`，底层使用 `dart:io` 的 `HttpClient`。检查器通过 `HttpOverrides` 自动捕获所有请求，对 http 包和 Dio 都是真正的零侵入。

---

### Q: Why do I see duplicate Dio requests? / 为什么看到重复的 Dio 请求？

**A:** If you use both `InspectorDioInterceptor` and the auto-capture (HttpOverrides), Dio requests will be recorded twice. Simply remove the manual `InspectorDioInterceptor` — auto-capture handles everything.

如果同时使用了 `InspectorDioInterceptor` 和自动捕获（HttpOverrides），Dio 请求会被记录两次。移除手动 `InspectorDioInterceptor` 即可，自动捕获会处理一切。

---

### Q: Can I modify requests during testing? / 测试时可以修改请求吗？

**A:** Yes (since v1.0.7). The inspector supports intercepting and modifying requests via rules. Open a request detail and tap the Interceptor icon to configure a rule. You can modify the **request body** and **request headers** only — response fields (status code, response body) are read-only (since v1.0.8). GET requests cannot be modified (no request body). The master toggle is on the Network list page; rules only apply when modification mode is enabled.

**可以**（v1.0.7 起）。检查器支持通过规则拦截并修改请求。打开请求详情，点击拦截器图标配置规则。仅可修改**请求体**和**请求头**——响应字段（状态码、响应体）只读（v1.0.8 起）。GET 请求不可修改（无请求体）。总开关在 Network 列表页，规则仅在启用修改模式时生效。

See [Network Inspector > Request Interceptor](Network-Inspector#request-interceptor--请求拦截修改) for details.

详见 [Network Inspector > 请求拦截修改](Network-Inspector#request-interceptor--请求拦截修改)。

---

## Logging / 日志

### Q: Can I use my existing logging library? / 可以使用现有的日志库吗？

**A:** Yes! The inspector automatically captures logs from any library that uses `print()` or `debugPrint()`. No configuration needed. Third-party logs are categorized as **Info level**.

**可以！** 检查器会自动捕获任何使用 `print()` 或 `debugPrint()` 的日志库的日志，无需配置。第三方日志统一归类为 **Info 级别**。

---

### Q: How to sync inspector logs to my logger? / 如何将检查器日志同步到我的日志库？

**A:** Use the `onLogCaptured` callback:

使用 `onLogCaptured` 回调：

```dart
InspectorLogInterceptor.instance.onLogCaptured = (entry) {
  yourLogger.log(entry.message);
};
```

> **Warning**: Do NOT call `print()` or logging methods inside this callback, as it will cause infinite recursion.
> **警告**：不要在此回调中调用 `print()` 或日志方法，否则会导致无限递归。

---

## Database / 数据库

### Q: Why don't I see any databases? / 为什么看不到数据库？

**A:** The inspector scans `getApplicationDocumentsDirectory()` and `getDatabasesPath()` for `.db` and `.sqlite` files. If your database is stored elsewhere, you can implement a custom `DatabaseProvider`.

检查器扫描 `getApplicationDocumentsDirectory()` 和 `getDatabasesPath()` 目录中的 `.db` 和 `.sqlite` 文件。如果你的数据库存储在其他位置，可以实现自定义 `DatabaseProvider`。

---

## Memory / 内存

### Q: Why does Dart Heap show "N/A" when debugging via PC? / 通过 PC 调试时为什么 Dart Heap 显示 "N/A"？

**A:** This is an expected behavior. When using `flutter run` to debug via PC, the flutter tool sets up port forwarding between PC and device via `adb reverse`, allowing PC-side DevTools to access the device's VM Service. However, `Service.getInfo()` returns a `serverUri` from the PC's perspective; when the app process internally accesses `127.0.0.1:PC_port`, the device doesn't have that port listening locally, resulting in `Connection refused` and VM Service showing OFF.

**这是预期行为。** 使用 `flutter run` 连接 PC 调试时，flutter tool 会通过 `adb reverse` 在 PC 和设备之间做端口转发，让 PC 上的 DevTools 能访问设备的 VM Service。但应用进程内部 `Service.getInfo()` 返回的 `serverUri` 是 PC 视角的端口，应用进程访问 `127.0.0.1:PC端口` 时设备本地并没有监听该端口，导致 Connection refused，VM Service 显示 OFF。

**Workarounds / 解决方案：**
- Open the debug app directly without PC connection — VM Service works normally / 直接打开 debug 应用（不连 PC），VM Service 正常工作
- Use Native memory data (Android PSS / iOS physicalFootprint) as fallback — always available / 使用 Native 内存数据（Android PSS / iOS physicalFootprint）作为降级，始终可用
- Process RSS is always available regardless of VM Service / 进程 RSS 无论 VM Service 状态都可用

See [Memory Viewer > VM Service Availability](Memory-Viewer#vm-service-availability--vm-service-可用性) for details.

详见 [Memory Viewer > VM Service 可用性](Memory-Viewer#vm-service-availability--vm-service-可用性)。

---

### Q: Does memory monitoring affect performance? / 内存监控会影响性能吗？

**A:** Memory monitoring is **off by default** (since v1.1.0). When disabled, all timers are stopped and VM Service connection is cleared, leaving zero overhead. When enabled, refresh intervals are optimized:

内存监控**默认关闭**（v1.1.0 起）。关闭时所有定时器停止、VM Service 连接清空，零开销。开启时刷新间隔已优化：

- Process RSS / Dart Heap: 500ms
- Native Memory: 3000ms
- Storage Stats: 3000ms
- Leak Detection: 2000ms

You can toggle the switch at the top of the Memory panel anytime.

可随时在 Memory 面板顶部切换开关。

---

### Q: Does leak detection require code modification? / 泄漏检测需要侵入代码吗？

**A:** The current implementation uses `WeakReference` + `Finalizer`, which requires calling `trackObject()` to register objects for tracking. This is a mild invasion (one line of code per tracked object).

当前实现使用 `WeakReference` + `Finalizer`，需要调用 `trackObject()` 注册要追踪的对象。这是轻度侵入（每个追踪对象一行代码）。

**Trade-offs / 取舍：**
- **Pros**: 100% reliable, doesn't depend on VM Service, works in release mode / 100% 可靠，不依赖 VM Service，release 模式也可用
- **Cons**: Requires user to know which objects to track / 需要用户知道要追踪哪些对象

A zero-invasion Heap Snapshot comparison feature (based on VM Service) is technically possible but would strongly depend on VM Service availability (unavailable when debugging via PC), with significant performance overhead. Not currently implemented.

零侵入的 Heap Snapshot 对比功能（基于 VM Service）技术上可行，但会强依赖 VM Service 可用性（PC 调试时不可用），且有显著性能开销。目前未实现。

See [Memory Viewer > Memory Leak Detection](Memory-Viewer#6-memory-leak-detection--内存泄漏检测) for API details.

详见 [Memory Viewer > 内存泄漏检测](Memory-Viewer#6-memory-leak-detection--内存泄漏检测) 了解 API 详情。

---

## FPS / 帧率

### Q: Why does FPS show a very low value (e.g. 9-10 FPS)? / 为什么 FPS 显示很低（如 9-10）？

**A:** This was a bug fixed in v1.2.0. The root cause was that `_recentFrameTimestamps.add(now)` was placed outside the for-loop in `_onFrameTimings`; since Flutter engine's `addTimingsCallback` is **batched** (may return multiple frames per call), only one timestamp was recorded per batch, undercounting FPS by 6-10x. Upgrade to `^1.2.0` to fix this.

这是 v1.2.0 已修复的 bug。根因是 `_onFrameTimings` 中 `_recentFrameTimestamps.add(now)` 在 for 循环外；Flutter 引擎的 `addTimingsCallback` 是**批量回调**（一次可能返回多帧），但每批只记录 1 个时间戳，导致 FPS 计算偏低 6-10 倍。升级到 `^1.2.0` 即可修复。

See [FPS Viewer](FPS-Viewer) for details.

详见 [FPS Viewer](FPS-Viewer)。

---

### Q: Does FPS monitoring affect performance? / FPS 监控会影响性能吗？

**A:** FPS monitoring is **off by default** (since v1.2.0). When disabled, no frame timings callbacks and no timers — zero overhead. When enabled, it only processes lightweight frame timing data with bounded history (60 trend points, up to 3600 frame records). You can toggle the switch at the top of the FPS panel anytime.

FPS 监控**默认关闭**（v1.2.0 起）。关闭时无帧回调、无定时器——零开销。开启时仅处理轻量帧时序数据，历史有界（趋势 60 个点，帧记录最多 3600 条）。可随时在 FPS 面板顶部切换开关。

---

## UI / 界面

### Q: The inspector panel gets pushed up when keyboard appears. / 键盘弹出时检查器面板被顶起来了。

**A:** This was fixed in v1.0.6. The floating button and panel are rendered via `Overlay`, which is independent of the page layout and not affected by keyboard.

此问题已在 v1.0.6 修复。悬浮按钮和面板通过 `Overlay` 渲染，独立于页面布局，不受键盘影响。

---

### Q: How to use search? / 如何使用搜索？

**A:** Each viewer has its own search bar at the top. Database viewer has two-level search: global search (database list) and in-database search (table names + all column data).

每个查看器顶部都有搜索栏。数据库查看器有双层搜索：全局搜索（数据库列表）和数据库内搜索（表名 + 所有列数据）。

---

### Q: The floating button disappeared / can't be opened after enabling FPS. / 开启 FPS 后悬浮按钮消失/无法打开。

**A:** This was a bug fixed in v1.2.0. The root cause was that `FpsService.notifyListeners()` triggered Overlay rebuild; combined with the original Overlay lookup failure (using `Overlay.of(context, rootOverlay: true)` which returned `null`), the button State was destroyed and could not recover. Upgrade to `^1.2.0` which uses `navigatorState.overlay` instead.

这是 v1.2.0 已修复的 bug。根因是 `FpsService.notifyListeners()` 触发 Overlay 重建，叠加原 Overlay 查找失败（使用 `Overlay.of(context, rootOverlay: true)` 返回 `null`），导致按钮 State 被销毁且无法恢复。升级到 `^1.2.0`，改用 `navigatorState.overlay` 即可。

---

### Q: How does the floating button edge docking work? / 悬浮按钮的边缘吸附怎么用？

**A:** Since v1.2.0, when you drag the button near a screen edge and release, it auto-docks and tucks into the edge, leaving only a 24px peek visible. The icon becomes a directional chevron hinting you can tap to pull it out:

- **Tap the peek** → smoothly pulls out to fully visible (panel NOT opened, avoids accidental open) / 平滑拉出到完全可见（不打开面板，避免误触）
- **Tap when fully visible** → opens the inspector panel / 打开检查器面板

This design avoids conflicts with system back gestures (Android/iOS edge swipe to go back) when pulling out from the docked state.

v1.2.0 起，拖动按钮靠近屏幕边缘松手即自动吸附并"收入"边缘，仅露 24px。图标变为方向箭头，提示可点击拉出：

- **点击露出部分** → 平滑拉出到完全可见（不打开面板，避免误触）
- **完全可见时点击** → 打开检查器面板

此设计避免了从吸附态拖出时与系统返回手势（Android/iOS 边缘右滑退出）的冲突。

See [Usage > Edge Docking](Usage#edge-docking-since-v120--边缘吸附v120-起) for details.

详见 [Usage > 边缘吸附](Usage#edge-docking-since-v120--边缘吸附v120-起)。

---

## License / 许可证

### Q: Can I use this in a commercial project? / 可以在商业项目中使用吗？

**A:** This project is licensed under **GPL-3.0**. You can use it freely, but any modified commercial distribution must also be open-source under GPL-3.0.

本项目采用 **GPL-3.0** 许可证。可以自由使用，但修改后的商业分发也必须在 GPL-3.0 下开源。

### Q: Are you liable for issues in modified versions? / 修改版出问题你们负责吗？

**A:** This plugin is provided "as is", without warranty of any kind. The author assumes no responsibility or liability for the functionality, security, or any consequences arising from the use of modified versions or derivative projects.

本插件按"原样"提供，不提供任何担保。作者不对修改版或衍生项目的功能、安全性及任何使用后果承担责任。
