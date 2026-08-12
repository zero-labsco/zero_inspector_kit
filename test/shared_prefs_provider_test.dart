import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/services/shared_prefs_provider.dart';

/// 手写 fake，实现 SharedPrefsLike 契约，避免依赖 shared_preferences 包。
/// Hand-written fake implementing the SharedPrefsLike contract, so the test
/// does not depend on the `shared_preferences` package.
class _FakePrefs implements SharedPrefsLike {
  _FakePrefs(this._data);
  final Map<String, Object> _data;

  @override
  Set<String> getKeys() => _data.keys.toSet();

  @override
  Object? get(String key) => _data[key];

  @override
  bool? getBool(String key) => _data[key] as bool?;

  @override
  int? getInt(String key) => _data[key] as int?;

  @override
  double? getDouble(String key) => _data[key] as double?;

  @override
  String? getString(String key) => _data[key] as String?;

  @override
  List<String>? getStringList(String key) => _data[key] as List<String>?;
}

void main() {
  group('SharedPrefsProvider / 偏好存储查看器', () {
    late SharedPrefsProvider provider;

    setUp(() {
      provider = SharedPrefsProvider(
        prefs: _FakePrefs({
          'theme': 'dark',
          'count': 42,
          'enabled': true,
          'ratio': 1.5,
          'tags': <String>['a', 'b'],
        }),
      );
    });

    test(
      'getDatabases returns one database with one table / 返回单个库单表',
      () async {
        final dbs = await provider.getDatabases();
        expect(dbs, hasLength(1));
        expect(dbs.first.name, 'SharedPreferences');
        expect(dbs.first.tables, hasLength(1));
        expect(dbs.first.tables.first.name, 'preferences');
        expect(dbs.first.tables.first.rowCount, 5);
      },
    );

    test(
      'queryTable maps entries to key/type/value columns / 映射为键值列',
      () async {
        final result = await provider.queryTable('x', 'preferences');
        expect(result.columns, ['key', 'type', 'value']);
        expect(result.totalRows, 5);
        final map = {
          for (final row in result.rows)
            row['key'] as String: (row['type'], row['value']),
        };
        expect(map['theme'], ('String', 'dark'));
        expect(map['count'], ('int', '42'));
        expect(map['enabled'], ('bool', 'true'));
        expect(map['ratio'], ('double', '1.5'));
        expect(map['tags'], ('List<String>', 'a, b'));
      },
    );

    test('queryTable is sorted by key / 按 key 排序', () async {
      final result = await provider.queryTable('x', 'preferences');
      final keys = result.rows.map((r) => r['key'] as String).toList();
      expect(keys, [...keys]..sort());
    });

    test('whereKeyword filters rows / 关键词过滤', () async {
      final result = await provider.queryTable(
        'x',
        'preferences',
        whereKeyword: 'tag',
      );
      expect(result.totalRows, 1);
      expect(result.rows.first['key'], 'tags');
    });

    test('limit and offset paginate / 分页', () async {
      final result = await provider.queryTable(
        'x',
        'preferences',
        limit: 2,
        offset: 1,
      );
      expect(result.rows, hasLength(2));
      expect(result.totalRows, 5);
    });
  });
}
