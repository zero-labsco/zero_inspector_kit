import '../models/database_info.dart';

/// 数据库提供者抽象接口 / Database provider abstract interface
///
/// 通过实现此接口，可以支持多种数据库类型（SQLite、Hive、Isar等）
/// By implementing this interface, multiple database types can be supported (SQLite, Hive, Isar, etc.)
///
/// 实现示例 / Implementation example:
/// ```dart
/// class MyCustomDatabaseProvider implements DatabaseProvider {
///   @override
///   String get name => 'CustomDB';
///
///   @override
///   Future<List<DatabaseInfo>> getDatabases() async {
///     // 返回数据库列表 / Return database list
///     return [];
///   }
///
///   @override
///   Future<QueryResult> queryTable(String dbPath, String tableName, {int limit = 50}) async {
///     // 执行查询并返回结果 / Execute query and return result
///     return QueryResult(columns: [], rows: []);
///   }
/// }
/// ```
abstract class DatabaseProvider {
  /// 数据库类型名称，用于标识不同的数据库提供者 / Database type name for identifying different database providers
  String get name;

  /// 获取所有数据库列表 / Get all database list
  Future<List<DatabaseInfo>> getDatabases();

  /// 查询指定表的数据 / Query specified table data
  /// [dbPath] 数据库文件路径 / Database file path
  /// [tableName] 表名称 / Table name
  /// [limit] 返回行数限制，默认50 / Return row limit, default 50
  Future<QueryResult> queryTable(
    String dbPath,
    String tableName, {
    int limit = 50,
  });
}

/// 数据库提供者注册表 / Database provider registry
///
/// 用于管理所有已注册的数据库提供者，支持动态添加和移除
/// Used to manage all registered database providers, supporting dynamic addition and removal
///
/// 使用方式 / Usage:
/// ```dart
/// // 注册默认的SQLite提供者 / Register default SQLite provider
/// DatabaseRegistry.instance.registerProvider(SqliteDatabaseProvider());
///
/// // 注册自定义数据库提供者 / Register custom database provider
/// DatabaseRegistry.instance.registerProvider(MyCustomDatabaseProvider());
/// ```
class DatabaseRegistry {
  DatabaseRegistry._();

  /// 单例实例 / Singleton instance
  static final DatabaseRegistry instance = DatabaseRegistry._();

  /// 已注册的数据库提供者列表 / Registered database provider list
  final List<DatabaseProvider> _providers = [];

  /// 注册数据库提供者 / Register database provider
  /// [provider] 要注册的数据库提供者 / Database provider to register
  void registerProvider(DatabaseProvider provider) {
    if (!_providers.any((p) => p.name == provider.name)) {
      _providers.add(provider);
    }
  }

  /// 注销数据库提供者 / Unregister database provider
  /// [name] 数据库提供者名称 / Database provider name
  void unregisterProvider(String name) {
    _providers.removeWhere((p) => p.name == name);
  }

  /// 获取所有已注册的数据库提供者（只读）/ Get all registered database providers (read-only)
  List<DatabaseProvider> get providers => List.unmodifiable(_providers);
}
