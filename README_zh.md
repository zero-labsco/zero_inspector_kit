# Zero Inspector Kit

一个功能强大的 Flutter 插件，用于应用内开发者控制台，提供实时调试工具，包括网络请求检查、日志记录、数据库查看和路由追踪。

## 功能特性

- **网络检查器**: 实时捕获和查看所有 HTTP 请求，包括请求/响应头、请求体、状态码和延迟时间。
- **日志系统**: 自动捕获应用中的日志，包括 print() 调用、Flutter 错误和异常。支持多种日志级别（verbose、debug、info、warning、error），并支持第三方日志库集成。
- **数据库查看器**: 支持 SQLite 和其他数据库的检查，支持自定义数据库提供者。
- **路由追踪器**: 监控导航历史和当前路由信息。
- **悬浮按钮**: 从屏幕边缘滑入/滑出的可访问悬浮检查按钮。
- **跨平台**: 支持 Android 和 iOS 平台。

## 安装

在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  zero_inspector_kit:
    git:
      url: https://github.com/zero-labsco/zero_inspector_kit.git
      ref: main
```

## 使用方法

### 基本配置

```dart
import 'package:flutter/material.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  runInspectorApp(() {
    runApp(const MyApp());
  });
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
        floatingActionButton: const FloatingInspectorButton(enabled: true),
      ),
    );
  }
}
```

**注意**: 使用 `runInspectorApp()` 包装你的应用以启用自动 print() 捕获。这确保所有 print() 调用（包括第三方库的调用）都能被检查器捕获。

**生产构建**: 检查器在 release 模式下会自动禁用。你不需要移除任何代码 - Flutter 的 tree-shaking 会从生产构建中移除所有检查器相关代码。

### 日志记录

启动后自动从多个来源捕获日志：

```dart
InspectorLogInterceptor.instance.start();
```

**自动捕获的日志：**
- `print()` 和 `debugPrint()` 调用
- Flutter 框架错误和异常
- `runZonedGuarded` 捕获的未处理异常

**手动记录日志：**
```dart
InspectorLogInterceptor.instance.verbose('详细日志');
InspectorLogInterceptor.instance.debug('调试日志');
InspectorLogInterceptor.instance.info('信息日志');
InspectorLogInterceptor.instance.warning('警告日志');
InspectorLogInterceptor.instance.error('错误日志');
```

**第三方日志库集成：**

要与其他日志库（如 logger、flutter_logger）集成，使用 `onLogCaptured` 回调：

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

对于内部使用 `print()` 的第三方日志库，无需额外配置，会自动被捕获。

### 网络请求（Dio）

```dart
import 'package:dio/dio.dart';

final Dio dio = Dio();
final InspectorDioInterceptor dioInterceptor = InspectorDioInterceptor();

dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) {
      dioInterceptor.onRequest({
        'method': options.method,
        'url': options.uri.toString(),
        'headers': options.headers.cast<String, String>(),
        'data': options.data,
      });
      handler.next(options);
    },
    onResponse: (response, handler) {
      dioInterceptor.onResponse({
        'data': response.data,
        'statusCode': response.statusCode,
        'requestOptions': {
          'method': response.requestOptions.method,
          'uri': response.requestOptions.uri,
        },
      });
      handler.next(response);
    },
    onError: (error, handler) {
      dioInterceptor.onError({
        'message': error.message,
        'response': error.response != null ? {
          'data': error.response!.data,
          'statusCode': error.response!.statusCode,
        } : null,
        'requestOptions': {
          'method': error.requestOptions.method,
          'uri': error.requestOptions.uri,
        },
      });
      handler.next(error);
    },
  ),
);
```

### 网络请求（HTTP 包）

```dart
import 'package:http/http.dart' as http;

// GET 请求
final response = await InspectorHttpInterceptor.instance.get(
  Uri.parse('https://api.example.com/data'),
);

// POST 请求
final response = await InspectorHttpInterceptor.instance.post(
  Uri.parse('https://api.example.com/data'),
  body: {'key': 'value'},
);

// 其他方法: put, delete, patch, head, send
```

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
| position | FloatingButtonPosition | 按钮位置（左/右） |
| color | Color | 按钮背景颜色 |

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