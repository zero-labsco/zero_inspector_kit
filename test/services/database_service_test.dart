import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// 内存假实现 / In-memory fake provider
class _FakeDatabaseProvider implements DatabaseProvider {
  _FakeDatabaseProvider(
    this.name, {
    this.databases = const <DatabaseInfo>[],
    this.result,
  });

  @override
  final String name;

  final List<DatabaseInfo> databases;
  final QueryResult? result;

  @override
  Future<List<DatabaseInfo>> getDatabases() async => databases;

  @override
  Future<QueryResult> queryTable(
    String dbPath,
    String tableName, {
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool desc = false,
    String? whereKeyword,
  }) async => result ?? QueryResult(rows: const [], columns: const []);
}

/// 始终抛错的提供者，用于验证隔离性 / A provider that always throws, to verify isolation
class _ThrowingDatabaseProvider implements DatabaseProvider {
  @override
  String get name => 'throwing';

  @override
  Future<List<DatabaseInfo>> getDatabases() async => throw Exception('boom');

  @override
  Future<QueryResult> queryTable(
    String dbPath,
    String tableName, {
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool desc = false,
    String? whereKeyword,
  }) async => throw Exception('boom');
}

void main() {
  tearDown(() {
    DatabaseRegistry.instance.unregisterProvider('svc-a');
    DatabaseRegistry.instance.unregisterProvider('svc-b');
    DatabaseRegistry.instance.unregisterProvider('throwing');
  });

  test(
    'getDatabases 合并所有提供者的结果 / getDatabases merges results across providers',
    () async {
      DatabaseRegistry.instance.registerProvider(
        _FakeDatabaseProvider(
          'svc-a',
          databases: [
            DatabaseInfo(name: 'a', path: '/a', tables: const <TableInfo>[]),
          ],
        ),
      );
      DatabaseRegistry.instance.registerProvider(
        _FakeDatabaseProvider(
          'svc-b',
          databases: [
            DatabaseInfo(name: 'b', path: '/b', tables: const <TableInfo>[]),
          ],
        ),
      );
      final all = await DatabaseService.instance.getDatabases();
      expect(all.length, 2);
    },
  );

  test(
    'getDatabases 隔离抛错的提供者 / getDatabases isolates a throwing provider',
    () async {
      DatabaseRegistry.instance.registerProvider(_ThrowingDatabaseProvider());
      DatabaseRegistry.instance.registerProvider(
        _FakeDatabaseProvider(
          'svc-a',
          databases: [
            DatabaseInfo(name: 'a', path: '/a', tables: const <TableInfo>[]),
          ],
        ),
      );
      final all = await DatabaseService.instance.getDatabases();
      expect(all.length, 1);
    },
  );

  test(
    'queryTable 返回第一个**未报错**的结果，合法的空表不会被跳过 / queryTable '
    'returns the first non-error result; a legitimately empty table is not skipped',
    () async {
      // 回归：此前用 `rows.isNotEmpty` 判定成功，一张合法的空表会让循环继续尝试
      // 后面的 provider，把**另一个数据源**的内容当成这个 dbPath 的结果返回。
      // Regression: this used to test `rows.isNotEmpty`, so a legitimately empty
      // table made the loop keep trying later providers and could return another
      // data source's content for this dbPath.
      DatabaseRegistry.instance.registerProvider(
        _FakeDatabaseProvider(
          'svc-a',
          result: QueryResult(rows: const [], columns: const []),
        ),
      );
      DatabaseRegistry.instance.registerProvider(
        _FakeDatabaseProvider(
          'svc-b',
          result: QueryResult(
            rows: <Map<String, dynamic>>[
              {'id': 1},
            ],
            columns: ['id'],
          ),
        ),
      );
      final r = await DatabaseService.instance.queryTable('/p', 't');
      expect(r.rows, isEmpty);
      expect(r.hasError, isFalse);
    },
  );

  test(
    'queryTable 容忍抛错的提供者 / queryTable tolerates a throwing provider',
    () async {
      DatabaseRegistry.instance.registerProvider(_ThrowingDatabaseProvider());
      DatabaseRegistry.instance.registerProvider(
        _FakeDatabaseProvider(
          'svc-b',
          result: QueryResult(
            rows: <Map<String, dynamic>>[
              {'id': 1},
            ],
            columns: ['id'],
          ),
        ),
      );
      final r = await DatabaseService.instance.queryTable('/p', 't');
      expect(r.rows.length, 1);
    },
  );
}
