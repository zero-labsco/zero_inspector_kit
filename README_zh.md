# Zero Inspector Kit

一个功能强大的 Flutter 插件，用于应用内开发者控制台，提供实时调试工具，包括网络请求检查、日志记录、数据库查看和路由追踪。

## 功能特性

- **网络检查器**: 实时捕获和查看所有 HTTP 请求，包括请求/响应头、请求体、状态码和延迟时间。
- **日志系统**: 支持多种日志级别（verbose、debug、info、warning、error）的应用日志捕获。
- **数据库查看器**: 支持 SQLite 和其他数据库的检查，支持自定义数据库提供者。
- **路由追踪器**: 监控导航历史和当前路由信息。
- **悬浮按钮**: 从屏幕边缘滑入/滑出的可访问悬浮检查按钮。
- **跨平台**: 支持 Android 和 iOS 平台。

## 安装

在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  zero_inspector_kit:
    path: /path/to/zero_inspector_kit
```

## 使用方法

### 基本配置

```dart
import 'package:flutter/material.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  runApp(const MyApp());
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

### 日志记录

```dart
InspectorLogInterceptor.instance.start();

InspectorLogInterceptor.instance.verbose('详细日志');
InspectorLogInterceptor.instance.debug('调试日志');
InspectorLogInterceptor.instance.info('信息日志');
InspectorLogInterceptor.instance.warning('警告日志');
InspectorLogInterceptor.instance.error('错误日志');
```

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
| enabled | bool | 是否启用检查器 |
| position | FloatingButtonPosition | 按钮位置（左/右） |
| color | Color | 按钮背景颜色 |

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

### InspectorRouteObserver

用于追踪路由变化的 Navigator observer。

## 贡献

欢迎贡献代码！请随时提交 issue 和 pull request。

## 许可证

本项目采用 GNU General Public License v3.0 许可证 - 详见 [LICENSE](LICENSE) 文件。