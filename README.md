# Zero Inspector Kit

A powerful Flutter plugin for in-app developer console, providing real-time debugging tools including network request inspection, logging, database viewing, and route tracking.

## Features

- **Network Inspector**: Capture and view all HTTP requests in real-time, including request/response headers, body, status codes, and latency.
- **Logging System**: Capture application logs with multiple levels (verbose, debug, info, warning, error).
- **Database Viewer**: Inspect SQLite and other databases with support for custom database providers.
- **Route Tracker**: Monitor navigation history and current route information.
- **Floating Button**: Accessible floating inspector button that slides in/out from the edge of the screen.
- **Cross-platform**: Works on both Android and iOS.

## Installation

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  zero_inspector_kit:
    path: /path/to/zero_inspector_kit
```

## Usage

### Basic Setup

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

### Logging

```dart
InspectorLogInterceptor.instance.start();

InspectorLogInterceptor.instance.verbose('Verbose log');
InspectorLogInterceptor.instance.debug('Debug log');
InspectorLogInterceptor.instance.info('Info log');
InspectorLogInterceptor.instance.warning('Warning log');
InspectorLogInterceptor.instance.error('Error log');
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
| enabled | bool | Whether the inspector is enabled |
| position | FloatingButtonPosition | Position of the button (left/right) |
| color | Color | Background color of the button |

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

### InspectorRouteObserver

Navigator observer for tracking route changes.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.