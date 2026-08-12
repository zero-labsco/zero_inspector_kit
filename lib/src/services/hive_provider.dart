import 'dart:convert';

import '../models/database_info.dart';
import 'database_provider.dart';

/// 一个最小化的 Hive Box 形状契约，仅声明查看所需方法。
/// 插件本身不依赖 `hive`，用户传入自己持有的 box 实例即可，
/// 自动适配任意 Hive 版本、避免依赖冲突。
///
/// A minimal Hive Box-shaped contract declaring only what the viewer needs.
/// The plugin does NOT depend on `hive`; callers pass in their own box so any
/// version is supported without version conflicts.
abstract class HiveBoxLike {
  Iterable<dynamic> get keys;
  dynamic get(dynamic key);
  int get length;
}

/// [HiveBoxLike] 的默认适配：包裹真实的 `Box` 实例。
/// Default adapter wrapping a real Hive `Box` instance.
class HiveBoxAdapter implements HiveBoxLike {
  const HiveBoxAdapter(this._box);

  final dynamic _box;

  @override
  Iterable<dynamic> get keys => _box.keys;

  @override
  dynamic get(dynamic key) => _box.get(key);

  @override
  int get length => _box.length;
}

/// Hive 查看器 Provider。
/// 将一个 Hive Box 呈现为一个「数据库 / 一张表」，复用 DatabaseViewer 的浏览与导出流程。
///
/// Hive viewer provider. Exposes a Hive box as a single database / table,
/// reusing DatabaseViewer's browse & export flow.
class HiveProvider implements DatabaseProvider {
  HiveProvider({required HiveBoxLike box, required this.name}) : _box = box;

  final HiveBoxLike _box;
  @override
  final String name;

  static const String _tableName = 'entries';

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    return [
      DatabaseInfo(
        name: name,
        path: 'hive://$name',
        tables: [
          TableInfo(name: _tableName, rowCount: _box.length, columns: const []),
        ],
      ),
    ];
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
    var keys = _box.keys.toList()..sort();
    if (desc) keys = keys.reversed.toList();
    if (whereKeyword != null && whereKeyword.isNotEmpty) {
      final kw = whereKeyword.toLowerCase();
      keys = keys.where((k) => k.toString().toLowerCase().contains(kw)).toList();
    }
    final total = keys.length;
    final windowed = keys.skip(offset).take(limit).map((k) {
      final v = _box.get(k);
      return <String, dynamic>{
        'key': _encodeKey(k),
        'type': _typeName(v),
        'value': _encode(v),
      };
    }).toList();

    return QueryResult(
      columns: const ['key', 'type', 'value'],
      rows: windowed,
      totalRows: total,
    );
  }

  String _encodeKey(dynamic k) => k?.toString() ?? 'null';

  String _typeName(dynamic v) {
    if (v == null) return 'null';
    if (v is bool) return 'bool';
    if (v is int) return 'int';
    if (v is double) return 'double';
    if (v is String) return 'String';
    if (v is List) return 'List';
    if (v is Map) return 'Map';
    return v.runtimeType.toString();
  }

  String _encode(dynamic v) {
    if (v == null) return 'null';
    if (v is String) return v;
    // 复杂对象尝试 JSON 序列化以便阅读；失败则退回 toString。
    // Try JSON for complex objects; fall back to toString on failure.
    try {
      return jsonEncode(v);
    } catch (_) {
      return v.toString();
    }
  }
}
