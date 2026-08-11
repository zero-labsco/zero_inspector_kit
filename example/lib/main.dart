import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';
import 'package:logger/logger.dart';

void main() {
  // 零侵入集成：一行代码启用所有检查器功能 / Zero-invasion: one line enables all inspector features
  // http 包和 Dio 用户均无需额外配置 / No extra config needed for http package and Dio users
  ZeroInspectorKit.runAppWithInspector(MaterialApp(home: const HomePage()));
}

/// 主页 / Home page
/// 展示所有检查器功能的示例 / Show examples of all inspector features
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  /// Dio 实例用于发送网络请求 / Dio instance for sending network requests
  /// 通过 HttpOverrides 自动捕获，无需额外配置 / Auto-captured via HttpOverrides, no extra configuration needed
  final Dio _dio = Dio();

  /// Logger 实例用于测试第三方日志库集成 / Logger instance for testing third-party log library integration
  late Logger _logger;

  // ==================== FPS 演示状态 / FPS demo state ====================

  /// 掉帧动画控制器（用于大量动画模拟掉帧）/ Jank animation controller (for many animations to simulate jank)
  AnimationController? _jankAnimationController;

  /// 是否启用重动画模式（大量旋转+缩放动画，故意触发掉帧）/ Whether heavy animation mode is on (many rotate+scale animations to intentionally trigger jank)
  bool _heavyAnimationsEnabled = false;

  /// 重动画数量 / Number of heavy animations
  final int _heavyAnimationCount = 80;

  /// 流畅动画控制器（单个轻量动画，演示高 FPS）/ Smooth animation controller (single lightweight animation for high FPS demo)
  AnimationController? _smoothAnimationController;

  /// 是否启用流畅动画模式（演示高 FPS 60 流畅运行）/ Whether smooth animation mode is on (demonstrates high 60 FPS)
  bool _smoothAnimationEnabled = false;

  @override
  void initState() {
    super.initState();

    _verifyOhosPlugin();
    _setupLoggerIntegration();
    _initTestDatabase();
  }

  /// 验证 ohos 原生插件是否被正确打包并调用 / Verify the ohos native plugin is bundled and invoked
  Future<void> _verifyOhosPlugin() async {
    try {
      final version = await ZeroInspectorKitPlatform.instance
          .getPlatformVersion();
      print('[ZeroInspectorKit] getPlatformVersion => $version');
    } catch (e) {
      print('[ZeroInspectorKit] getPlatformVersion failed: $e');
    }
  }

  /// 设置 Logger 日志库集成 / Set up Logger log library integration
  void _setupLoggerIntegration() {
    _logger = Logger(printer: PrettyPrinter(methodCount: 0, printEmojis: true));
  }

  /// 使用 Logger 库输出日志 / Output logs using Logger library
  /// Logger 库通过 print() 输出日志，会被检查器自动捕获 / Logger library outputs via print(), which will be auto-captured by inspector
  void _logWithLogger() {
    _logger.t('Logger trace message');
    _logger.d('Logger debug message');
    _logger.i('Logger info message');
    _logger.w('Logger warning message');
    _logger.e('Logger error message');
    _logger.f('Logger fatal message');
  }

  /// 初始化测试数据库 / Initialize test databases
  /// 创建两个测试数据库用于演示数据库查看器功能 / Create two test databases to demonstrate database viewer functionality
  /// - test_database.db: 包含 users 和 posts 表 / - test_database.db: contains users and posts tables
  /// - test_data.sqlite: 包含 products 和 orders 表 / - test_data.sqlite: contains products and orders tables
  Future<void> _initTestDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      await openDatabase(
        join(dbPath, 'test_database.db'),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              email TEXT,
              age INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE posts (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT,
              content TEXT,
              user_id INTEGER,
              created_at TEXT
            )
          ''');
          await db.insert('users', {
            'name': 'Alice',
            'email': 'alice@example.com',
            'age': 25,
          });
          await db.insert('users', {
            'name': 'Bob',
            'email': 'bob@example.com',
            'age': 30,
          });
          await db.insert('users', {
            'name': 'Charlie',
            'email': 'charlie@example.com',
            'age': 35,
          });
          await db.insert('posts', {
            'title': 'First Post',
            'content': 'Hello World!',
            'user_id': 1,
            'created_at': '2024-01-01',
          });
          await db.insert('posts', {
            'title': 'Second Post',
            'content': 'Flutter is awesome',
            'user_id': 2,
            'created_at': '2024-01-02',
          });
        },
      );

      await openDatabase(
        join(dbPath, 'test_data.sqlite'),
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE products (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT,
              price REAL,
              stock INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE orders (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              product_id INTEGER,
              quantity INTEGER,
              total REAL,
              created_at TEXT
            )
          ''');
          await db.insert('products', {
            'name': 'iPhone',
            'price': 5999,
            'stock': 100,
          });
          await db.insert('products', {
            'name': 'iPad',
            'price': 3999,
            'stock': 50,
          });
          await db.insert('products', {
            'name': 'MacBook',
            'price': 12999,
            'stock': 30,
          });
          await db.insert('orders', {
            'product_id': 1,
            'quantity': 2,
            'total': 11998,
            'created_at': '2024-01-03',
          });
          await db.insert('orders', {
            'product_id': 2,
            'quantity': 1,
            'total': 3999,
            'created_at': '2024-01-04',
          });
        },
      );

      print('Test databases initialized successfully');
    } catch (e) {
      print('Failed to initialize databases: $e');
    }
  }

  /// 发送 Dio GET 请求 / Send Dio GET request
  /// 请求会通过 HttpOverrides 自动捕获（零侵入）/ Request will be auto-captured via HttpOverrides (zero-invasion)
  Future<void> _makeDioGetRequest() async {
    try {
      await _dio.get('https://jsonplaceholder.typicode.com/posts/1');
      print('Dio GET request completed successfully');
    } catch (e) {
      print('Dio GET request failed: $e');
    }
  }

  /// 发送 Dio POST 请求 / Send Dio POST request
  Future<void> _makeDioPostRequest() async {
    try {
      await _dio.post(
        'https://jsonplaceholder.typicode.com/posts',
        data: {'title': 'foo', 'body': 'bar', 'userId': 1},
      );
      print('Dio POST request completed successfully');
    } catch (e) {
      print('Dio POST request failed: $e');
    }
  }

  /// 发送 Dio PUT 请求 / Send Dio PUT request
  Future<void> _makeDioPutRequest() async {
    try {
      await _dio.put(
        'https://jsonplaceholder.typicode.com/posts/1',
        data: {'title': 'updated title', 'body': 'updated body', 'userId': 1},
      );
      print('Dio PUT request completed successfully');
    } catch (e) {
      print('Dio PUT request failed: $e');
    }
  }

  /// 发送 Dio DELETE 请求 / Send Dio DELETE request
  Future<void> _makeDioDeleteRequest() async {
    try {
      await _dio.delete('https://jsonplaceholder.typicode.com/posts/1');
      print('Dio DELETE request completed successfully');
    } catch (e) {
      print('Dio DELETE request failed: $e');
    }
  }

  /// 发送 Dio PATCH 请求 / Send Dio PATCH request
  Future<void> _makeDioPatchRequest() async {
    try {
      await _dio.patch(
        'https://jsonplaceholder.typicode.com/posts/1',
        data: {'title': 'patched title'},
      );
      print('Dio PATCH request completed successfully');
    } catch (e) {
      print('Dio PATCH request failed: $e');
    }
  }

  /// 发送 Dio HEAD 请求 / Send Dio HEAD request
  Future<void> _makeDioHeadRequest() async {
    try {
      await _dio.head('https://jsonplaceholder.typicode.com/posts/1');
      print('Dio HEAD request completed successfully');
    } catch (e) {
      print('Dio HEAD request failed: $e');
    }
  }

  /// 发送 HTTP GET 请求 / Send HTTP GET request
  /// 直接使用 http 包发送，请求会被 HttpOverrides 自动拦截 / Send directly via http package, request will be auto-intercepted by HttpOverrides
  /// 用户不需要做任何额外配置，零侵入！/ No extra configuration needed, zero-invasion!
  Future<void> _makeHttpGetRequest() async {
    try {
      await http.get(Uri.parse('https://jsonplaceholder.typicode.com/posts/2'));
      print('HTTP GET request completed successfully');
    } catch (e) {
      print('HTTP GET request failed: $e');
    }
  }

  /// 发送 HTTP POST 请求 / Send HTTP POST request
  /// 直接使用 http 包发送，请求会被 HttpOverrides 自动拦截 / Send directly via http package, request will be auto-intercepted by HttpOverrides
  /// 用户不需要做任何额外配置，零侵入！/ No extra configuration needed, zero-invasion!
  Future<void> _makeHttpPostRequest() async {
    try {
      await http.post(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
        body: {'title': 'foo', 'body': 'bar', 'userId': 1},
      );
      print('HTTP POST request completed successfully');
    } catch (e) {
      print('HTTP POST request failed: $e');
    }
  }

  /// 发送 HTTP PUT 请求 / Send HTTP PUT request
  /// 直接使用 http 包发送，请求会被 HttpOverrides 自动拦截 / Send directly via http package, request will be auto-intercepted by HttpOverrides
  Future<void> _makeHttpPutRequest() async {
    try {
      await http.put(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
        body: {'title': 'updated title', 'body': 'updated body', 'userId': 1},
      );
      print('HTTP PUT request completed successfully');
    } catch (e) {
      print('HTTP PUT request failed: $e');
    }
  }

  /// 发送 HTTP DELETE 请求 / Send HTTP DELETE request
  /// 直接使用 http 包发送，请求会被 HttpOverrides 自动拦截 / Send directly via http package, request will be auto-intercepted by HttpOverrides
  Future<void> _makeHttpDeleteRequest() async {
    try {
      await http.delete(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      );
      print('HTTP DELETE request completed successfully');
    } catch (e) {
      print('HTTP DELETE request failed: $e');
    }
  }

  /// 发送 HTTP PATCH 请求 / Send HTTP PATCH request
  /// 直接使用 http 包发送，请求会被 HttpOverrides 自动拦截 / Send directly via http package, request will be auto-intercepted by HttpOverrides
  Future<void> _makeHttpPatchRequest() async {
    try {
      await http.patch(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
        body: {'title': 'patched title'},
      );
      print('HTTP PATCH request completed successfully');
    } catch (e) {
      print('HTTP PATCH request failed: $e');
    }
  }

  /// 发送 HTTP HEAD 请求 / Send HTTP HEAD request
  /// 直接使用 http 包发送，请求会被 HttpOverrides 自动拦截 / Send directly via http package, request will be auto-intercepted by HttpOverrides
  Future<void> _makeHttpHeadRequest() async {
    try {
      await http.head(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/1'),
      );
      print('HTTP HEAD request completed successfully');
    } catch (e) {
      print('HTTP HEAD request failed: $e');
    }
  }

  // ==================== Memory 测试 / Memory Tests ====================

  /// 保存加载的图片引用，防止被 GC 回收 / Keep image references to prevent GC
  final List<Widget> _loadedImages = [];

  /// 加载测试图片（测试图片缓存）/ Load test images (test image cache)
  Future<void> _loadTestImages() async {
    final imageUrls = [
      'https://picsum.photos/200/200?random=1',
      'https://picsum.photos/200/200?random=2',
      'https://picsum.photos/200/200?random=3',
      'https://picsum.photos/200/200?random=4',
      'https://picsum.photos/400/400?random=5',
    ];

    for (final url in imageUrls) {
      try {
        final imageProvider = NetworkImage(url);
        final completer = Completer<void>();
        final stream = imageProvider.resolve(const ImageConfiguration());
        final listener = ImageStreamListener(
          (_, _) {
            if (!completer.isCompleted) {
              completer.complete();
            }
          },
          onError: (error, stackTrace) {
            if (!completer.isCompleted) {
              completer.completeError(error, stackTrace);
            }
          },
        );
        stream.addListener(listener);
        await completer.future;
        _loadedImages.add(Image.network(url, width: 100, height: 100));
      } catch (e) {
        print('Failed to load image: $url - $e');
      }
    }
    print(
      'Loaded ${imageUrls.length} test images (total: ${_loadedImages.length})',
    );
  }

  /// 分配内存（测试堆内存监控）/ Allocate memory (test heap monitoring)
  void _allocateMemory() {
    // 分配约 10MB 的内存 / Allocate approximately 10MB of memory
    final data = List.generate(10000, (_) => List.filled(1000, 'x' * 100));
    print('Allocated ~10MB of memory (${data.length} lists)');
    // 保持引用，防止立即被 GC 回收 / Keep reference to prevent immediate GC
    _memoryHolders.add(data);
  }

  /// 保持内存引用的列表 / List to hold memory references
  final List<dynamic> _memoryHolders = [];

  /// 手动触发 GC / Manually trigger GC
  void _triggerGC() {
    // 清除引用，让 GC 可以回收 / Clear references for GC
    _memoryHolders.clear();
    print('Cleared memory references, GC will collect them');
  }

  // ==================== FPS 演示方法 / FPS demo methods ====================

  /// 切换重动画模式（故意触发掉帧演示）
  /// Toggle heavy animation mode (intentionally triggers jank for demo)
  void _toggleHeavyAnimations() {
    setState(() {
      _heavyAnimationsEnabled = !_heavyAnimationsEnabled;
    });

    if (_heavyAnimationsEnabled) {
      _jankAnimationController ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      )..repeat(reverse: true);
      print('Heavy animations enabled ($_heavyAnimationCount widgets)');
    } else {
      _jankAnimationController?.stop();
      _jankAnimationController?.dispose();
      _jankAnimationController = null;
      print('Heavy animations disabled');
    }
  }

  /// 故意执行密集计算（阻塞主线程 100-500ms）触发掉帧
  /// Intentionally run heavy computation (block main thread 100-500ms) to trigger jank
  void _triggerJankComputation() {
    final stopwatch = Stopwatch()..start();
    final durationMs = 100 + (DateTime.now().microsecondsSinceEpoch % 400);
    // 密集循环计算 / Heavy loop computation
    var sum = 0;
    while (stopwatch.elapsedMilliseconds < durationMs) {
      for (var i = 0; i < 10000; i++) {
        sum += i * i % 7;
      }
    }
    print(
      'Heavy computation done: blocked ${stopwatch.elapsedMilliseconds}ms, sum=$sum',
    );
  }

  /// 切换流畅动画模式（单个轻量动画，演示高 FPS 60 流畅运行）
  /// Toggle smooth animation mode (single lightweight animation, demonstrates high 60 FPS)
  void _toggleSmoothAnimation() {
    setState(() {
      _smoothAnimationEnabled = !_smoothAnimationEnabled;
    });

    if (_smoothAnimationEnabled) {
      _smoothAnimationController ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      )..repeat();
      print('Smooth animation enabled (single lightweight widget)');
    } else {
      _smoothAnimationController?.stop();
      _smoothAnimationController?.dispose();
      _smoothAnimationController = null;
      print('Smooth animation disabled');
    }
  }

  @override
  void dispose() {
    _jankAnimationController?.dispose();
    _jankAnimationController = null;
    _smoothAnimationController?.dispose();
    _smoothAnimationController = null;
    super.dispose();
  }

  /// 使用 print() 输出不同级别的日志 / Output logs of different levels using print()
  /// 检查器会根据前缀自动识别日志级别（[VERBOSE]、[DEBUG]、[INFO]、[WARNING]、[ERROR]）
  /// Inspector auto-detects log level based on prefix ([VERBOSE], [DEBUG], [INFO], [WARNING], [ERROR])
  void _logMessages() {
    print('[VERBOSE] This is a verbose log');
    print('[DEBUG] This is a debug log');
    print('[INFO] This is an info log');
    print('[WARNING] This is a warning log');
    print('[ERROR] This is an error log');
  }

  /// 使用检查器的日志方法输出日志 / Output logs using inspector's log methods
  /// 通过 InspectorLogInterceptor 直接调用日志方法，无需 print() / Call log methods directly via InspectorLogInterceptor, no print() needed
  void _logWithCustomCallback() {
    InspectorLogInterceptor.instance.debug('Custom debug log via callback');
    InspectorLogInterceptor.instance.info('Custom info log via callback');
    InspectorLogInterceptor.instance.warning('Custom warning log via callback');
    InspectorLogInterceptor.instance.error('Custom error log via callback');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zero Inspector Kit Example')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Network Requests',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _makeDioGetRequest,
                child: const Text('Dio GET Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeDioPostRequest,
                child: const Text('Dio POST Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeDioPutRequest,
                child: const Text('Dio PUT Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeDioDeleteRequest,
                child: const Text('Dio DELETE Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeDioPatchRequest,
                child: const Text('Dio PATCH Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeDioHeadRequest,
                child: const Text('Dio HEAD Request'),
              ),
              const SizedBox(height: 16),
              const Text(
                'HTTP Package Requests',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeHttpGetRequest,
                child: const Text('HTTP GET Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeHttpPostRequest,
                child: const Text('HTTP POST Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeHttpPutRequest,
                child: const Text('HTTP PUT Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeHttpDeleteRequest,
                child: const Text('HTTP DELETE Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeHttpPatchRequest,
                child: const Text('HTTP PATCH Request'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _makeHttpHeadRequest,
                child: const Text('HTTP HEAD Request'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Logs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _logMessages,
                child: const Text('Generate Logs'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _logWithCustomCallback,
                child: const Text('Custom Logs (Callback)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _logWithLogger,
                child: const Text('Logger Library Logs'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Logs are automatically captured from:\n- print() calls\n- Flutter errors/exceptions\n- Custom log methods\n- Logger library (via integration)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Production Build: Inspector is automatically\n'
                'disabled in release mode (no code changes needed)',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.blue, fontSize: 12),
              ),
              const SizedBox(height: 8),
              const Text(
                'Third-party log library integration:\n'
                'Logger logs are captured because print() is called\n'
                'Alternatively, use onLogCaptured callback for custom handling',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 24),
              const Text(
                'Database',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Test database with users and posts tables\nis auto-created on app startup',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              const Text(
                'Memory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  _loadTestImages();
                },
                child: const Text('Load Test Images'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _allocateMemory,
                child: const Text('Allocate Memory (10MB)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _triggerGC,
                child: const Text('Trigger GC'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Load images to test image cache\n'
                'Allocate memory to test heap monitoring\n'
                'Trigger GC to test garbage collection',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 24),
              const Text(
                'FPS / Performance',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _triggerJankComputation,
                child: const Text('Trigger Jank (Heavy Computation)'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _toggleHeavyAnimations,
                child: Text(
                  _heavyAnimationsEnabled
                      ? 'Disable Heavy Animations'
                      : 'Enable Heavy Animations (Jank Demo)',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _toggleSmoothAnimation,
                child: Text(
                  _smoothAnimationEnabled
                      ? 'Disable Smooth Animation'
                      : 'Enable Smooth Animation (High FPS Demo)',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enable FPS monitoring via the switch in the inspector\'s FPS tab.\n'
                'Heavy Animations renders 80 rotating widgets to trigger jank.\n'
                'Smooth Animation runs a single lightweight widget for stable 60 FPS.\n'
                'Heavy Computation blocks the main thread for 100-500ms.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
              if (_heavyAnimationsEnabled) ...[
                const SizedBox(height: 12),
                _buildHeavyAnimationPreview(),
              ],
              if (_smoothAnimationEnabled) ...[
                const SizedBox(height: 12),
                _buildSmoothAnimationPreview(),
              ],
              const SizedBox(height: 24),
              const Text(
                'Navigation',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SecondScreen(),
                    ),
                  );
                },
                child: const Text('Navigate to Second Screen'),
              ),
            ],
          ),
        ),
      ),
      // 悬浮按钮由 ZeroInspectorKit.runAppWithInspector 自动通过 Overlay 创建，无需手动添加
      // Floating button is auto-created via Overlay by runAppWithInspector, no manual addition needed
    );
  }

  /// 构建重动画预览（80 个同时旋转+缩放的 widget，故意触发掉帧）
  /// Build heavy animation preview (80 simultaneously rotating+scaling widgets, intentionally triggering jank)
  Widget _buildHeavyAnimationPreview() {
    final controller = _jankAnimationController;
    if (controller == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
      ),
      child: ClipRect(
        child: Wrap(
          spacing: 2,
          runSpacing: 2,
          children: List.generate(_heavyAnimationCount, (index) {
            return AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                final angle = controller.value * 3.14159 * 2 * (index % 3 + 1);
                final scale = 0.5 + (controller.value * 0.5);
                return Transform.rotate(
                  angle: angle,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color:
                            Colors.primaries[index % Colors.primaries.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  /// 构建流畅动画预览（单个轻量 widget 平滑旋转，演示高 FPS 60）
  /// Build smooth animation preview (single lightweight widget rotating smoothly, demonstrates high 60 FPS)
  Widget _buildSmoothAnimationPreview() {
    final controller = _smoothAnimationController;
    if (controller == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      height: 150,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            // 平滑的复合动画：旋转 + 缩放 + 渐变 / Smooth compound animation: rotate + scale + gradient
            final angle = controller.value * 3.14159 * 2;
            final scale =
                0.8 + 0.2 * (0.5 + 0.5 * (controller.value - 0.5).abs() * 2);
            return Transform.rotate(
              angle: angle,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.green, Colors.teal, Colors.cyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 第二页 / Second screen
/// 用于演示路由导航追踪功能 / Used to demonstrate route navigation tracking
class SecondScreen extends StatelessWidget {
  const SecondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Second Screen')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('This is the second screen'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ThirdScreen()),
                );
              },
              child: const Text('Navigate to Third Screen'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
      // 悬浮按钮由 ZeroInspectorKit.runAppWithInspector 自动通过 Overlay 创建
      // Floating button auto-created via Overlay by runAppWithInspector
    );
  }
}

/// 第三页 / Third screen
/// 用于演示路由导航追踪功能 / Used to demonstrate route navigation tracking
class ThirdScreen extends StatelessWidget {
  const ThirdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Third Screen')),
      body: const Center(child: Text('This is the third screen')),
      // 悬浮按钮由 ZeroInspectorKit.runAppWithInspector 自动通过 Overlay 创建
      // Floating button auto-created via Overlay by runAppWithInspector
    );
  }
}
