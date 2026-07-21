# Usage / 使用指南

## Integration Methods / 集成方式

### 1. One-Line Integration (Recommended) / 一行代码集成（推荐）

```dart
void main() {
  ZeroInspectorKit.runAppWithInspector(const MyApp());
}
```

This method:
- Auto-initializes inspector / 自动初始化检查器
- Captures `print()` via Zone / 通过 Zone 捕获 print()
- Displays floating button via Overlay / 通过 Overlay 显示悬浮按钮
- Auto-injects route observer / 自动注入路由观察者

### 2. Two-Line Integration / 两行代码集成

```dart
void main() {
  ZeroInspectorKit.init();
  runApp(ZeroInspectorKit.wrapApp(const MyApp()));
}
```

## Inspector Panel / 检查器面板

The inspector panel contains **4 tabs**:

检查器面板包含 **4 个标签页**：

| Tab | Icon | Feature |
|-----|------|---------|
| **Network** | 🌐 | HTTP request viewing / 网络请求查看 |
| **Logs** | 📝 | Log viewing with level filter / 日志查看 |
| **Database** | 💾 | Database and table inspection / 数据库查看 |
| **Routes** | 🧭 | Route navigation tracking / 路由追踪 |

## Floating Button / 悬浮按钮

- The floating button appears after 1 second delay / 悬浮按钮延迟 1 秒出现
- **Drag** to move it along the screen edge / **拖动** 可沿屏幕边缘移动
- **Tap** to open/close the inspector panel / **点击** 打开/关闭检查器面板
- Button auto-snaps to the nearest screen edge / 按钮自动吸附到最近的屏幕边缘
- Breathing animation when idle / 空闲时有呼吸动画

## Search / 搜索

All three main viewers (Network, Logs, Database) support **fuzzy search**:

三大查看器均支持**模糊搜索**：

| Viewer | Search Scope |
|--------|-------------|
| Network | URL, HTTP method / URL、请求方法 |
| Logs | Message, tag / 消息、标签 |
| Database (global) | Database name, table name / 数据库名、表名 |
| Database (in-database) | Table name, all column data / 表名、所有列数据 |

## Manual Logging (Optional) / 手动记录日志（可选）

The inspector auto-captures `print()` output. You can also use manual log methods for precise level control:

检查器会自动捕获 `print()` 输出。也可以使用手动日志方法进行精确级别控制：

```dart
InspectorLogInterceptor.instance.verbose('Verbose log / 详细日志');
InspectorLogInterceptor.instance.debug('Debug log / 调试日志');
InspectorLogInterceptor.instance.info('Info log / 信息日志');
InspectorLogInterceptor.instance.warning('Warning log / 警告日志');
InspectorLogInterceptor.instance.error('Error log / 错误日志');
```

## Third-Party Log Integration / 第三方日志库集成

**No configuration needed!** The plugin automatically captures logs from third-party logging libraries (e.g., logger, flutter_logger) that use `print()` or `debugPrint()`.

**无需配置！** 插件会自动捕获所有使用 `print()` 的第三方日志库的日志。

These logs are categorized as **INFO level**.

这些日志统一归类为 **INFO 级别**。

### Bidirectional Sync (Optional) / 双向同步（可选）

To sync inspector-captured logs to your third-party logger:

将检查器捕获的日志同步到第三方日志库：

```dart
InspectorLogInterceptor.instance.onLogCaptured = (entry) {
  yourLogger.log(entry.message);
};
```

## Feature Pages / 功能详情

- [Network Inspector](Network-Inspector) — Network request details / 网络检查器详情
- [Log Viewer](Log-Viewer) — Log viewing details / 日志查看器详情
- [Database Viewer](Database-Viewer) — Database inspection details / 数据库查看器详情
- [Route Tracker](Route-Tracker) — Route tracking details / 路由追踪详情
