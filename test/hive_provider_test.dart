import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/services/hive_provider.dart';

/// 手写 fake，实现 HiveBoxLike 契约，避免依赖 hive 包。
/// Hand-written fake implementing the HiveBoxLike contract, so the test does
/// not depend on the `hive` package.
class _FakeBox implements HiveBoxLike {
  _FakeBox(this._data);
  final Map<dynamic, dynamic> _data;

  @override
  Iterable<dynamic> get keys => _data.keys;

  @override
  dynamic get(dynamic key) => _data[key];

  @override
  int get length => _data.length;
}

void main() {
  group('HiveProvider / Hive 查看器', () {
    late HiveProvider provider;

    setUp(() {
      provider = HiveProvider(
        name: 'settings',
        box: _FakeBox({
          'user': {'name': 'Ada', 'age': 36},
          'flag': true,
          'score': 99,
          'note': 'hello',
        }),
      );
    });

    test('getDatabases returns one database for the box / 返回单个库',
        () async {
      final dbs = await provider.getDatabases();
      expect(dbs, hasLength(1));
      expect(dbs.first.name, 'settings');
      expect(dbs.first.path, 'hive://settings');
      expect(dbs.first.tables.first.name, 'entries');
      expect(dbs.first.tables.first.rowCount, 4);
    });

    test('queryTable serializes complex values to JSON / 复杂对象序列化为 JSON',
        () async {
      final result = await provider.queryTable('x', 'entries');
      expect(result.columns, ['key', 'type', 'value']);
      final userRow = result.rows.firstWhere((r) => r['key'] == 'user');
      expect(userRow['type'], 'Map');
      // 值应为合法 JSON 字符串，且内容正确
      final decoded = jsonDecode(userRow['value'] as String) as Map;
      expect(decoded['name'], 'Ada');
      expect(decoded['age'], 36);
      final flagRow = result.rows.firstWhere((r) => r['key'] == 'flag');
      expect(flagRow['type'], 'bool');
      expect(flagRow['value'], 'true');
    });

    test('whereKeyword is case-insensitive / 关键词不区分大小写', () async {
      final result = await provider.queryTable(
        'x',
        'entries',
        whereKeyword: 'NOTE',
      );
      expect(result.totalRows, 1);
      expect(result.rows.first['key'], 'note');
    });

    test('desc reverses order / 倒序', () async {
      final asc = await provider.queryTable('x', 'entries');
      final desc = await provider.queryTable('x', 'entries', desc: true);
      expect(desc.rows.first['key'], asc.rows.last['key']);
    });
  });
}
