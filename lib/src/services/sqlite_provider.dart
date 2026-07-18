import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/database_info.dart';
import 'database_provider.dart';

/// SQLite数据库提供者实现 / SQLite database provider implementation
/// 自动扫描应用目录下的.db和.sqlite文件 / Auto-scan .db and .sqlite files in application directory
class SqliteDatabaseProvider implements DatabaseProvider {
  @override
  String get name => 'sqlite';

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    final databases = <DatabaseInfo>[];
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final dbDirPath = await getDatabasesPath();
      final directories = [docDir.path, dbDirPath];

      for (final dirPath in directories) {
        final directory = Directory(dirPath);
        if (!directory.existsSync()) continue;

        final files = directory.listSync(recursive: true).whereType<File>();

        for (final file in files) {
          if (file.path.endsWith('.db') || file.path.endsWith('.sqlite')) {
            if (databases.any((d) => d.path == file.path)) continue;

            try {
              final db = await openDatabase(
                file.path,
                readOnly: true,
                version: 1,
              );

              final tables = await _getTables(db);
              databases.add(
                DatabaseInfo(
                  name: file.path.split(Platform.pathSeparator).last,
                  path: file.path,
                  tables: tables,
                ),
              );

              await db.close();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    return databases;
  }

  /// 获取数据库中的所有表信息 / Get all table info in database
  Future<List<TableInfo>> _getTables(Database db) async {
    final tables = <TableInfo>[];
    try {
      final result = await db.rawQuery(
        'SELECT name FROM sqlite_master WHERE type="table"',
      );

      for (final row in result) {
        final tableName = row['name'] as String;
        if (tableName.startsWith('sqlite_')) continue;

        final columns = await _getColumns(db, tableName);
        final rowCount = await _getRowCount(db, tableName);

        tables.add(
          TableInfo(name: tableName, rowCount: rowCount, columns: columns),
        );
      }
    } catch (_) {}

    return tables;
  }

  /// 获取表的列信息 / Get column info of table
  Future<List<ColumnInfo>> _getColumns(Database db, String tableName) async {
    final columns = <ColumnInfo>[];
    try {
      final result = await db.rawQuery('PRAGMA table_info($tableName)');

      for (final row in result) {
        columns.add(
          ColumnInfo(name: row['name'] as String, type: row['type'] as String),
        );
      }
    } catch (_) {}

    return columns;
  }

  /// 获取表的行数 / Get row count of table
  Future<int> _getRowCount(Database db, String tableName) async {
    try {
      final result = await db.rawQuery('SELECT COUNT(*) FROM $tableName');
      return result.first.values.first as int;
    } catch (_) {
      return 0;
    }
  }

  @override
  Future<QueryResult> queryTable(
    String dbPath,
    String tableName, {
    int limit = 50,
  }) async {
    try {
      final db = await openDatabase(dbPath, readOnly: true, version: 1);

      final columns = await _getColumns(db, tableName);
      final rows = await db.rawQuery('SELECT * FROM $tableName LIMIT $limit');

      await db.close();

      return QueryResult(
        rows: rows,
        columns: columns.map((c) => c.name).toList(),
      );
    } catch (_) {
      return QueryResult(rows: [], columns: []);
    }
  }
}