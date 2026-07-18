import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';
import 'package:logger/logger.dart';

void main() {
  /// 零侵入集成：仅需一行代码即可启用所有检查器功能 / Zero-invasion integration: One line of code to enable all inspector features
  ///
  /// 对于 http 包用户：真正的零侵入，无需修改任何其他代码！
  /// For http package users: True zero-invasion, no other code modifications needed!
  ///
  /// 对于 Dio 用户：同样零侵入！Dio 默认使用 HttpClient，会被 HttpOverrides 自动捕获
  /// For Dio users: Also zero-invasion! Dio uses HttpClient by default, auto-captured by HttpOverrides
  ///
  /// runAppWithInspector 会自动：/ runAppWithInspector automatically:
  /// 1. 初始化检查器（日志捕获、网络拦截、数据库扫描）/ 1. Initialize inspector (log capture, network interception, database scan)
  /// 2. 通过 Zone 捕获所有 print() 输出 / 2. Capture all print() output via Zone
  /// 3. 自动显示悬浮按钮 / 3. Auto-show floating button
  /// 4. 自动注入路由观察者到 MaterialApp / 4. Auto-inject route observer into MaterialApp
  ZeroInspectorKit.runAppWithInspector(MaterialApp(home: const HomePage()));
}

/// 零侵入使用示例 / Zero-invasion usage example
///
/// http 包用户：以下代码完全无需修改，检查器会自动工作！
/// http package users: No modifications needed below, inspector works automatically!
///
/// Dio 用户：同样零侵入！Dio 默认使用 HttpClient，会被 HttpOverrides 自动捕获
/// Dio users: Also zero-invasion! Dio uses HttpClient by default, auto-captured by HttpOverrides
///
/// 检查器自动完成：/ Inspector automatically:
/// - 捕获所有 print() 输出和 Flutter 错误 / - Capture all print() output and Flutter errors
/// - 拦截所有 http 包请求（通过 HttpOverrides 全局拦截）/ - Intercept all http package requests (via HttpOverrides global interception)
/// - 扫描 SQLite 数据库 / - Scan SQLite databases
/// - 自动跟踪路由导航（无需手动添加 navigatorObservers）/ - Auto-track route navigation (no need to manually add navigatorObservers)
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: const HomePage());
  }
}

/// 主页 / Home page
/// 展示所有检查器功能的示例 / Show examples of all inspector features
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Dio 实例用于发送网络请求 / Dio instance for sending network requests
  /// 通过 HttpOverrides 自动捕获，无需额外配置 / Auto-captured via HttpOverrides, no extra configuration needed
  final Dio _dio = Dio();

  /// Logger 实例用于测试第三方日志库集成 / Logger instance for testing third-party log library integration
  late Logger _logger;

  @override
  void initState() {
    super.initState();

    /// 注意：SQLite 数据库提供者已在 ZeroInspectorKit.init() 中自动注册，无需手动注册
    /// Note: SQLite database provider is automatically registered in ZeroInspectorKit.init(), no manual registration needed
    /// DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider()); // 这行已不需要 / This line is no longer needed

    _setupLoggerIntegration();
    _initTestDatabase();
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
      floatingActionButton: const FloatingInspectorButton(),
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
      floatingActionButton: const FloatingInspectorButton(),
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
      floatingActionButton: const FloatingInspectorButton(),
    );
  }
}
