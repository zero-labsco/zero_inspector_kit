# Zero Inspector Kit

<div align="center">

**English** &nbsp;|&nbsp; [简体中文](README_zh.md)

</div>

A powerful Flutter plugin for an in-app developer console, providing real-time debugging tools: network inspection, logging, database viewing, memory monitoring, FPS monitoring, and route tracking.

[![pub version](https://img.shields.io/pub/v/zero_inspector_kit.svg)](https://pub.dev/packages/zero_inspector_kit)
[![pub points](https://img.shields.io/pub/points/zero_inspector_kit.svg)](https://pub.dev/packages/zero_inspector_kit/score)
[![CI](https://github.com/zero-labsco/zero_inspector_kit/actions/workflows/ci.yml/badge.svg)](https://github.com/zero-labsco/zero_inspector_kit/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL--3.0-blue.svg)](https://github.com/zero-labsco/zero_inspector_kit/blob/main/LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS-green.svg)](https://pub.dev/packages/zero_inspector_kit)
[![Flutter](https://img.shields.io/badge/Flutter-✓-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-✓-0175C2?logo=dart)](https://dart.dev)
[![Style: effective dart](https://img.shields.io/badge/style-effective_dart-40c4ff.svg)](https://pub.dev/packages/effective_dart)

> **🔔 Upgrade recommended:** v1.5.0 enhances the log viewer with auto-scroll (pausable), regex search, tag filtering and one-tap copy of a single log entry — so you can locate and reuse logs faster than ever (no breaking changes). All users are advised to upgrade to `^1.5.0`.

🌐 **[Official Website](https://www.zerolabsco.com/)** &nbsp;·&nbsp; 📦 **[View on pub.dev](https://pub.dev/packages/zero_inspector_kit)** &nbsp;·&nbsp; 🔗 **[View on GitHub](https://github.com/zero-labsco/zero_inspector_kit)**

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
  - [Zero-Invasion Integration](#zero-invasion-integration-recommended)
  - [Logging](#logging)
  - [Network Requests](#network-requests)
  - [Network Interceptor](#network-request-interceptor)
  - [Database Provider](#database-provider)
  - [Memory Monitor](#memory-monitor)
  - [FPS Monitor](#fps-monitor)
  - [Custom Database Provider](#custom-database-provider)
  - [Widget Inspector & Network Timeline](#widget-inspector--network-timeline-off-by-default)
- [API Reference](#api-reference)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Zero-Invasion Integration** — One line of code, no changes to existing project code.
- **Network Inspector** — Real-time capture of all HTTP (http & Dio) requests; modify bodies/headers via interceptor rules; batch cURL copy; sensitive-header masking; filterable by method/status/interception.
- **Logging System** — Auto-captures `print()`, Flutter errors, and custom logs across multiple levels; integrates with third-party log libraries; auto-scroll (pausable), regex search, tag filtering and one-tap copy of a single log entry.
- **Database Viewer** — Inspect SQLite and other databases via custom providers.
- **Memory Monitor** — Trend chart, Dart Heap, Native memory breakdown, leak detection, image-cache & storage stats (master switch to avoid overhead).
- **FPS Monitor** — Real-time FPS, jank detection, trend chart, frame records (master switch to avoid overhead).
- **Route Tracker** — Navigation history and current route.
- **Alert System** — Rule-based alerts on network/logs/memory/FPS with unread badge and throttling.
- **Floating Button** — Breathing-animation overlay button that auto-docks to screen edges, avoiding back-gesture conflicts.
- **Modern UI** — Dark theme with gradients and centralized, customizable colors.
- **Cross-Platform** — Android and iOS.

---

## Installation

### Pub.dev (Recommended)

```yaml
dependencies:
  zero_inspector_kit: ^1.5.0
```

### GitHub

```yaml
dependencies:
  zero_inspector_kit:
    git:
      url: https://github.com/zero-labsco/zero_inspector_kit.git
      ref: release/v1.5.0   # replace 1.5.0 with the version you need
```

---

## Usage

### Zero-Invasion Integration (Recommended)

Integrate with just **1 line of code**, no need to modify any existing project code:

```dart
import 'package:flutter/material.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  // Single line: init inspector, capture print() via Zone, show floating button
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

**What the inspector does automatically (no other code changes):**

| Capability | How |
|------------|-----|
| ✅ Log Capture | All `print()` / `debugPrint()` calls and Flutter errors via Zone |
| ✅ Network Interception | All **http** & **Dio** requests via `HttpOverrides` (Dio uses `HttpClient`) |
| ✅ Database Scan | Auto-scans and registers SQLite databases |
| ✅ Floating Button | Shown via `Overlay`, no manual widget needed |
| ✅ Route Tracking | Via `InspectorRouteObserver` (auto-injected into `MaterialApp`) |

**Production Build:** The inspector is automatically disabled in release mode — tree-shaking removes all related code, so you never need to delete anything.

### Manual Integration (More Control)

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';

void main() async {
  // 1) Manual init (more control than the one-line helper)
  ZeroInspectorKit.init(
    enableWidgetInspector: true,   // optional: pre-enable Widget Inspector
    enableNetworkTimeline: true,   // optional: pre-enable Network Timeline
  );

  // 2) Register custom data sources (one-line API)
  final prefs = await SharedPreferences.getInstance();
  ZeroInspectorKit.registerSharedPrefs(SharedPreferencesAdapter(prefs));

  final settings = await Hive.openBox('settings');
  final cache = await Hive.openBox('cache');
  ZeroInspectorKit.registerHive({
    'settings': HiveBoxAdapter(settings),
    'cache': HiveBoxAdapter(cache),
  });

  // 3) Wrap your app
  runApp(ZeroInspectorKit.wrapApp(const MyApp()));
}
```

> **About dependencies:** the plugin itself doesn't need `shared_preferences` / `hive`; **your app** must still add them to its own `pubspec.yaml` if it wants to inspect these. Both appear under the **Database** tab and reuse the same browse/export flow as SQLite.

<details>
<summary>Prefer the raw API? Register the providers yourself.</summary>

```dart
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

void main() {
  ZeroInspectorKit.init();
  DatabaseRegistry.instance.registerProvider(SharedPrefsProvider(prefs: prefs));
  DatabaseRegistry.instance.registerProvider(HiveProvider(box: box, name: 'settings'));
  runApp(ZeroInspectorKit.wrapApp(const MyApp()));
}
```

</details>

### Logging

Start automatic capture from multiple sources:

```dart
InspectorLogInterceptor.instance.start();
```

**Auto-captured:** `print()` / `debugPrint()`, Flutter framework errors, and `runZonedGuarded` exceptions.

**Manual logging (optional):**

```dart
InspectorLog.v('Verbose'); InspectorLog.d('Debug');
InspectorLog.i('Info');    InspectorLog.w('Warning');
InspectorLog.e('Error');
```

Third-party libraries that log via `print()`/`debugPrint()` (e.g. `logger`, `flutter_logger`) are captured automatically — no config needed. Use `onLogCaptured` to sync captured logs back into your own logging service:

```dart
import 'package:logger/logger.dart';
final logger = Logger();

InspectorLogInterceptor.instance.onLogCaptured = (entry) {
  logger.log(_mapLogLevel(entry.level),
    '${entry.tag != null ? '[${entry.tag}] ' : ''}${entry.message}');
};
```

### Network Requests

All HTTP requests (both **http** and **Dio**) are intercepted via `HttpOverrides` automatically after init — no setup required.

```dart
import 'package:http/http.dart' as http;
final r = await http.get(Uri.parse('https://api.example.com/data')); // captured
```

```dart
import 'package:dio/dio.dart';
final dio = Dio();
final r = await dio.get('https://api.example.com/data'); // captured
```

> **Note:** Dio uses `IOHttpClientAdapter` (which uses `dart:io`'s `HttpClient`), so it is captured automatically without extra config.

### Network Request Interceptor

Modify requests via rules — useful for testing parameters without touching app code.

**Workflow:** send a request → open detail → tap the interceptor icon → configure rule (URL pattern, method, body/header edits) → save. Subsequent matching requests use the modified parameters.

| Aspect | Detail |
|--------|--------|
| Supported edits | Request body & headers (POST/PUT/PATCH only) |
| GET requests | View-only, cannot be modified (no body) |
| Rule matching | Exact or regex URL pattern; method filter (GET/POST/PUT/DELETE/PATCH/HEAD/Any) |

When no rules are configured or they are disabled, all requests are sent unmodified.

### Database Provider

```dart
DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
```

### Memory Monitor

Comprehensive analysis with a master switch (off by default to avoid overhead).

- **Master Switch:** top toggle in the Memory panel; off = no timers / no VM Service connection.
- **Trend Chart:** 2-minute window (240 snapshots × 500ms), switchable across Process RSS / Dart Heap / New Space / Old Space.
- **Dart Heap (needs VM Service):** usage/capacity/external bars; new/old-space breakdown; manual GC trigger.
- **Native Memory (real devices):** Android PSS breakdown; iOS physical footprint/compressed/RSS; low-memory warning.
- **Leak Detection (Dart 2.17+ `WeakReference`):** `trackObject()` four-state flow; auto-GC verification; UI shows suspected/tracking/released objects.

```dart
myBloc.trackMemoryLeak(tag: 'HomePage_myBloc');   // shorthand
// or: trackMemoryLeak(myBloc, tag: 'HomePage_myBloc');
myBloc.untrackMemoryLeak();                        // cancel
MemoryInspectorService.instance.clearLeakRecords(); // clear all
```

- **Image Cache:** live size/count, pending vs live, usage bar, one-click clear.
- **App Storage:** documents / temp / DB size, one-click temp clear.

> **⚠️ VM Service availability:** when debugging via `flutter run` on PC, Dart VM Heap may show `VM: OFF` (port-forwarding quirk). Native memory and process RSS still work. Opening the debug app directly on-device shows Heap data correctly.

### FPS Monitor

Real-time frame analysis with a master switch (off by default).

- **Master Switch:** top toggle; off = no timings callback, zero overhead.
- **Metrics:** current FPS, jank rate, total frames, 30-second trend chart (60 points), janky-frame list (>16ms).
- **Accuracy (since v1.2.1):** uses real `buildStart` timestamps (not `DateTime.now()`) and `rasterFinish - buildStart` duration, catching GPU raster jank.

```dart
FpsService.instance.start();
final fps = FpsService.instance.currentFps;
final jank = FpsService.instance.jankRate;
FpsService.instance.clear();
```

### Custom Database Provider

Implement `DatabaseProvider` for other databases:

```dart
class MyCustomDatabaseProvider implements DatabaseProvider {
  @override
  String get name => 'CustomDB';

  @override
  Future<List<DatabaseInfo>> getDatabases() async => [];

  @override
  Future<QueryResult> queryTable(String dbPath, String tableName, {int limit = 50}) async =>
      QueryResult(columns: [], rows: []);
}

DatabaseRegistry.instance.registerProvider(MyCustomDatabaseProvider());
```

### Widget Inspector & Network Timeline (off by default)

Both are **off by default** and toggled via a panel switch (like Memory), so no overhead until enabled. Pre-enable at startup:

```dart
ZeroInspectorKit.runAppWithInspector(
  const MyApp(),
  enableWidgetInspector: true,   // one-shot tree snapshot + breadcrumb navigation
  enableNetworkTimeline: true,   // live request waterfall
);
```

- **Widget Inspector:** one-shot snapshot browsed via breadcrumb navigation (not live; tap Refresh to re-snapshot).
- **Network Timeline:** live waterfall of requests, no manual refresh.

---

## API Reference

### FloatingInspectorButton

| Parameter | Type | Description |
|-----------|------|-------------|
| `enabled` | `bool` | Whether the inspector is enabled (default: `true`, auto-disabled in release) |

### ConditionalInspector

Auto shows/hides the inspector based on build mode.

```dart
ConditionalInspector(child: YourAppWidget())
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `child` | `Widget` | The child widget |
| `enabled` | `bool` | Whether the inspector is enabled (default: `true`) |

### InspectorLogInterceptor

| Method | Description |
|--------|-------------|
| `start()` / `stop()` | Start / stop capturing logs |
| `log(level, message, tag)` | Add a log entry |
| `verbose/debug/info/warning/error(message, tag)` | Add a log at the given level |

| Property | Type | Description |
|----------|------|-------------|
| `onLogCaptured` | `void Function(LogEntry)?` | Callback for third-party log integration |

### InspectorLog

Shorthand wrapper around `InspectorLogInterceptor.instance`.

| Method | Description |
|--------|-------------|
| `start()` / `stop()` | Start / stop capturing logs |
| `log(level, message, {tag})` | Add a log entry |
| `v/d/i/w/e(message, {tag})` | Add a log at the given level |

| Property | Type | Description |
|----------|------|-------------|
| `isRunning` | `bool` | Whether log capture is active |

### InspectorRouteObserver

Navigator observer for tracking route changes.

### FpsService

Singleton FPS service extending `ChangeNotifier`.

| Method | Description |
|--------|-------------|
| `start()` / `stop()` | Start / stop monitoring |
| `clear()` | Clear all history and counters |

| Property | Type | Description |
|----------|------|-------------|
| `isRunning` | `bool` | Whether monitoring is active |
| `currentFps` | `double` | Current FPS (every 500ms) |
| `jankRate` | `double` | Jank rate (%) |
| `totalFrameCount` | `int` | Total frames captured |
| `totalJankyCount` | `int` | Total janky frames (>16ms) |
| `lastFrameJanky` | `bool` | Whether the latest frame was janky |
| `fpsHistory` | `List<double>` | Recent 60 FPS values (unmodifiable) |
| `frameRecords` | `List<FrameRecord>` | Recent frame records (unmodifiable, ≤3600) |

### runInspectorApp

Runs your app inside the inspector Zone for automatic `print()` capture.

```dart
runInspectorApp(VoidCallback appRunner)
```

| Parameter | Type | Description |
|-----------|------|-------------|
| `appRunner` | `VoidCallback` | Function to run your app (usually `runApp`) |

---

## Contributing

Contributions are welcome! Please read the [Contributing Guidelines](CONTRIBUTING.md) before submitting issues or pull requests.

- 🐛 [Report a Bug](https://github.com/zero-labsco/zero_inspector_kit/issues/new?template=bug_report.md)
- 💡 [Request a Feature](https://github.com/zero-labsco/zero_inspector_kit/issues/new?template=feature_request.md)
- 💬 [Join Discussions](https://github.com/zero-labsco/zero_inspector_kit/discussions)
- 📖 [Contributing Guide](CONTRIBUTING.md)

---

## License

This project is licensed under the GNU General Public License v3.0 — see the [LICENSE](LICENSE) file for details.

This plugin is licensed under GPL-3.0, which permits commercial use. Any derivative project that modifies this plugin and redistributes it must publish its complete source code under the same license.

This plugin is provided "as is", without warranty of any kind. The author assumes no responsibility or liability for the functionality, security, or any consequences arising from the use of modified versions or derivative projects.
