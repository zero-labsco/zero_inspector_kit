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
  Future<QueryResult> queryTable(String dbPath, String tableName, {int limit = 50}) async {
    for (final provider in DatabaseRegistry.instance.providers) {
      try {
        final result = await provider.queryTable(dbPath, tableName, limit: limit);
        if (result.rows.isNotEmpty) return result;
      } catch (_) {}
    }
    return QueryResult(rows: [], columns: []);
  }
}