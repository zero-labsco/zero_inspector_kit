import '../models/database_info.dart';
import 'database_provider.dart';

/// 一个最小化的 SharedPreferences 形状契约，仅声明查看所需方法。
/// 插件本身不依赖 `shared_preferences`，用户传入自己持有的实例即可，
/// 从而自动适配任意版本、避免依赖冲突。
///
/// A minimal SharedPreferences-shaped contract declaring only what the viewer
/// needs. The plugin does NOT depend on `shared_preferences`; callers pass in
/// their own instance so any version is supported without version conflicts.
abstract class SharedPrefsLike {
  Set<String> getKeys();
  Object? get(String key);
  bool? getBool(String key);
  int? getInt(String key);
  double? getDouble(String key);
  String? getString(String key);
  List<String>? getStringList(String key);
}

/// [SharedPrefsLike] 的默认适配：包裹真实的 `SharedPreferences` 实例。
/// Default adapter wrapping a real `SharedPreferences` instance.
class SharedPreferencesAdapter implements SharedPrefsLike {
  const SharedPreferencesAdapter(this._prefs);

  final dynamic _prefs;

  @override
  Set<String> getKeys() => _prefs.getKeys();

  @override
  Object? get(String key) => _prefs.get(key);

  @override
  bool? getBool(String key) => _prefs.getBool(key);

  @override
  int? getInt(String key) => _prefs.getInt(key);

  @override
  double? getDouble(String key) => _prefs.getDouble(key);

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  List<String>? getStringList(String key) => _prefs.getStringList(key);
}

/// SharedPreferences 查看器 Provider。
/// 将一组键值对呈现为一个「数据库 / 一张表」，复用 DatabaseViewer 的浏览与导出流程。
///
/// SharedPreferences viewer provider. Exposes the key-value store as a single
/// database / table, reusing DatabaseViewer's browse & export flow.
class SharedPrefsProvider implements DatabaseProvider {
  SharedPrefsProvider({
    required SharedPrefsLike prefs,
    this.name = 'SharedPreferences',
  }) : _prefs = prefs;

  final SharedPrefsLike _prefs;
  @override
  final String name;

  static const String _tableName = 'preferences';

  @override
  Future<List<DatabaseInfo>> getDatabases() async {
    final count = _prefs.getKeys().length;
    return [
      DatabaseInfo(
        name: name,
        path: 'prefs://$name',
        tables: [
          TableInfo(name: _tableName, rowCount: count, columns: const []),
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
    var keys = _prefs.getKeys().toList()..sort();
    if (desc) keys = keys.reversed.toList();
    if (whereKeyword != null && whereKeyword.isNotEmpty) {
      final kw = whereKeyword.toLowerCase();
      keys = keys.where((k) => k.toLowerCase().contains(kw)).toList();
    }
    final total = keys.length;
    final windowed = keys.skip(offset).take(limit).map((k) {
      final v = _prefs.get(k);
      return <String, dynamic>{
        'key': k,
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

  String _typeName(Object? v) {
    if (v is bool) return 'bool';
    if (v is int) return 'int';
    if (v is double) return 'double';
    if (v is String) return 'String';
    if (v is List) return 'List<String>';
    return v?.runtimeType.toString() ?? 'null';
  }

  String _encode(Object? v) {
    if (v == null) return 'null';
    if (v is String) return v;
    if (v is List) return v.join(', ');
    return v.toString();
  }
}
