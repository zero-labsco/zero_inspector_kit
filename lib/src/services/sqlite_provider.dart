import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/database_info.dart';
import 'database_provider.dart';

/// SQLite数据库提供者实现 / SQLite database provider implementation
/// 自动扫描应用目录下的.db和.sqlite文件 / Auto-scan .db and .sqlite files in application directory
class SqliteDatabaseProvider implements DatabaseProvider {
  /// 连接缓存：dbPath -> Database / Connection cache: dbPath -> Database
  /// 复用只读连接，避免每次查询都 open/close 造成数百毫秒卡顿。
  /// Reuses read-only connections to avoid the open/close overhead per query.
  final Map<String, Database> _connections = {};

  /// LRU 访问顺序，用于在上限内回收最久未使用的连接。
  /// LRU access order, used to evict the least-recently-used connection.
  final List<String> _accessOrder = [];

  /// 同时缓存的连接数上限 / Max number of cached connections.
  static const int _maxCachedConnections = 3;

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

            Database? db;
            try {
              db = await _openConnection(file.path);
              final tables = await _getTables(db);
              databases.add(
                DatabaseInfo(
                  name: file.path.split(Platform.pathSeparator).last,
                  path: file.path,
                  tables: tables,
                ),
              );
            } catch (_) {
              // 单个文件打开失败不应阻断整个扫描 / A single bad file must not abort the scan.
            } finally {
              // 扫描阶段不持有连接，归还缓存 / Don't keep connections during scan.
              _releaseConnection(file.path);
            }
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
        "SELECT name FROM sqlite_master WHERE type='table'",
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
      final result = await db.rawQuery(
        'PRAGMA table_info(${_quoteIdent(tableName)})',
      );

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
      final result = await db.rawQuery(
        'SELECT COUNT(*) FROM ${_quoteIdent(tableName)}',
      );
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
    int offset = 0,
    String? orderBy,
    bool desc = false,
    String? whereKeyword,
  }) async {
    Database? db;
    try {
      db = await _openConnection(dbPath);

      // 列名白名单：orderBy 必须是真实存在的列，否则忽略排序（防 SQL 注入）。
      // Column whitelist: orderBy must be a real column, else sorting is ignored (prevents SQL injection).
      final columns = await _getColumns(db, tableName);
      final columnNames = columns.map((c) => c.name).toList();

      final quotedTable = _quoteIdent(tableName);
      final whereClause = _buildKeywordWhere(columnNames, whereKeyword);
      final orderClause = _buildOrderClause(columnNames, orderBy, desc);

      // 关键字过滤时仍需先拿到总行数（过滤后的行数）。
      // When filtering, total row count should reflect the filtered set.
      final kwArgs = whereKeyword == null || whereKeyword.isEmpty
          ? const <String>[]
          : _keywordArgs(columnNames, whereKeyword);
      final countSql = 'SELECT COUNT(*) FROM $quotedTable$whereClause';
      final totalRows = whereKeyword == null || whereKeyword.isEmpty
          ? Sqflite.firstIntValue(await db.rawQuery(
              'SELECT COUNT(*) FROM $quotedTable',
            )) ??
              0
          : Sqflite.firstIntValue(await db.rawQuery(countSql, kwArgs)) ?? 0;

      final sql =
          'SELECT * FROM $quotedTable$whereClause$orderClause LIMIT $limit OFFSET $offset';
      final rows = await db.rawQuery(sql, kwArgs);

      return QueryResult(
        rows: rows,
        columns: columnNames,
        totalRows: totalRows,
      );
    } catch (_) {
      // 查询失败时返回空结果；错误态由后续批次的 InspectorResult 暴露给 UI。
      // On failure return empty; error surfacing via InspectorResult comes in a later batch.
      return QueryResult(rows: [], columns: []);
    } finally {
      // query 不持有连接，立即归还缓存 / query does not keep the connection.
      _releaseConnection(dbPath);
    }
  }

  // ---- 连接缓存（LRU） / Connection cache (LRU) ----

  Future<Database> _openConnection(String dbPath) async {
    final cached = _connections[dbPath];
    if (cached != null) {
      _accessOrder.remove(dbPath);
      _accessOrder.add(dbPath);
      return cached;
    }

    final db = await openDatabase(dbPath, readOnly: true, version: 1);
    _connections[dbPath] = db;
    _accessOrder.add(dbPath);

    // 超出上限时回收最久未使用的连接 / Evict least-recently-used when over capacity.
    while (_connections.length > _maxCachedConnections) {
      final oldest = _accessOrder.removeAt(0);
      final evicted = _connections.remove(oldest);
      try {
        await evicted?.close();
      } catch (_) {}
    }
    return db;
  }

  void _releaseConnection(String dbPath) {
    // 连接仍保留在缓存中供复用，这里仅维护 LRU 顺序由 _openConnection 负责。
    // Connections stay cached for reuse; LRU order is managed in _openConnection.
  }

  /// 关闭并清空所有缓存的连接。应在 Inspector 销毁时调用。
  /// Closes and clears all cached connections. Call when the inspector is disposed.
  Future<void> dispose() async {
    for (final db in _connections.values) {
      try {
        await db.close();
      } catch (_) {}
    }
    _connections.clear();
    _accessOrder.clear();
  }

  // ---- SQL 安全辅助 / SQL safety helpers ----

  /// 安全引用标识符（表名/列名）。将双引号转义为两个双引号，并包裹双引号。
  /// Safely quote an identifier (table/column name). Doubles embedded quotes and wraps in double quotes.
  static String _quoteIdent(String ident) {
    final escaped = ident.replaceAll('"', '""');
    return '"$escaped"';
  }

  /// 校验 [name] 是否为合法标识符（仅含字母、数字、下划线、点）。
  /// Validate that [name] is a safe identifier (letters, digits, underscore, dot only).
  static bool _isValidIdent(String name) {
    return RegExp(r'^[A-Za-z0-9_\.]+$').hasMatch(name);
  }

  /// 构建列名白名单校验后的 ORDER BY 子句。
  /// Build the ORDER BY clause after validating the column against the whitelist.
  static String _buildOrderClause(
    List<String> columnNames,
    String? orderBy,
    bool desc,
  ) {
    if (orderBy == null || orderBy.isEmpty) return '';
    if (!columnNames.contains(orderBy) || !_isValidIdent(orderBy)) return '';
    final dir = desc ? 'DESC' : 'ASC';
    return ' ORDER BY ${_quoteIdent(orderBy)} $dir';
  }

  /// 构建单元格级关键字过滤的 WHERE 子句（参数化，防注入）。
  /// Build the cell-level keyword filter WHERE clause (parameterized, injection-safe).
  static String _buildKeywordWhere(
    List<String> columnNames,
    String? keyword,
  ) {
    if (keyword == null || keyword.isEmpty) return '';
    final safeCols =
        columnNames.where(_isValidIdent).map(_quoteIdent).toList();
    if (safeCols.isEmpty) return '';
    final conditions = safeCols.map((c) => '$c LIKE ?').join(' OR ');
    return ' WHERE $conditions';
  }

  /// 关键字过滤所需的绑定参数（与 [_buildKeywordWhere] 的列一一对应）。
  /// Bind args for the keyword filter (one per column from [_buildKeywordWhere]).
  static List<String> _keywordArgs(List<String> columnNames, String keyword) {
    final safeCols = columnNames.where(_isValidIdent).toList();
    return safeCols.map((_) => '%$keyword%').toList();
  }
}
