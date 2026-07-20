# Zero Inspector Kit

一个功能强大的 Flutter 插件，用于应用内开发者控制台，提供实时调试工具，包括网络请求检查、日志记录、数据库查看和路由追踪。

🌐 **[官方网站](https://www.zerolabsco.com/)**

🔗 **[查看 GitHub 仓库](https://github.com/zero-labsco/zero_inspector_kit)**

## 功能特性

- **零侵入性**: 仅需一行代码即可集成，无需修改项目任何现有代码（http 包用户）。
- **网络检查器**: 实时捕获和查看所有 HTTP 请求，包括请求/响应头、请求体、状态码和延迟时间。
- **日志系统**: 自动捕获应用中的日志，包括 print() 调用、Flutter 错误和异常。支持多种日志级别（verbose、debug、info、warning、error），并支持第三方日志库集成。
- **数据库查看器**: 支持 SQLite 和其他数据库的检查，支持自定义数据库提供者。
- **路由追踪器**: 监控导航历史和当前路由信息。
- **悬浮按钮**: 从屏幕边缘滑入/滑出的可访问悬浮检查按钮。
- **跨平台**: 支持 Android 和 iOS 平台。

## 安装

### Pub.dev（推荐）

在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  zero_inspector_kit: ^1.0.6
```

### GitHub

或者，你也可以从 GitHub 安装：

```yaml
dependencies:
  zero_inspector_kit:
    git:
      url: https://github.com/zero-labsco/zero_inspector_kit.git
      ref: main
```

## 使用方法

### 零侵入集成（推荐）

只需**一行代码**即可完成集成，无需修改项目任何现有代码：

```dart
import 'package:flutter/material.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  // 一行代码：初始化检查器、通过 Zone 捕获 print()、自动显示悬浮按钮
  ZeroInspectorKit.runAppWithInspector(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [InspectorRouteObserver()],
      home: Scaffold(
        appBar: AppBar(title: const Text('App')),
        body: const Center(child: Text('Hello World')),
      ),
    );
  }
}
```

**零侵入性说明**：

集成后，检查器会自动完成以下工作，无需修改项目其他代码：

- ✅ **日志捕获**: 通过 Zone 自动捕获所有 `print()`、`debugPrint()` 调用和 Flutter 错误
- ✅ **网络拦截**: 通过 HttpOverrides 自动拦截 **http 包**和 **Dio** 的所有网络请求（Dio 默认使用 HttpClient）。
- ✅ **数据库扫描**: 自动扫描并注册 SQLite 数据库
- ✅ **悬浮按钮**: 通过 Overlay 自动显示，无需手动添加任何组件
- ✅ **路由追踪**: 通过 `InspectorRouteObserver` 监控导航历史（自动注入到 MaterialApp）

**生产构建**: 检查器在 release 模式下会自动禁用。你不需要移除任何代码 - Flutter 的 tree-shaking 会从生产构建中移除所有检查器相关代码。

### 替代集成方式（两行代码）

如果你需要更多控制权，可以使用两行代码的方式：

```dart
void main() {
  ZeroInspectorKit.init();
  runApp(ZeroInspectorKit.wrapApp(const MyApp()));
}
```

### 日志记录

启动后自动从多个来源捕获日志：

```dart
InspectorLogInterceptor.instance.start();
```

**自动捕获的日志：**
- `print()` 和 `debugPrint()` 调用
- Flutter 框架错误和异常
- `runZonedGuarded` 捕获的未处理异常

**手动记录日志（可选）：**

如果需要更精确的日志级别控制，可以使用检查器提供的日志方法。这是**可选功能**，不影响自动捕获功能：

```dart
InspectorLogInterceptor.instance.verbose('详细日志');
InspectorLogInterceptor.instance.debug('调试日志');
InspectorLogInterceptor.instance.info('信息日志');
InspectorLogInterceptor.instance.warning('警告日志');
InspectorLogInterceptor.instance.error('错误日志');
```

**第三方日志库集成（自动）：**

**无需任何配置！** 插件会自动捕获所有使用 `print()` 或 `debugPrint()` 的第三方日志库（如 logger、flutter_logger、logcat）的日志。

工作原理：插件通过覆盖 `debugPrint` 和 Zone 机制捕获所有 `print()` 调用，而大多数第三方日志库内部都是通过 `print()` 输出日志的。

这些日志统一归类到 **INFO 级别**，因为每个库都有自己的级别标识（emoji、前缀等），用户可通过日志内容识别级别。

**双向同步（可选）：**

如果需要将检查器捕获的日志同步到第三方日志库（让检查器日志也出现在你的日志服务中），可以使用 `onLogCaptured` 回调：

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

### 网络请求

所有 HTTP 请求（包括 **http 包**和 **Dio**）在初始化后都会通过 `HttpOverrides` 自动拦截。无需任何额外配置！

**http 包：**
```dart
import 'package:http/http.dart' as http;

// GET 请求（自动捕获）
final response = await http.get(
  Uri.parse('https://api.example.com/data'),
);

// POST 请求（自动捕获）
final response = await http.post(
  Uri.parse('https://api.example.com/data'),
  body: {'key': 'value'},
);
```

**Dio（零侵入）：**
```dart
import 'package:dio/dio.dart';

final Dio dio = Dio();

// GET 请求（自动捕获）
final response = await dio.get('https://api.example.com/data');

// POST 请求（自动捕获）
final response = await dio.post(
  'https://api.example.com/data',
  data: {'key': 'value'},
);
```

**注意：** Dio 默认使用 `IOHttpClientAdapter`，内部使用 `dart:io` 的 `HttpClient`。这使得检查器可以通过 `HttpOverrides` 自动捕获 Dio 请求，无需任何额外配置。

### 数据库提供者

```dart
DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
```

## 自定义数据库提供者

要添加对其他数据库的支持，实现 `DatabaseProvider` 接口：

```dart
class MyCustomDatabaseProvider implements DatabaseProvider {
  @override
  String get name => 'CustomDB';

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    // 返回数据库列表
    return [];
  }

  @override
  Future<QueryResult> queryTable(String dbPath, String tableName, {int limit = 50}) async {
    // 执行查询并返回结果
    return QueryResult(columns: [], rows: []);
  }
}

// 注册提供者
DatabaseRegistry.instance.registerProvider(MyCustomDatabaseProvider());
```

## API 参考

### FloatingInspectorButton

| 参数 | 类型 | 描述 |
|------|------|------|
| enabled | bool | 是否启用检查器（默认：true，release 模式下自动禁用） |

### ConditionalInspector

一个便利组件，根据构建模式自动显示/隐藏检查器。

```dart
ConditionalInspector(
  child: YourAppWidget(),
)
```

| 参数 | 类型 | 描述 |
|------|------|------|
| child | Widget | 子组件 |
| enabled | bool | 是否启用检查器（默认：true） |

### InspectorLogInterceptor

| 方法 | 描述 |
|------|------|
| start() | 开始捕获日志 |
| stop() | 停止捕获日志 |
| log(level, message, tag) | 添加日志条目 |
| verbose(message, tag) | 添加详细日志 |
| debug(message, tag) | 添加调试日志 |
| info(message, tag) | 添加信息日志 |
| warning(message, tag) | 添加警告日志 |
| error(message, tag) | 添加错误日志 |

| 属性 | 类型 | 描述 |
|------|------|------|
| onLogCaptured | `void Function(LogEntry)?` | 日志捕获回调，用于第三方日志库集成 |

### InspectorRouteObserver

用于追踪路由变化的 Navigator observer。

### runInspectorApp

一个辅助函数，使用检查器 Zone 运行应用，启用自动 print() 捕获。

```dart
runInspectorApp(VoidCallback appRunner)
```

| 参数 | 类型 | 描述 |
|------|------|------|
| appRunner | VoidCallback | 运行应用的函数（通常是 `runApp`） |

## 贡献

欢迎贡献代码！请随时提交 issue 和 pull request。

## 许可证

本项目采用 GNU General Public License v3.0 许可证 - 详见 [LICENSE](LICENSE) 文件。