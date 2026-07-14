/// 数据库信息模型
class DatabaseInfo {
  /// 数据库名称
  final String name;

  /// 数据库文件路径
  final String path;

  /// 数据库表列表
  final List<TableInfo> tables;

  DatabaseInfo({
    required this.name,
    required this.path,
    required this.tables,
  });
}

/// 数据表信息模型
class TableInfo {
  /// 表名称
  final String name;

  /// 表行数
  final int rowCount;

  /// 表列信息列表
  final List<ColumnInfo> columns;

  TableInfo({
    required this.name,
    required this.rowCount,
    required this.columns,
  });
}

/// 列信息模型
class ColumnInfo {
  /// 列名称
  final String name;

  /// 列类型
  final String type;

  ColumnInfo({
    required this.name,
    required this.type,
  });
}

/// 查询结果模型
class QueryResult {
  /// 查询结果行数据
  final List<Map<String, dynamic>> rows;

  /// 列名列表
  final List<String> columns;

  QueryResult({
    required this.rows,
    required this.columns,
  });
}