import '../models/database_info.dart';
import 'database_provider.dart';

/// 数据库服务 / Database service
/// 统一管理所有数据库提供者，提供数据库查询接口 / Unified management of all database providers, providing database query interface
class DatabaseService {
  DatabaseService._();

  /// 单例实例 / Singleton instance
  static final DatabaseService instance = DatabaseService._();

  /// 获取所有数据库列表 / Get all database list
  /// 遍历所有已注册的数据库提供者，合并结果 / Iterate through all registered database providers and merge results
  Future<List<DatabaseInfo>> getDatabases() async {
    final databases = <DatabaseInfo>[];
    for (final provider in DatabaseRegistry.instance.providers) {
      try {
        final result = await provider.getDatabases();
        databases.addAll(result);
      } catch (_) {}
    }
    return databases;
  }

  /// 查询指定表的数据 / Query specified table data
  /// 按顺序尝试所有已注册的数据库提供者，返回第一个成功的结果 / Try all registered database providers in order, return the first successful result
  Future<QueryResult> queryTable(
    String dbPath,
    String tableName, {
    int limit = 50,
    int offset = 0,
    String? orderBy,
    bool desc = false,
    String? whereKeyword,
  }) async {
    QueryResult? firstFailure;
    for (final provider in DatabaseRegistry.instance.providers) {
      try {
        final result = await provider.queryTable(
          dbPath,
          tableName,
          limit: limit,
          offset: offset,
          orderBy: orderBy,
          desc: desc,
          whereKeyword: whereKeyword,
        );
        // 以"提供者是否报错"判定成功，而不是"结果是否非空"：此前用
        // `rows.isNotEmpty`，一张**合法的空表**会让循环继续尝试后面的 provider，
        // 于是可能把另一个数据源（Hive / SharedPreferences）的内容当成这个
        // dbPath 的结果返回。
        // Success is decided by whether the provider errored, not by whether rows
        // came back: this used to test `rows.isNotEmpty`, so a legitimately empty
        // table made the loop keep trying later providers and could return another
        // data source's (Hive / SharedPreferences) content for this dbPath.
        if (!result.hasError) return result;
        firstFailure ??= result;
      } catch (_) {}
    }
    return firstFailure ?? QueryResult(rows: [], columns: []);
  }
}
