/// 数据库信息模型 / Database info model
class DatabaseInfo {
  /// 数据库名称 / Database name
  final String name;

  /// 数据库文件路径 / Database file path
  final String path;

  /// 数据库表列表 / Database table list
  final List<TableInfo> tables;

  /// 扫描该数据库时发生的错误（如无法打开）。非空时说明表列表可能不完整。
  /// Error encountered while scanning this database (e.g. cannot open it).
  /// Non-null means the table list may be incomplete.
  final String? error;

  DatabaseInfo({
    required this.name,
    required this.path,
    required this.tables,
    this.error,
  });
}

/// 数据表信息模型 / Table info model
class TableInfo {
  /// 表名称 / Table name
  final String name;

  /// 表行数 / Table row count
  final int rowCount;

  /// 表列信息列表 / Table column info list
  final List<ColumnInfo> columns;

  TableInfo({
    required this.name,
    required this.rowCount,
    required this.columns,
    this.error,
  });

  /// 扫描该表时发生的错误（如无法读取 schema）。非空时说明列信息可能不完整。
  /// Error encountered while scanning this table (e.g. cannot read schema).
  /// Non-null means the column info may be incomplete.
  final String? error;
}

/// 列信息模型 / Column info model
class ColumnInfo {
  /// 列名称 / Column name
  final String name;

  /// 列类型 / Column type
  final String type;

  ColumnInfo({required this.name, required this.type});
}

/// 查询结果模型 / Query result model
class QueryResult {
  /// 查询结果行数据 / Query result row data
  final List<Map<String, dynamic>> rows;

  /// 列名列表 / Column name list
  final List<String> columns;

  /// 过滤后的总行数（用于分页）。未提供时回退为 [rows] 长度。
  /// Total filtered row count (for pagination). Falls back to [rows].length when absent.
  final int? totalRows;

  /// 查询失败时非空。此时 [rows] 为空，UI 应渲染错误态而非（误导性的）空列表。
  /// Non-null when the query failed. When set, [rows] is empty and the UI
  /// should render an error state instead of a (misleading) empty list.
  final String? error;

  QueryResult({
    required this.rows,
    required this.columns,
    this.totalRows,
    this.error,
  });

  /// 用于分页的总行数；未显式提供时按当前页行数近似。
  /// Total rows for pagination; approximates with current page length if not provided.
  int get total => totalRows ?? rows.length;

  /// 查询是否失败 / Whether the query failed.
  bool get hasError => error != null && error!.isNotEmpty;

  /// 成功（可能为空）的结果 / A successful (possibly empty) result.
  const QueryResult.empty()
      : rows = const [],
        columns = const [],
        totalRows = 0,
        error = null;

  /// 携带错误信息的失败结果 / A failed result carrying the error message.
  const QueryResult.failure(this.error)
      : rows = const [],
        columns = const [],
        totalRows = 0;
}
