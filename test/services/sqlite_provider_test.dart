import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// SQLite 提供者的真实数据库单元测试（基于 sqflite_common_ffi 在主机上运行）。
/// Real-database unit test for the SQLite provider, run on the host via
/// sqflite_common_ffi.
void main() {
  late String dbPath;
  late SqliteDatabaseProvider provider;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    final dir = await Directory.systemTemp.createTemp('zik_sqlite_');
    dbPath = '${dir.path}${Platform.pathSeparator}test.db';
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT)');
        await db.insert('users', {'id': 1, 'name': 'alice'});
        await db.insert('users', {'id': 2, 'name': 'bob'});
      },
    );
    await db.close();
    provider = SqliteDatabaseProvider();
  });

  tearDown(() async {
    await provider.dispose();
    final file = File(dbPath);
    if (file.existsSync()) file.deleteSync();
  });

  test('queryTable 返回列与行 / queryTable returns columns and rows', () async {
    final result = await provider.queryTable(dbPath, 'users');
    expect(result.hasError, isFalse);
    expect(result.columns, contains('name'));
    expect(result.rows.length, 2);
  });

  test('queryTable 支持 limit 与 offset 分页 / queryTable honors limit and offset',
      () async {
    final page1 = await provider.queryTable(dbPath, 'users', limit: 1, offset: 0);
    final page2 = await provider.queryTable(dbPath, 'users', limit: 1, offset: 1);
    expect(page1.rows.length, 1);
    expect(page2.rows.length, 1);
    expect(page1.rows.first['id'], 1);
    expect(page2.rows.first['id'], 2);
  });

  test('queryTable 暴露错误而非伪装成空列表 / queryTable surfaces errors instead of an empty list',
      () async {
    final result = await provider.queryTable(dbPath, 'missing_table');
    expect(result.hasError, isTrue);
  });
}
