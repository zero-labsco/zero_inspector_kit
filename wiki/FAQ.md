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

## UI / 界面

### Q: The inspector panel gets pushed up when keyboard appears. / 键盘弹出时检查器面板被顶起来了。

**A:** This was fixed in v1.0.6. The floating button and panel are rendered via `Overlay`, which is independent of the page layout and not affected by keyboard.

此问题已在 v1.0.6 修复。悬浮按钮和面板通过 `Overlay` 渲染，独立于页面布局，不受键盘影响。

---

### Q: How to use search? / 如何使用搜索？

**A:** Each viewer has its own search bar at the top. Database viewer has two-level search: global search (database list) and in-database search (table names + all column data).

每个查看器顶部都有搜索栏。数据库查看器有双层搜索：全局搜索（数据库列表）和数据库内搜索（表名 + 所有列数据）。

---

## License / 许可证

### Q: Can I use this in a commercial project? / 可以在商业项目中使用吗？

**A:** This project is licensed under **GPL-3.0**. You can use it freely, but any modified commercial distribution must also be open-source under GPL-3.0.

本项目采用 **GPL-3.0** 许可证。可以自由使用，但修改后的商业分发也必须在 GPL-3.0 下开源。
