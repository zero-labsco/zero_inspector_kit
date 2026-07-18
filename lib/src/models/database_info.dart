/// 数据库信息模型 / Database info model
class DatabaseInfo {
  /// 数据库名称 / Database name
  final String name;

  /// 数据库文件路径 / Database file path
  final String path;

  /// 数据库表列表 / Database table list
  final List<TableInfo> tables;

  DatabaseInfo({
    required this.name,
    required this.path,
    required this.tables,
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
  });
}

/// 列信息模型 / Column info model
class ColumnInfo {
  /// 列名称 / Column name
  final String name;

  /// 列类型 / Column type
  final String type;

  ColumnInfo({
    required this.name,
    required this.type,
  });
}

/// 查询结果模型 / Query result model
class QueryResult {
  /// 查询结果行数据 / Query result row data
  final List<Map<String, dynamic>> rows;

  /// 列名列表 / Column name list
  final List<String> columns;

  QueryResult({
    required this.rows,
    required this.columns,
  });
}