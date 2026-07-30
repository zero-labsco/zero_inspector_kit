# Zero Inspector Kit

A powerful Flutter plugin for in-app developer console, providing real-time debugging tools including network request inspection, logging, database viewing, memory monitoring, FPS monitoring, and route tracking.

[![pub version](https://img.shields.io/pub/v/zero_inspector_kit.svg)](https://pub.dev/packages/zero_inspector_kit)
[![pub points](https://img.shields.io/pub/points/zero_inspector_kit.svg)](https://pub.dev/packages/zero_inspector_kit/score)
[![CI](https://github.com/zero-labsco/zero_inspector_kit/actions/workflows/ci.yml/badge.svg)](https://github.com/zero-labsco/zero_inspector_kit/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://github.com/zero-labsco/zero_inspector_kit/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-✓-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-✓-0175C2?logo=dart)](https://dart.dev)
[![Style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://pub.dev/packages/effective_dart)

> **🔔 Upgrade recommended:** v1.2.1 fixes fundamental FPS accuracy issues (timestamps used `DateTime.now()` instead of real frame timestamps; frame duration only counted build phase, missing GPU rasterization jank). All users using the FPS monitor feature are advised to upgrade to `^1.2.1`.

🌐 **[Official Website](https://www.zerolabsco.com/)**

🔗 **[View on GitHub](https://github.com/zero-labsco/zero_inspector_kit)**

## Features

- **Zero Invasion**: Integrate with just **1 line of code**, no need to modify any existing project code.
- **Network Inspector**: Capture and view all HTTP requests in real-time, including request/response headers, body, status codes, and latency. Supports modifying request body and headers via interceptor rules (for POST/PUT/PATCH requests).
- **Logging System**: Capture application logs automatically from print() calls, Flutter errors/exceptions, and custom log methods. Supports multiple levels (verbose, debug, info, warning, error) and third-party log library integration.
- **Database Viewer**: Inspect SQLite and other databases with support for custom database providers.
- **Memory Monitor**: Real-time memory monitoring with trend chart, Dart Heap details, Native memory breakdown (Android PSS / iOS physicalFootprint), memory leak detection, image cache monitoring, and app storage statistics. Master switch to avoid performance overhead.
- **FPS Monitor**: Real-time FPS measurement, frame duration stats, jank detection, and FPS trend chart (30-second window). Master switch to avoid performance overhead.
- **Route Tracker**: Monitor navigation history and current route information.
- **Floating Button**: Accessible floating inspector button with breathing animation, rendered via root `Overlay` so it stays independent of any page's widget tree. Drag and release to auto-dock and tuck into the nearest screen edge (only a small peek visible); tap the peek to smoothly pull it out, then tap again to open the panel. This avoids conflicts with system back-gesture edges.
- **Modern UI**: Beautiful dark theme with gradient design, customizable colors via centralized theme configuration.
- **Cross-platform**: Works on Android and iOS.

## Installation

### Pub.dev (Recommended)

Add the following to your `pubspec.yaml`:

```yaml
dependencies:
  zero_inspector_kit: ^1.2.1
```

### GitHub

Alternatively, you can install from GitHub (replace `1.2.1` with the version you need):

```yaml
dependencies:
  zero_inspector_kit:
    git:
      url: https://github.com/zero-labsco/zero_inspector_kit.git
      ref: v1.2.1
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
- ✅ **Network Interception**: Automatically intercepts all **http package** and **Dio** network requests via HttpOverrides (Dio uses HttpClient by default).
- ✅ **Database Scan**: Automatically scans and registers SQLite databases
- ✅ **Floating Button**: Automatically displayed via Overlay, no need to manually add any components
- ✅ **Route Tracking**: Monitors navigation history via `InspectorRouteObserver` (automatically injected into MaterialApp)

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

**Manual logging (Optional):**

For more precise log level control, you can use the inspector's log methods. This is **optional** and does not affect auto-capture functionality.

Quick shorthand (recommended):

```dart
InspectorLog.v('Verbose log');
InspectorLog.d('Debug log');
InspectorLog.i('Info log');
InspectorLog.w('Warning log');
InspectorLog.e('Error log');
```

You can also use the full form if needed:

```dart
InspectorLogInterceptor.instance.verbose('Verbose log');
InspectorLogInterceptor.instance.debug('Debug log');
InspectorLogInterceptor.instance.info('Info log');
InspectorLogInterceptor.instance.warning('Warning log');
InspectorLogInterceptor.instance.error('Error log');
```

**Third-party log library integration (Automatic):**

**No configuration needed!** The plugin automatically captures logs from all third-party logging libraries (e.g., logger, flutter_logger, logcat) that use `print()` or `debugPrint()`.

How it works: The plugin captures all `print()` calls by overriding `debugPrint` and using Zone mechanism. Most third-party logging libraries internally output logs via `print()`.

These logs are categorized as **INFO level** since each library has its own level indicators (emoji, prefixes, etc.) that users can identify from the log content.

**Bidirectional Sync (Optional):**

If you need to sync inspector-captured logs to your third-party logging library (make inspector logs also appear in your logging service), use the `onLogCaptured` callback:

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

### Network Requests

All HTTP requests (both **http package** and **Dio**) are automatically intercepted via `HttpOverrides` after initialization. No additional setup is required!

**http package:**
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

**Dio (zero-invasion):**
```dart
import 'package:dio/dio.dart';

final Dio dio = Dio();

// GET request (automatically captured)
final response = await dio.get('https://api.example.com/data');

// POST request (automatically captured)
final response = await dio.post(
  'https://api.example.com/data',
  data: {'key': 'value'},
);
```

**Note:** Dio uses `IOHttpClientAdapter` by default, which internally uses `dart:io`'s `HttpClient`. This allows the inspector to capture Dio requests automatically via `HttpOverrides` without any additional configuration.

### Network Request Interceptor

The inspector supports intercepting and modifying network requests via rules. This is useful for testing different request parameters without modifying app code.

**Workflow:**
1. Send a request normally (it will be captured in the Network panel)
2. Open the request detail and tap the Interceptor icon
3. Configure the modification rule (URL pattern, HTTP method, request modifications)
4. Save the rule — subsequent matching requests will use the modified parameters

**Supported modifications:**
- Request body and request headers
- Only for requests with body (POST, PUT, PATCH, etc.)
- GET requests are view-only and cannot be modified

**Why can't GET requests be modified?**
- The interceptor currently supports modifying request body and headers only
- GET requests don't have a request body
- Modifying GET request parameters would require URL modification
- URL modification may cause unexpected issues with request routing and parameter encoding

**Rule matching:**
- URL pattern matching (exact match or regex)
- HTTP method filtering (GET, POST, PUT, DELETE, PATCH, HEAD, or Any)

**Note:** When no rules are configured or rules are disabled, all requests are sent normally without any modification.

### Database Provider

```dart
DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
```

### Memory Monitor

The memory monitor provides comprehensive memory analysis with a master switch to control data collection (off by default to avoid performance overhead).

**Master Switch:**
- Top switch in the Memory panel controls whether monitoring is enabled
- When disabled: all timers stop, VM Service connection is cleared (no WebSocket overhead)
- When enabled: starts data collection and attempts VM Service connection

**Memory Trend Chart:**
- Real-time line chart with 2-minute history window (240 snapshots × 500ms)
- Switchable between 4 metrics: Process RSS / Dart Heap / New Space / Old Space

**Dart Heap Overview (requires VM Service):**
- Heap Usage / Capacity / External usage with progress bar
- New/Old space detailed breakdown (Usage / Capacity / External)
- Manual GC trigger button (disabled when VM Service unavailable)

**Native Memory (100% available on real devices):**
- Android: Total PSS, Dalvik PSS, Native PSS, Native Private Dirty, Device Memory status
- iOS: Physical Footprint, Compressed memory, Process RSS, Device available memory
- Low memory warning indicator

**Memory Leak Detection (based on Dart 2.17+ WeakReference):**
- Register objects for leak tracking via `trackObject()` API
- Four-state transition: tracking → verifying → leaked / released
- Auto-trigger GC verification after exceeding expected release time
- UI shows suspected leaks (red), tracking objects, and released objects

```dart
// Quick shorthand (recommended)
myBloc.trackMemoryLeak(tag: 'HomePage_myBloc');

// Or use top-level function
trackMemoryLeak(myBloc, tag: 'HomePage_myBloc');

// Cancel tracking
myBloc.untrackMemoryLeak();

// Or use the full form if needed
MemoryInspectorService.instance.trackObject(
  myBloc,
  tag: 'HomePage_myBloc',
  expectedReleaseAfter: Duration(seconds: 60),
);
MemoryInspectorService.instance.untrackObject(myBloc);

// Clear all records
MemoryInspectorService.instance.clearLeakRecords();
```

**Image Cache Monitoring:**
- Real-time display of image cache size and count
- Shows pending (loading) and live (in use) image counts
- Visual progress bar of cache usage
- One-click clear all image cache

**App Storage Statistics:**
- Documents directory size
- Temp cache directory size
- Total database file size
- One-click clear app temp cache

**⚠️ Important: VM Service availability**

**When debugging via PC with `flutter run`, Dart VM Heap data may be unavailable (VM: OFF).**

**Reason:** When using `flutter run` to debug via PC, the flutter tool sets up port forwarding between PC and device via `adb reverse`, allowing PC-side DevTools to access the device's VM Service. However, `Service.getInfo()` returns a `serverUri` from PC's perspective; when the app process internally accesses `127.0.0.1:PC_port`, the device doesn't have that port listening locally, resulting in `Connection refused` and VM Service showing OFF.

**Does not affect actual usage:** When opening the debug app directly without PC connection (no flutter tool involved), VM Service listens directly on the device's local port, the app can connect normally, and Dart Heap data displays correctly.

**Fallback:** When VM Service is unavailable, Native memory (Android PSS / iOS physicalFootprint) still displays normally, and process RSS is always available. Only Dart Heap details and manual GC are unavailable.

### FPS Monitor

The FPS Monitor provides real-time frame performance analysis with a master switch to control data collection (off by default to avoid performance overhead).

**Master Switch:**
- Top switch in the FPS panel controls whether monitoring is enabled
- When disabled: no frame timings callbacks, no timer, no overhead
- When enabled: starts collecting frame data via `WidgetsBinding.instance.addTimingsCallback`

**Features:**
- Current FPS, jank rate, total frame count
- FPS trend line chart (30-second window, 60 data points)
- Janky frame list with duration and timestamp (frames > 16ms)
- Reset button to clear all statistics

**Accuracy (since v1.2.1):**
- Frame timestamps use `timing.timestampInMicroseconds(FramePhase.buildStart)` — the real per-frame start time from the Flutter engine, not `DateTime.now()` (which collides across batched frames)
- Frame duration uses `rasterFinish - buildStart`, covering **both build and raster (GPU) phases** — this catches GPU rasterization jank, the most common Flutter jank type that pure `buildDuration`-based detection misses

**Programmatic control (optional):**

```dart
// Start / Stop FPS monitoring from code
FpsService.instance.start();
FpsService.instance.stop();

// Read current stats
final fps = FpsService.instance.currentFps;
final jankRate = FpsService.instance.jankRate;
final totalFrames = FpsService.instance.totalFrameCount;
final jankyFrames = FpsService.instance.totalJankyCount;

// Clear historical data
FpsService.instance.clear();

// Listen to updates
FpsService.instance.addListener(() {
  // Update your own UI
});

// Historical data access
final history = FpsService.instance.fpsHistory;       // List<double>, 60 entries
final records = FpsService.instance.frameRecords;      // List<FrameRecord>, unmodifiable
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

### InspectorLog

A shorthand wrapper around `InspectorLogInterceptor.instance` for shorter log calls.

| Method | Description |
|--------|-------------|
| start() | Start capturing logs |
| stop() | Stop capturing logs |
| log(level, message, {tag}) | Add a log entry |
| v(message, {tag}) | Add verbose log |
| d(message, {tag}) | Add debug log |
| i(message, {tag}) | Add info log |
| w(message, {tag}) | Add warning log |
| e(message, {tag}) | Add error log |

| Property | Type | Description |
|----------|------|-------------|
| isRunning | bool | Whether log capture is currently active |

### InspectorRouteObserver

Navigator observer for tracking route changes.

### FpsService

Singleton service for FPS monitoring, extends `ChangeNotifier`.

| Method | Description |
|--------|-------------|
| start() | Start FPS monitoring |
| stop() | Stop FPS monitoring |
| clear() | Clear all historical data and counters |

| Property | Type | Description |
|----------|------|-------------|
| isRunning | bool | Whether monitoring is currently active |
| currentFps | double | Current FPS (updated every 500ms) |
| jankRate | double | Jank rate as percentage |
| totalFrameCount | int | Total frames captured |
| totalJankyCount | int | Total janky frames captured (>16ms) |
| lastFrameJanky | bool | Whether the most recent frame was janky |
| fpsHistory | `List<double>` | Recent 60 FPS values (unmodifiable) |
| frameRecords | `List<FrameRecord>` | Recent frame records (unmodifiable, up to 3600) |

### runInspectorApp

A helper function to run your app with the inspector Zone, enabling automatic print() capture.

```dart
runInspectorApp(VoidCallback appRunner)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| appRunner | VoidCallback | The function to run your app (usually `runApp`) |

## Contributing

Contributions are welcome! Please read the [Contributing Guidelines](CONTRIBUTING.md) before submitting issues or pull requests.

- 🐛 [Report a Bug](https://github.com/zero-labsco/zero_inspector_kit/issues/new?template=bug_report.md)
- 💡 [Request a Feature](https://github.com/zero-labsco/zero_inspector_kit/issues/new?template=feature_request.md)
- 💬 [Join Discussions](https://github.com/zero-labsco/zero_inspector_kit/discussions)
- 📖 [Contributing Guide](CONTRIBUTING.md)

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.
