import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

// 一行启动检查器：binding 与后续所有插件初始化都在 runAppWithInspector 内部的
// zone 内进行（首次 ensureInitialized 由 runApp 触发），避免在 zone 外初始化
// 导致 "Zone mismatch" 断言。
// One-line launcher: the binding and all plugin initialization happen inside
// runAppWithInspector's zone (the first ensureInitialized is triggered by
// runApp), so nothing is initialized in the outer zone → no "Zone mismatch".
// 注意：runAppWithInspector 仅在传入的 app 是 MaterialApp 时才会自动注入
// InspectorRouteObserver（见 zero_inspector_kit.dart 的 _wrapAppWithRouteObserver）。
// 因此这里直接传入 MaterialApp（而非包了一层的 StatelessWidget），route 演示
// 才可被 Route tracking 捕获。
// NOTE: runAppWithInspector injects InspectorRouteObserver only when the passed
// app is a MaterialApp (see _wrapAppWithRouteObserver). So we pass a MaterialApp
// directly here (not a wrapping StatelessWidget) so the route demo is captured.
void main() {
  ZeroInspectorKit.runAppWithInspector(
    MaterialApp(
      title: 'Zero Inspector Kit Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // 路由演示：命名路由。InspectorRouteObserver 会在 runAppWithInspector
      // 内部自动挂到 navigatorObservers，所有 push/pop 都会被 Route tracking
      // 捕获，无需手动接线。
      // Route demo: named routes. InspectorRouteObserver is auto-attached inside
      // runAppWithInspector, so every push/pop is captured by Route tracking with
      // no manual wiring.
      initialRoute: '/',
      routes: {
        '/': (context) => const MyApp(),
        '/detail': (context) => const ExampleDetailPage(),
      },
    ),
  );
}

Future<void> _seedExampleDatabases() async {
  final dir = await getDatabasesPath();
  for (final name in ['example1.db', 'example2.db']) {
    final path = '$dir/$name';
    final db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            value REAL,
            created_at TEXT
          )
        ''');
        for (var i = 0; i < 20; i++) {
          await db.insert('items', {
            'name': 'Item $i',
            'value': i * 1.5,
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      },
    );
    await db.close();
  }
  // 注册 SQLite 提供者（示例中展示数据库查看器用法）。
  DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const ExampleHomePage();
  }
}

/// 路由演示用的二级页面 / A second-level page for the route demo.
class ExampleDetailPage extends StatelessWidget {
  const ExampleDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Page')),
      body: const Center(
        child: Text(
          'You navigated here via a named route (/detail).\n'
          'Open the inspector\'s Route tracking to see this push/pop.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

/// 一组用于演示的示例请求定义：涵盖不同 HTTP 方法、URL 与预期状态码。
/// A set of demo requests: different HTTP methods, URLs and expected codes.
class _DemoRequest {
  const _DemoRequest(this.method, this.url, this.label);
  final String method;
  final String url;
  final String label;
}

const List<_DemoRequest> _demoRequests = [
  _DemoRequest(
    'GET',
    'https://jsonplaceholder.typicode.com/posts/1',
    'GET · 200',
  ),
  _DemoRequest(
    'GET',
    'https://jsonplaceholder.typicode.com/posts/99999',
    'GET · 404',
  ),
  _DemoRequest(
    'POST',
    'https://jsonplaceholder.typicode.com/posts',
    'POST · 201',
  ),
  _DemoRequest(
    'PUT',
    'https://jsonplaceholder.typicode.com/posts/1',
    'PUT · 200',
  ),
  _DemoRequest(
    'DELETE',
    'https://jsonplaceholder.typicode.com/posts/1',
    'DELETE · 200',
  ),
];

class ExampleHomePage extends StatefulWidget {
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  final _httpClient = HttpClient();
  int _requestCount = 0;

  // 第三方 logger 演示用的实例（懒创建），与"检查器日志"完全解耦。
  // Lazily-created instance for the third-party logger demo, fully decoupled
  // from the inspector's own logs.
  Logger? _logger;
  // 是否开启了"检查器 → logger"转发。只在用户显式开关时才设置全局回调，
  // 关闭时复位为 null，避免污染后续所有日志捕获。
  // Whether "inspector → logger" forwarding is on. The global callback is only
  // set while the toggle is on, and reset to null when off, so it never leaks
  // into unrelated log captures.
  bool _forwardingToLogger = false;

  @override
  void initState() {
    super.initState();
    // 在 zone 内（runApp 之后）初始化插件，确保 binding 也在同一 zone。
    // Initialize plugins inside the zone (after runApp) so the binding is in
    // the same zone as runApp.
    _initInspectorData();
  }

  Future<void> _initInspectorData() async {
    try {
      // 演示「自定义数据库源」一行注册 API（SharedPreferences / Hive）。
      final prefs = await SharedPreferences.getInstance();
      ZeroInspectorKit.registerSharedPrefs(SharedPreferencesAdapter(prefs));

      // Hive 必须先初始化目录（否则 Hive.openBox 会抛 HiveError）。
      final appDir = await getApplicationDocumentsDirectory();
      Hive.init(appDir.path);

      final settingsBox = await Hive.openBox('settings');
      await settingsBox.putAll({
        'theme': 'dark',
        'notifications': true,
        'lastSync': DateTime.now().toIso8601String(),
      });
      final cacheBox = await Hive.openBox('cache');
      await cacheBox.put('user_profile', {'name': 'Zero', 'vip': 1});
      ZeroInspectorKit.registerHive({
        'settings': HiveBoxAdapter(settingsBox),
        'cache': HiveBoxAdapter(cacheBox),
      });

      // 演示 SQLite 数据库查看（写入两个示例库并注册提供者）。
      await _seedExampleDatabases();
    } catch (error, stack) {
      debugPrint('Inspector data init failed: $error\n$stack');
    }
  }

  Future<void> _sendAllDemoRequests() async {
    for (final demo in _demoRequests) {
      try {
        late HttpClientRequest request;
        switch (demo.method) {
          case 'POST':
            request = await _httpClient.postUrl(Uri.parse(demo.url))
              ..write('{"title":"demo","body":"hello","userId":1}');
          case 'PUT':
            request = await _httpClient.putUrl(Uri.parse(demo.url))
              ..write('{"title":"demo","body":"updated","userId":1}');
          case 'DELETE':
            request = await _httpClient.deleteUrl(Uri.parse(demo.url));
          default:
            request = await _httpClient.getUrl(Uri.parse(demo.url));
        }
        final response = await request.close();
        await response.drain();
        if (mounted) {
          setState(() {
            _requestCount++;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _requestCount++;
          });
        }
      }
    }
  }

  /// 演示日志查看器：通过 InspectorLogInterceptor 输出各层级、不同 tag 的日志，
  /// 并故意抛出一个被捕获的异常（连同 stack），方便在 Log 查看器里演示分级、
  /// 搜索与按 tag 筛选。
  /// Demo the Log viewer: emit logs of every level with different tags via
  /// InspectorLogInterceptor, plus a caught exception (with stack) so the Log
  /// viewer can demo level filtering, search, and tag grouping.
  void _emitDemoLogs() {
    InspectorLog.v('Bootstrap sequence started', tag: 'lifecycle');
    InspectorLog.d('Hydrating cached config from disk', tag: 'cache');
    InspectorLog.i('User session restored (uid=1024)', tag: 'auth');
    InspectorLog.i('Fetched 12 items from remote API', tag: 'network');
    InspectorLog.w('Slow response: /feed took 1820ms', tag: 'network');
    InspectorLog.w('Token expires in 90s, will refresh soon', tag: 'auth');
    InspectorLog.e('Failed to decode push payload', tag: 'push');
    try {
      throw StateError('Simulated crash in background sync');
    } catch (error, stack) {
      InspectorLog.e('Background sync error: $error\n$stack', tag: 'sync');
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emitted demo logs — open the Log viewer'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 演示第三方日志库集成：使用 `logger` 包（pub.dev 上的 logger 2.x）输出日志。
  /// 检查器会自动通过 print() 捕获这些日志（归类为 Info 级别），无需任何配置。
  /// 本函数只负责"logger → 检查器"这一段（单向），不触碰全局转发状态，
  /// 因此与 _emitDemoLogs 完全互不影响。
  /// Demo third-party logger integration: emit logs via the `logger` package.
  /// The inspector auto-captures them through print() (classified as Info), no
  /// config needed. This only covers the "logger → inspector" direction and
  /// never touches the global forwarding state, so it is fully independent of
  /// _emitDemoLogs.
  void _emitLoggerLogs() {
    final logger = _logger ??= Logger(
      printer: PrettyPrinter(methodCount: 0, errorMethodCount: 3),
    );
    logger.t('logger verbose: lazy-loaded feature flags');
    logger.d('logger debug: cache hit ratio = 0.87');
    logger.i('logger info: order #8852 created');
    logger.w('logger warning: retry 2/3 after timeout');
    logger.e(
      'logger error: payment gateway returned 503',
      error: 'gateway_unavailable',
      stackTrace: StackTrace.current,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Emitted logger logs — auto-captured by Log viewer'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// 切换"检查器 → logger"转发开关。开启时设置一次全局回调，关闭时复位为
  /// null，确保不影响其它演示（例如 demo 日志）的捕获行为。
  /// Toggle the "inspector → logger" forwarding switch. When on, install the
  /// global callback once; when off, reset it to null so other demos (e.g. demo
  /// logs) are unaffected.
  void _toggleLoggerForwarding() {
    final logger = _logger ??= Logger(
      printer: PrettyPrinter(methodCount: 0, errorMethodCount: 3),
    );
    setState(() {
      _forwardingToLogger = !_forwardingToLogger;
    });
    if (_forwardingToLogger) {
      InspectorLog.onLogCaptured = (entry) {
        // 用 level.name 判断级别（无需直接引用插件的 LogLevel 类型）。
        // Use level.name to avoid importing the internal LogLevel type.
        final lvl = entry.level.name == 'error' ? Level.error : Level.info;
        logger.log(lvl, '[inspector] ${entry.message}');
      };
    } else {
      // 关闭时清除回调，避免永久污染后续日志捕获。
      // Clear the callback when off so it never leaks into later captures.
      InspectorLog.onLogCaptured = null;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _forwardingToLogger
                ? 'Forwarding inspector logs → logger: ON'
                : 'Forwarding inspector logs → logger: OFF',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// 触发一次强制掉帧：在 UI 线程做一段同步重计算，制造可见的 jank，
  /// 让 FPS 监控页能看到掉帧标记与 FPS 抖动。
  /// Force a jank: a blocking synchronous computation on the UI thread so the
  /// FPS monitor records a dropped frame and FPS dip.
  void _triggerJank() {
    final sw = Stopwatch()..start();
    var sink = 0;
    while (sw.elapsedMilliseconds < 120) {
      for (var i = 0; i < 100000; i++) {
        sink += (i * 31) ~/ 7;
      }
    }
    debugPrint('jank workload done (result=$sink)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zero Inspector Kit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Open the inspector panel from the floating button, then try the '
            'buttons below. Open the Widget Inspector to snapshot the nested '
            'widget tree, or Route tracking to watch navigation.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Requests sent: $_requestCount',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _sendAllDemoRequests,
            icon: const Icon(Icons.cloud_download),
            label: const Text('Send mixed requests (GET/POST/PUT/DELETE)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _emitDemoLogs,
            icon: const Icon(Icons.message_outlined),
            label: const Text('Emit demo logs (see Log viewer)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _emitLoggerLogs,
            icon: const Icon(Icons.library_books_outlined),
            label: const Text('Emit logger logs (3rd-party)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _toggleLoggerForwarding,
            icon: Icon(
              _forwardingToLogger
                  ? Icons.link_off_outlined
                  : Icons.link_outlined,
            ),
            style: _forwardingToLogger
                ? ElevatedButton.styleFrom(backgroundColor: Colors.orange)
                : null,
            label: Text(
              _forwardingToLogger
                  ? 'Forward inspector logs → logger: ON'
                  : 'Forward inspector logs → logger: OFF',
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _triggerJank,
            icon: const Icon(Icons.speed),
            label: const Text('Trigger a jank (see FPS monitor)'),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/detail'),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Open detail page (route demo)'),
          ),
          const SizedBox(height: 16),
          // Widget 检查器演示：带 Key 的嵌套组件树，打开 Widget 检查器即可查看
          // 每个节点的类型、Key、子节点数与层级。
          // Widget inspector demo: a nested tree with Keys — open the Widget
          // Inspector to inspect each node's type, Key, child count and depth.
          _buildWidgetDemoTree(),
        ],
      ),
    );
  }

  /// 一个有代表性的嵌套组件树，带有 GlobalKey / ValueKey / Key，
  /// 方便在 Widget 检查器中观察节点信息。
  /// A representative nested widget tree with GlobalKey / ValueKey / Key so the
  /// Widget Inspector shows meaningful node details.
  Widget _buildWidgetDemoTree() {
    return Container(
      key: const Key('widgetDemoContainer'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Column(
        key: const Key('widgetDemoColumn'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Widget Inspector demo tree',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          ListView.builder(
            key: const Key('widgetDemoList'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) => ListTile(
              key: ValueKey('item_$index'),
              leading: const Icon(Icons.widgets_rounded),
              title: Text('Nested card #$index'),
              subtitle: Text('key=item_$index'),
            ),
          ),
        ],
      ),
    );
  }
}
