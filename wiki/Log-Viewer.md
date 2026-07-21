# Log Viewer / 日志查看器

## Overview / 概述

The Log Viewer automatically captures logs from multiple sources with zero configuration.

日志查看器自动从多个来源捕获日志，无需配置。

## Log Sources / 日志来源

| Source | Capture Method |
|--------|---------------|
| `print()` | Zone specification override / Zone 规范覆盖 |
| `debugPrint()` | debugPrint override / debugPrint 覆盖 |
| Flutter errors | runZonedGuarded / runZonedGuarded 捕获 |
| Unhandled exceptions | runZonedGuarded / runZonedGuarded 捕获 |
| Third-party libraries | Via print() capture / 通过 print() 捕获 |

## Log Levels / 日志级别

| Level | Abbreviation | Color | Description |
|-------|-------------|-------|-------------|
| Verbose | V | Gray | Detailed information / 详细信息 |
| Debug | D | Blue | Debug information / 调试信息 |
| Info | I | Green | General information / 一般信息 |
| Warning | W | Orange | Warning messages / 警告信息 |
| Error | E | Red | Error messages / 错误信息 |

> Third-party library logs are categorized as **Info** level.

> 第三方日志库的日志统一归类为 **Info** 级别。

## UI Features / UI 功能

### Filter Bar / 过滤栏
- **All**: Show all logs / 显示所有日志
- **V / D / I / W / E**: Filter by level / 按级别过滤
- Single-select mode / 单选模式

### Log List / 日志列表
- Level badge with color / 带颜色的级别徽章
- Timestamp display / 时间戳显示
- Tag display (if available) / 标签显示（如有）
- Error/warning rows have subtle background tint / 错误/警告行有淡色背景
- Left border color indicates level / 左侧边框颜色表示级别

### Search / 搜索
- Fuzzy search by message content or tag / 按消息内容或标签模糊搜索
- Combined with level filter / 可与级别过滤组合使用

## Manual Logging / 手动记录日志

```dart
InspectorLogInterceptor.instance.verbose('Verbose message / 详细消息');
InspectorLogInterceptor.instance.debug('Debug message / 调试消息');
InspectorLogInterceptor.instance.info('Info message / 信息消息');
InspectorLogInterceptor.instance.warning('Warning message / 警告消息');
InspectorLogInterceptor.instance.error('Error message / 错误消息');

// With tag / 带标签
InspectorLogInterceptor.instance.info('User logged in', tag: 'Auth');
```

## Third-Party Library Integration / 第三方日志库集成

### Auto-Capture (Inbound) / 自动捕获（入站）

No configuration needed. Any library using `print()` or `debugPrint()` is automatically captured.

无需配置。任何使用 `print()` 或 `debugPrint()` 的库都会被自动捕获。

### Bidirectional Sync (Optional) / 双向同步（可选）

To forward inspector logs to your third-party logger:

将检查器日志转发到第三方日志库：

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

> **Note**: Do NOT call logging methods inside `onLogCaptured`, as this will cause infinite recursion.
> **注意**：不要在 `onLogCaptured` 内部调用日志方法，否则会导致无限递归。

## Starting the Log Interceptor / 启动日志拦截器

If using `runAppWithInspector()`, the log interceptor starts automatically. Otherwise:

如果使用 `runAppWithInspector()`，日志拦截器会自动启动。否则：

```dart
InspectorLogInterceptor.instance.start();
```
