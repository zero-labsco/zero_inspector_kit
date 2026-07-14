import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
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
  Database? _testDb;

  @override
  void initState() {
    super.initState();
    InspectorLogInterceptor.instance.start();
    DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
    
    _setupDioInterceptor();
    _initTestDatabase();
  }

  Future<void> _initTestDatabase() async {
    try {
      final dbPath = await getDatabasesPath();
      _testDb = await openDatabase(
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
          await db.insert('users', {'name': 'Alice', 'email': 'alice@example.com', 'age': 25});
          await db.insert('users', {'name': 'Bob', 'email': 'bob@example.com', 'age': 30});
          await db.insert('users', {'name': 'Charlie', 'email': 'charlie@example.com', 'age': 35});
          await db.insert('posts', {'title': 'First Post', 'content': 'Hello World!', 'user_id': 1, 'created_at': '2024-01-01'});
          await db.insert('posts', {'title': 'Second Post', 'content': 'Flutter is awesome', 'user_id': 2, 'created_at': '2024-01-02'});
        },
      );
      InspectorLogInterceptor.instance.info('Test database initialized successfully');
    } catch (e) {
      InspectorLogInterceptor.instance.error('Failed to initialize database: $e');
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
  }

  Future<void> _makeDioRequest() async {
    try {
      await _dio.get('https://jsonplaceholder.typicode.com/posts/1');
      InspectorLogInterceptor.instance.info('Dio request completed successfully');
    } catch (e) {
      InspectorLogInterceptor.instance.error('Dio request failed: $e');
    }
  }

  Future<void> _makeHttpGetRequest() async {
    try {
      await InspectorHttpInterceptor.instance.get(
        Uri.parse('https://jsonplaceholder.typicode.com/posts/2'),
      );
      InspectorLogInterceptor.instance.info('HTTP GET request completed successfully');
    } catch (e) {
      InspectorLogInterceptor.instance.error('HTTP GET request failed: $e');
    }
  }

  Future<void> _makeHttpPostRequest() async {
    try {
      await InspectorHttpInterceptor.instance.post(
        Uri.parse('https://jsonplaceholder.typicode.com/posts'),
        body: {
          'title': 'foo',
          'body': 'bar',
          'userId': 1,
        },
      );
      InspectorLogInterceptor.instance.info('HTTP POST request completed successfully');
    } catch (e) {
      InspectorLogInterceptor.instance.error('HTTP POST request failed: $e');
    }
  }

  void _logMessages() {
    InspectorLogInterceptor.instance.verbose('This is a verbose log');
    InspectorLogInterceptor.instance.debug('This is a debug log');
    InspectorLogInterceptor.instance.info('This is an info log');
    InspectorLogInterceptor.instance.warning('This is a warning log');
    InspectorLogInterceptor.instance.error('This is an error log');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zero Inspector Kit Example'),
      ),
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
      floatingActionButton: const FloatingInspectorButton(enabled: true),
    );
  }
}

class SecondScreen extends StatelessWidget {
  const SecondScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Second Screen'),
      ),
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
                  MaterialPageRoute(
                    builder: (context) => const ThirdScreen(),
                  ),
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
      floatingActionButton: const FloatingInspectorButton(enabled: true),
    );
  }
}

class ThirdScreen extends StatelessWidget {
  const ThirdScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Third Screen'),
      ),
      body: const Center(
        child: Text('This is the third screen'),
      ),
      floatingActionButton: const FloatingInspectorButton(enabled: true),
    );
  }
}