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
//
// 本示例故意把根组件写成一个 StatelessWidget 壳 ExampleAppShell，内部才是
// MaterialApp —— 这正是「路由追踪穿透」要验证的场景：runAppWithInspector 传入的
// app 不是 MaterialApp 本身，而是被一层壳包着。检查器会穿透该壳、找到真正的
// MaterialApp 并注入 InspectorRouteObserver，无需用户手动接线。
// NOTE: The root here is a StatelessWidget shell (ExampleAppShell) wrapping the
// real MaterialApp. This exercises the route-observer *penetration* path:
// _wrapAppWithRouteObserver drills through the shell, finds the inner MaterialApp
// and injects InspectorRouteObserver automatically.
void main() {
  ZeroInspectorKit.runAppWithInspector(const ExampleAppShell());
}

/// 根壳：一个普通的 StatelessWidget，内部返回 MaterialApp。
/// 用来演示「穿透」—— 检查器不会把它当成 MaterialApp，而是 build 它、
/// 穿透到内部的 MaterialApp 注入路由观察者。
/// A plain StatelessWidget shell wrapping the real MaterialApp. Demonstrates
/// penetration: the inspector builds this shell, finds the inner MaterialApp
/// and injects the route observer.
class ExampleAppShell extends StatelessWidget {
  const ExampleAppShell({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Zero Inspector Kit Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      // 路由演示：命名路由。InspectorRouteObserver 由检查器穿透壳后自动挂到
      // 内部 MaterialApp 的 navigatorObservers，所有 push/pop 都会被 Route
      // tracking 捕获，无需手动接线。
      // Route demo: named routes. InspectorRouteObserver is auto-attached by the
      // inspector after penetrating the shell, so every push/pop is captured by
      // Route tracking with no manual wiring.
      initialRoute: '/',
      routes: {
        '/': (context) => const ExampleHomePage(),
        '/detail': (context) => const ExampleDetailPage(),
      },
    );
  }
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

class _ExampleHomePageState extends State<ExampleHomePage>
    with SingleTickerProviderStateMixin {
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

  // ── WebSocket / gRPC 抓取演示状态 / WS/gRPC capture demo state ──
  bool _wsCaptureOn = false;
  InspectorWebSocket? _activeWs;
  int _wsFramesReceived = 0;

  // ── FPS 动画测试状态 / FPS animation test state ──
  late final AnimationController _fpsAnim;
  bool _fpsAnimPlaying = false;

  @override
  void initState() {
    super.initState();
    _wsCaptureOn = WsInspectorService.instance.isEnabled;
    // 在 zone 内（runApp 之后）初始化插件，确保 binding 也在同一 zone。
    // Initialize plugins inside the zone (after runApp) so the binding is in
    // the same zone as runApp.
    _fpsAnim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _initInspectorData();
  }

  @override
  void dispose() {
    _fpsAnim.dispose();
    super.dispose();
  }

  Future<void> _initInspectorData() async {
    // 演示 SQLite 数据库查看（写入两个示例库并注册提供者）。
    // 独立 try/catch：即使下方 Hive / SharedPreferences 在 iOS 上初始化失败，
    // 也不会阻断示例库的建立，避免 iOS 模拟器里数据库查看器为空。
    try {
      await _seedExampleDatabases();
    } catch (error, stack) {
      debugPrint('Seed example databases failed: $error\n$stack');
    }

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

  // ── WebSocket / gRPC 抓取演示方法 / WS/gRPC capture demo methods ──
  /// 切换 WS/gRPC 抓取开关（与检查器 Network 标签页里的 WS 开关是同一个状态）。
  /// Toggle WS/gRPC capture. This is the same state as the WS switch in the
  /// inspector's Network tab.
  void _toggleWsCapture() {
    WsInspectorService.instance.toggle();
    if (mounted) {
      setState(() => _wsCaptureOn = WsInspectorService.instance.isEnabled);
    }
  }

  /// 打开一个真实 WebSocket（echo 服务器）并收发几帧；开启抓取时这些帧会出现在
  /// 检查器 Network 标签页的 "WS" 记录里。再次点击可关闭连接。
  /// Open a real WebSocket (echo server) and exchange a few frames. With capture
  /// ON, those frames appear as a "WS" entry in the inspector's Network tab.
  /// Tapping again closes the connection.
  Future<void> _openWsDemo() async {
    if (_activeWs != null) {
      await _closeWsDemo();
      return;
    }
    try {
      final ws = await InspectorWebSocket.connect(
        'wss://echo.websocket.events',
      );
      if (mounted) setState(() => _activeWs = ws);
      ws.listen(
        (data) {
          if (mounted) setState(() => _wsFramesReceived++);
          debugPrint('WS received: $data');
        },
        onDone: () {
          if (mounted) setState(() => _activeWs = null);
        },
      );
      for (var i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 500));
        ws.add('hello $i from zero_inspector_kit');
      }
      await Future.delayed(const Duration(seconds: 3));
      if (_activeWs == ws) await _closeWsDemo();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('WebSocket demo failed: $e')));
      }
    }
  }

  /// 关闭当前 WebSocket 连接 / Close the active WebSocket connection
  Future<void> _closeWsDemo() async {
    final ws = _activeWs;
    if (mounted) setState(() => _activeWs = null);
    await ws?.close();
  }

  /// 模拟一次 gRPC 调用（抓取开启时才会被记录）。
  /// Simulate a gRPC call (only recorded when capture is enabled).
  void _simulateGrpc() {
    WsInspectorService.instance.recordCall(
      name: 'helloworld.Greeter/SayHello',
      request: '{"name":"zero"}',
      response: '{"message":"Hello, zero!"}',
      protocol: 'gRPC',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logged a gRPC call (visible when WS capture is ON)'),
          duration: Duration(seconds: 2),
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

  /// FPS 动画测试：开关一个持续旋转的动画。旋转时引擎每帧都渲染，FPS 监控应读到
  /// ~60（或设备刷新率）；停止后页面静止，FPS 会因无帧可渲染而掉到个位数/0。
  /// FPS animation test: toggle a continuously spinning widget. While spinning, the
  /// engine renders every frame so the FPS monitor should read ~60 (or the device
  /// refresh rate); once stopped the page is static and FPS drops because no frames
  /// are produced.
  void _toggleFpsAnim() {
    setState(() {
      _fpsAnimPlaying = !_fpsAnimPlaying;
      if (_fpsAnimPlaying) {
        _fpsAnim.repeat();
      } else {
        _fpsAnim.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zero Inspector Kit')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'The root here is a StatelessWidget shell (ExampleAppShell) wrapping '
            'the real MaterialApp — this exercises the route-observer '
            'penetration path. Navigate below and watch the captured-route '
            'counter (it proves the observer was injected through the shell).',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Requests sent: $_requestCount',
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          // 实时显示「检查器已捕获的路由数」。若穿透成功，进入 /detail 再返回
          // 后计数会增加；若始终为 0，说明穿透回退、路由追踪未生效。
          // Live count of routes captured by the inspector. If penetration
          // succeeded, this grows after navigating; if it stays 0, the fallback
          // path was taken and route tracking did not engage.
          const _RouteCaptureIndicator(),
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
          // FPS 动画测试：开关一个持续旋转的方块。旋转时引擎每帧渲染，FPS 监控应
          // 读到 ~60；停止后页面静止，FPS 会因无帧可渲染而掉到个位数/0。
          // FPS animation test: toggle a continuously spinning box. While spinning the
          // engine renders every frame (FPS ~60); stopped, the page is idle and FPS
          // drops because no frames are produced.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'FPS animation test',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open the inspector → FPS tab, then toggle the spin below. '
                  'While spinning, FPS should read ~60; once stopped (page idle) '
                  'FPS drops — there is nothing left to render.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    RotationTransition(
                      turns: _fpsAnim,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.purple,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.autorenew,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleFpsAnim,
                        icon: Icon(
                          _fpsAnimPlaying
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                        ),
                        label: Text(
                          _fpsAnimPlaying ? 'Stop spinning' : 'Start spinning',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pushNamed('/detail'),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Open detail page (route demo)'),
          ),
          const SizedBox(height: 16),
          // WebSocket / gRPC 抓取演示：开启抓取后开一个真实 WebSocket 或模拟一次
          // gRPC 调用，即可在检查器的 Network 标签页看到 WS / gRPC 记录。
          // WS/gRPC capture demo: turn capture on, then open a real socket or
          // simulate a gRPC call to see WS / gRPC entries in the Network tab.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'WebSocket / gRPC capture demo',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Open the inspector → Network tab and flip the WS switch ON, '
                  'then open a socket below to see a "WS" entry with frames. '
                  'Or simulate a gRPC call (logged when capture is ON).',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _openWsDemo,
                        icon: Icon(
                          _activeWs == null ? Icons.cable : Icons.stop,
                        ),
                        label: Text(
                          _activeWs == null
                              ? 'Open WebSocket echo'
                              : 'Close WebSocket',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _simulateGrpc,
                        icon: const Icon(Icons.bolt),
                        label: const Text('Simulate gRPC'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('WS capture: ${_wsCaptureOn ? 'ON' : 'OFF'}'),
                    const SizedBox(width: 8),
                    Switch(
                      value: _wsCaptureOn,
                      onChanged: (_) => _toggleWsCapture(),
                    ),
                    const Spacer(),
                    Text('Frames received: $_wsFramesReceived'),
                  ],
                ),
              ],
            ),
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

  /// 一个用于 Widget 检查器演示的嵌套组件树：
  /// - 带 Key，方便观察节点信息；
  /// - 显式设置**颜色**（`ColoredBox` / `Container` 的 color）与**固定尺寸**
  ///   （`SizedBox` / `width`+`height`），让检查器首屏就能在详情里看到颜色色块
  ///   与渲染尺寸数据；
  /// - 含 `padding` / `alignment` 等布局属性，演示视觉/布局属性提取；
  /// - **刻意做出多种不同尺寸**（横幅、卡片、小方块、圆形点），方便在 Widget
  ///   检查器里下钻时直观看到每个节点的 size 各不相同——而不是整棵树都接近
  ///   屏宽的 441.4×918.9。
  /// 打开 Widget 检查器，点开 "Widget Inspector demo tree" 下钻即可看到。
  ///
  /// A nested tree for the Widget Inspector demo:
  /// - has Keys so node info is meaningful;
  /// - sets explicit **color** (`ColoredBox` / `Container` color) and **fixed
  ///   size** (`SizedBox` / `width`+`height`) so the inspector shows the color
  ///   swatch and rendered size right away;
  /// - carries `padding` / `alignment` etc. to demo visual/layout extraction;
  /// - **deliberately mixes many sizes** (banner, cards, small squares, a dot)
  ///   so drilling in the Widget Inspector shows each node's size differs —
  ///   rather than the whole tree being near the screen-wide 441.4×918.9.
  /// Open the Widget Inspector, expand "Widget Inspector demo tree" and drill.
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
          const Text(
            'Open the Widget Inspector (tab above) and drill into the nodes '
            'below. Each has a different rendered size — e.g. the red card is '
            '160×48 while the small dot is only 24×24, so you can watch the '
            'size change as you go deeper.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          // 撑满宽度的横幅：高度 72，颜色橙。尺寸不等于屏宽但接近屏宽，用来
          // 演示"接近整屏"与"固定尺寸"的差异。
          // Full-width banner: 72 tall, orange. Shows "near full width" vs the
          // fixed-size boxes below.
          Container(
            key: const Key('bannerBox'),
            width: double.infinity,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFF9500),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Banner · full width × 72',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          // 固定的红色卡片：尺寸 160 × 48，颜色红。检查器里可见 size 与 color。
          // Fixed red card: 160 × 48, red. Inspector shows size and color.
          Container(
            key: const Key('redBox'),
            width: 160,
            height: 48,
            color: const Color(0xFFFF3B30),
            alignment: Alignment.center,
            child: const Text(
              'Container · red · 160×48',
              style: TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          // ColoredBox：更鲜明的绿色背景，尺寸由内容撑开（无固定宽高）。
          // ColoredBox: a vivid green background, size driven by content.
          ColoredBox(
            key: const Key('greenBox'),
            color: const Color(0xFF34C759),
            child: const Padding(
              key: Key('greenBoxPadding'),
              padding: EdgeInsets.all(16),
              child: Text('ColoredBox · green · sized by content'),
            ),
          ),
          const SizedBox(height: 8),
          // 固定尺寸的蓝色块。
          // Fixed-size blue box.
          SizedBox(
            key: const Key('blueBox'),
            width: 200,
            height: 40,
            child: Container(
              key: const Key('blueInner'),
              color: const Color(0xFF007AFF),
              alignment: Alignment.center,
              child: const Text(
                'SizedBox 200×40 · blue',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 圆形小点：仅 24 × 24，演示"很小"的节点尺寸，方便对比 size 变化。
          // A tiny dot: only 24 × 24, to contrast strongly against the others.
          Container(
            key: const Key('dotBox'),
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Color(0xFFAF52DE),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

/// 实时显示「检查器已捕获的路由数」的小部件。
/// 监听 [InspectorService]（ChangeNotifier），每次路由 push/pop 都会触发重建，
/// 让用户无需打开面板也能直观确认穿透注入是否成功。
/// A small live widget showing how many routes the inspector has captured.
/// Listens to [InspectorService] (a ChangeNotifier) so it rebuilds on every
/// route push/pop, letting the user verify penetration without opening the panel.
class _RouteCaptureIndicator extends StatelessWidget {
  const _RouteCaptureIndicator();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: InspectorService.instance,
      builder: (context, _) {
        final count = InspectorService.instance.routeEntryCount;
        final color = count > 0 ? Colors.green : Colors.grey;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.route_outlined, color: color, size: 18),
            const SizedBox(width: 8),
            // 用 Flexible 约束文字宽度，避免窄屏或系统大字体下整行溢出。
            // Flexible bounds the text width so the row never overflows on
            // narrow screens or with large system fonts.
            Flexible(
              child: Text(
                'Routes captured by inspector: $count',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: color),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    );
  }
}
