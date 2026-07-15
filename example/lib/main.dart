import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';
import 'package:logger/logger.dart';

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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Dio _dio = Dio();
  final InspectorDioInterceptor _dioInterceptor = InspectorDioInterceptor();
  late Logger _logger;

  @override
  void initState() {
    super.initState();
    DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());

    _setupLoggerIntegration();
    _setupDioInterceptor();
    _initTestDatabase();
  }

  void _setupLoggerIntegration() {
    _logger = Logger(printer: PrettyPrinter(methodCount: 0, printEmojis: true));

    InspectorLogInterceptor.instance.onLogCaptured = (entry) {
      _logger.log(
        _mapLogLevel(entry.level),
        '${entry.tag != null ? '[${entry.tag}] ' : ''}${entry.message}',
      );
    };
  }

  Level _mapLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return Level.trace;
      case LogLevel.debug:
        return Level.debug;
      case LogLevel.info:
        return Level.info;
      case LogLevel.warning:
        return Level.warning;
      case LogLevel.error:
        return Level.error;
    }
  }

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

  void _setupDioInterceptor() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _dioInterceptor.onRequest({
            'method': options.method,
            'url': options.uri.toString(),
            'headers': options.headers.cast<String, String>(),
            'data': options.data,
          });
          handler.next(options);
        },
        onResponse: (response, handler) {
          _dioInterceptor.onResponse({
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
          _dioInterceptor.onError({
            'message': error.message,
            'response': error.response != null
                ? {
                    'data': error.response!.data,
                    'statusCode': error.response!.statusCode,
                  }
                : null,
            'requestOptions': {
              'method': error.requestOptions.method,
              'uri': error.requestOptions.uri,
            },
          });
          handler.next(error);
        },
      ),
    );
  }

  Future<void> _makeDioRequest() async {
    try {
      await _dio.get('https://jsonplaceholder.typicode.com/posts/1');
      print('Dio request completed successfully');
    } catch (e) {
      print('Dio request failed: $e');
    }
  }

  Future<void> _makeHttpGetRequest() async {
    try {
      await InspectorHttpInterceptor.instance.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/2'),
      );
      print('HTTP GET request completed successfully');
    } catch (e) {
      print('HTTP GET request failed: $e');
    }
  }

  Future<void> _makeHttpPostRequest() async {
    try {
      await InspectorHttpInterceptor.instance.post(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
        body: {'title': 'foo', 'body': 'bar', 'userId': 1},
      );
      print('HTTP POST request completed successfully');
    } catch (e) {
      print('HTTP POST request failed: $e');
    }
  }

  void _logMessages() {
    print('[VERBOSE] This is a verbose log');
    print('[DEBUG] This is a debug log');
    print('[INFO] This is an info log');
    print('[WARNING] This is a warning log');
    print('[ERROR] This is an error log');
  }

  void _logWithCustomCallback() {
    InspectorLogInterceptor.instance.debug('Custom debug log via callback');
    InspectorLogInterceptor.instance.info('Custom info log via callback');
    InspectorLogInterceptor.instance.warning('Custom warning log via callback');
    InspectorLogInterceptor.instance.error('Custom error log via callback');
  }

  void _logWithLogger() {
    _logger.t('Logger trace message');
    _logger.d('Logger debug message');
    _logger.i('Logger info message');
    _logger.w('Logger warning message');
    _logger.e('Logger error message');
    _logger.f('Logger fatal message');
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
                onPressed: _makeDioRequest,
                child: const Text('Dio GET Request'),
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
