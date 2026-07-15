# Zero Inspector Kit

A powerful Flutter plugin for in-app developer console, providing real-time debugging tools including network request inspection, logging, database viewing, and route tracking.

## Features

- **Network Inspector**: Capture and view all HTTP requests in real-time, including request/response headers, body, status codes, and latency.
- **Logging System**: Capture application logs automatically from print() calls, Flutter errors/exceptions, and custom log methods. Supports multiple levels (verbose, debug, info, warning, error) and third-party log library integration.
- **Database Viewer**: Inspect SQLite and other databases with support for custom database providers.
- **Route Tracker**: Monitor navigation history and current route information.
- **Floating Button**: Accessible floating inspector button that slides in/out from the edge of the screen.
- **Cross-platform**: Works on both Android and iOS.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  zero_inspector_kit:
    git:
      url: https://github.com/zero-labsco/zero_inspector_kit.git
      ref: main
```

## Usage

### Basic Setup

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

**Note**: Use `runInspectorApp()` to wrap your app for automatic print() capture. This ensures all print() calls, including those from third-party libraries, are captured by the inspector.

**Production Build**: The inspector is automatically disabled in release mode. You don't need to remove any code - Flutter's tree-shaking will remove all inspector-related code from production builds.

### Logging

The logger automatically captures logs from multiple sources once started:

```dart
InspectorLogInterceptor.instance.start();
```

**Auto-captured logs:**
- `print()` and `debugPrint()` calls
- Flutter framework errors and exceptions
- Unhandled exceptions caught by `runZonedGuarded`

**Manual logging:**
```dart
InspectorLogInterceptor.instance.verbose('Verbose log');
InspectorLogInterceptor.instance.debug('Debug log');
InspectorLogInterceptor.instance.info('Info log');
InspectorLogInterceptor.instance.warning('Warning log');
InspectorLogInterceptor.instance.error('Error log');
```

**Third-party log library integration:**

To integrate with other log libraries (e.g., logger, flutter_logger), use the `onLogCaptured` callback:

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

To capture logs from third-party libraries that use `print()` internally, no additional setup is required - they will be captured automatically.

### Network Requests (Dio)

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

### Network Requests (HTTP Package)

```dart
import 'package:http/http.dart' as http;

// GET request
final response = await InspectorHttpInterceptor.instance.get(
  Uri.parse('https://api.example.com/data'),
);

// POST request
final response = await InspectorHttpInterceptor.instance.post(
  Uri.parse('https://api.example.com/data'),
  body: {'key': 'value'},
);

// Other methods: put, delete, patch, head, send
```

### Database Provider

```dart
DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
```

## Custom Database Provider

To add support for other databases, implement the `DatabaseProvider` interface:

```dart
class MyCustomDatabaseProvider implements DatabaseProvider {
  @override
  String get name => 'CustomDB';

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    // Return list of databases
    return [];
  }

  @override
  Future<QueryResult> queryTable(String dbPath, String tableName, {int limit = 50}) async {
    // Execute query and return results
    return QueryResult(columns: [], rows: []);
  }
}

// Register the provider
DatabaseRegistry.instance.registerProvider(MyCustomDatabaseProvider());
```

## API Reference

### FloatingInspectorButton

| Parameter | Type | Description |
|-----------|------|-------------|
| enabled | bool | Whether the inspector is enabled (default: true, automatically disabled in release mode) |
| position | FloatingButtonPosition | Position of the button (left/right) |
| color | Color | Background color of the button |

### ConditionalInspector

A convenience widget that automatically shows/hides the inspector based on build mode.

```dart
ConditionalInspector(
  child: YourAppWidget(),
)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| child | Widget | The child widget |
| enabled | bool | Whether the inspector is enabled (default: true) |

### InspectorLogInterceptor

| Method | Description |
|--------|-------------|
| start() | Start capturing logs |
| stop() | Stop capturing logs |
| log(level, message, tag) | Add a log entry |
| verbose(message, tag) | Add verbose log |
| debug(message, tag) | Add debug log |
| info(message, tag) | Add info log |
| warning(message, tag) | Add warning log |
| error(message, tag) | Add error log |

| Property | Type | Description |
|----------|------|-------------|
| onLogCaptured | `void Function(LogEntry)?` | Callback when a log is captured, used for third-party log library integration |

### InspectorRouteObserver

Navigator observer for tracking route changes.

### runInspectorApp

A helper function to run your app with the inspector Zone, enabling automatic print() capture.

```dart
runInspectorApp(VoidCallback appRunner)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| appRunner | VoidCallback | The function to run your app (usually `runApp`) |

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.