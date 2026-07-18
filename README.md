# Zero Inspector Kit

A powerful Flutter plugin for in-app developer console, providing real-time debugging tools including network request inspection, logging, database viewing, and route tracking.

## Features

- **Zero Invasion**: Integrate with just **1 line of code**, no need to modify any existing project code.
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

### Zero Invasion Integration (Recommended)

Integrate with just **1 line of code**, no need to modify any existing project code:

```dart
import 'package:flutter/material.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  // Single line: Initialize inspector, capture print() via Zone, and display floating button
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

**Zero Invasion Explanation**:

After integration, the inspector automatically does the following without modifying any other project code:

- ✅ **Log Capture**: Automatically captures all `print()`, `debugPrint()` calls and Flutter errors via Zone
- ✅ **Network Interception**: Automatically intercepts all http package network requests via HttpOverrides
- ✅ **Database Scan**: Automatically scans and registers SQLite databases
- ✅ **Floating Button**: Automatically displayed via Overlay, no need to manually add any components
- ✅ **Route Tracking**: Monitors navigation history via `InspectorRouteObserver`

**Production Build**: The inspector is automatically disabled in release mode. You don't need to remove any code - Flutter's tree-shaking will remove all inspector-related code from production builds.

### Alternative Integration (Two Lines)

If you prefer more control, you can use the two-line approach:

```dart
void main() {
  ZeroInspectorKit.init();
  runApp(ZeroInspectorKit.wrapApp(const MyApp()));
}
```

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

Third-party log libraries (e.g., logger, flutter_logger) that use `print()` internally will be captured automatically. These logs are categorized as **INFO level** since each library has its own level indicators (emoji, prefixes, etc.) that users can identify from the log content.

To integrate with other log libraries using the `onLogCaptured` callback:

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

HTTP package requests are automatically intercepted via `HttpOverrides` after initialization. No additional setup is required - just use http package as normal:

```dart
import 'package:http/http.dart' as http;

// GET request (automatically captured)
final response = await http.get(
  Uri.parse('https://api.example.com/data'),
);

// POST request (automatically captured)
final response = await http.post(
  Uri.parse('https://api.example.com/data'),
  body: {'key': 'value'},
);
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