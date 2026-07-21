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
