import '../models/database_info.dart';

/// 数据库提供者抽象接口
/// 通过实现此接口，可以支持多种数据库类型（SQLite、Hive、Isar等）
abstract class DatabaseProvider {
  /// 数据库类型名称
  String get name;

  /// 获取所有数据库列表
  Future<List<DatabaseInfo>> getDatabases();

  /// 查询指定表的数据
  /// [dbPath] 数据库文件路径
  /// [tableName] 表名称
  /// [limit] 返回行数限制，默认50
  Future<QueryResult> queryTable(String dbPath, String tableName, {int limit = 50});
}

/// 数据库提供者注册表
/// 用于管理所有已注册的数据库提供者
class DatabaseRegistry {
  DatabaseRegistry._();

  /// 单例实例
  static final DatabaseRegistry instance = DatabaseRegistry._();

  /// 已注册的数据库提供者列表
  final List<DatabaseProvider> _providers = [];

  /// 注册数据库提供者
  void registerProvider(DatabaseProvider provider) {
    if (!_providers.any((p) => p.name == provider.name)) {
      _providers.add(provider);
    }
  }

  /// 注销数据库提供者
  void unregisterProvider(String name) {
    _providers.removeWhere((p) => p.name == name);
  }

  /// 获取所有已注册的数据库提供者（只读）
  List<DatabaseProvider> get providers => List.unmodifiable(_providers);
}