import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// 内存假实现，用于断言注册表行为，不触碰真实数据库。
/// In-memory fake used to assert registry behavior without a real database.
class _FakeDatabaseProvider implements DatabaseProvider {
  _FakeDatabaseProvider(this.name);

  @override
  final String name;

  @override
  Future<List<DatabaseInfo>> getDatabases() async => const <DatabaseInfo>[];

  @override
  Future<QueryResult> queryTable(
    String dbPath,
    String tableName, {
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool desc = false,
    String? whereKeyword,
  }) async =>
      QueryResult(rows: const [], columns: const []);
}

void main() {
  tearDown(() {
    DatabaseRegistry.instance.unregisterProvider('reg-a');
    DatabaseRegistry.instance.unregisterProvider('reg-b');
  });

  test('registerProvider 添加一个提供者 / registerProvider adds a provider', () {
    DatabaseRegistry.instance.registerProvider(_FakeDatabaseProvider('reg-a'));
    expect(
      DatabaseRegistry.instance.providers.any((p) => p.name == 'reg-a'),
      isTrue,
    );
  });

  test('registerProvider 按名称去重 / registerProvider dedupes by name', () {
    DatabaseRegistry.instance
      ..registerProvider(_FakeDatabaseProvider('reg-b'))
      ..registerProvider(_FakeDatabaseProvider('reg-b'));
    final count = DatabaseRegistry.instance.providers
        .where((p) => p.name == 'reg-b')
        .length;
    expect(count, 1);
  });

  test('unregisterProvider 按名称移除 / unregisterProvider removes by name', () {
    DatabaseRegistry.instance.registerProvider(_FakeDatabaseProvider('reg-a'));
    DatabaseRegistry.instance.unregisterProvider('reg-a');
    expect(
      DatabaseRegistry.instance.providers.any((p) => p.name == 'reg-a'),
      isFalse,
    );
  });
}
