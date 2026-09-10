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
  /// [offset] 跳过的行数，用于分页 / Rows to skip, for pagination
  /// [orderBy] 排序列名（列名白名单校验）/ Order-by column (validated against actual columns)
  /// [desc] 是否降序 / Descending order when true
  /// [whereKeyword] 单元格级关键字过滤（任一列包含即匹配）/ Cell-level keyword filter
  ///
  /// [offset]/[orderBy]/[desc]/[whereKeyword] 均为命名可选参数，保持向后兼容。
  /// These new parameters are named & optional, preserving backward compatibility.
  Future<QueryResult> queryTable(
    String dbPath,
    String tableName, {
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool desc = false,
    String? whereKeyword,
  });
}

/// 键值型数据源（Hive / SharedPreferences 等）的公共工具
/// Shared helpers for key-value data sources (Hive / SharedPreferences / etc.)
///
/// Hive 与 SharedPreferences 两个 provider 的分页、排序、过滤逻辑此前几乎
/// 逐行重复，且各自带着同样的排序崩溃缺陷，这里收敛为共享实现。
/// The Hive and SharedPreferences providers previously duplicated the paging,
/// sorting and filtering logic almost line for line — and both carried the same
/// sorting crash. The shared implementation lives here now.
class KeyValueQuery {
  KeyValueQuery._();

  /// 默认每页行数 / Default page size
  static const int defaultLimit = 50;

  /// 安全排序：Hive 的 key 是 `dynamic`，同时存在 int 与 String 时
  /// `List.sort()` 会用 `Comparable.compare` 直接抛 TypeError。
  /// 这里同类型按自然序、不同类型按字符串序，永不抛异常。
  /// Safe sort: Hive keys are `dynamic`, and mixing int and String makes
  /// `List.sort()` (which uses `Comparable.compare`) throw a TypeError.
  /// Same types compare naturally, mixed types fall back to string order —
  /// this never throws.
  static void sortKeys(List<dynamic> keys) {
    keys.sort((a, b) {
      if (a is Comparable &&
          b is Comparable &&
          a.runtimeType == b.runtimeType) {
        try {
          return a.compareTo(b);
        } catch (_) {
          // 同类型但不可比较（罕见实现），退回字符串比较。
          // Same type but not comparable (rare); fall back to string compare.
        }
      }
      return a.toString().compareTo(b.toString());
    });
  }

  /// 校验分页参数 / Validate paging parameters
  ///
  /// `LIMIT <= 0` / 负 `OFFSET` 会让 `skip/take` 行为异常（如返回全量），
  /// 这里统一收敛成安全值。
  /// `LIMIT <= 0` or a negative `OFFSET` makes `skip/take` misbehave (e.g.
  /// returning everything), so clamp to safe values.
  static ({int limit, int offset}) clampPaging(int limit, int offset) {
    return (
      limit: limit <= 0 ? defaultLimit : limit,
      offset: offset < 0 ? 0 : offset,
    );
  }
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
