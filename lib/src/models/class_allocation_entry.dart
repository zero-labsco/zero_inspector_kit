/// 单个 Dart 类的堆分配统计 / Per-class Dart heap allocation stats.
///
/// 来自 VM Service `getAllocationProfile` RPC 的 `ClassHeapStats` 条目。
/// Derived from a `ClassHeapStats` entry of the VM Service
/// `getAllocationProfile` RPC.
class ClassAllocationEntry {
  const ClassAllocationEntry({
    required this.className,
    required this.classId,
    required this.instances,
    required this.bytes,
    this.newInstances = 0,
    this.newBytes = 0,
  });

  /// 类名 / Class name (e.g. `String`, `Uint8List`).
  final String className;

  /// VM Service 类 ID（来自 `@Class.id`）/ VM Service class id (from `@Class.id`).
  final String classId;

  /// 当前存活实例总数 / Total live instances.
  final int instances;

  /// 当前占用字节总数 / Total bytes occupied.
  final int bytes;

  /// 上次 GC 以来新分配的实例数 / Instances allocated since last GC.
  final int newInstances;

  /// 上次 GC 以来新分配的字节 / Bytes allocated since last GC.
  final int newBytes;

  /// 解析 VM Service `getAllocationProfile` 响应为类分配列表（按 bytes 降序）。
  /// Parse a VM Service `getAllocationProfile` response into a sorted list
  /// (descending by bytes).
  ///
  /// 同时兼容两种字段形态：新版 `new`/`old` HeapSpace 对象，以及旧版顶层
  /// `count`/`size`/`bytes` 字段。/ Handles both the new `new`/`old` HeapSpace
  /// shape and the legacy top-level `count`/`size`/`bytes` fields.
  static List<ClassAllocationEntry> fromJson(Map<String, dynamic> json) {
    final raw = json['classes'];
    if (raw is! List) return const [];

    final List<ClassAllocationEntry> entries = [];
    for (final item in raw) {
      if (item is! Map<String, dynamic>) continue;

      final classMap = item['class'];
      final name = classMap is Map ? (classMap['name'] as String?) : null;
      // 跳过无名 / 空名 / VM 内部哨兵类（如 "::"）。
      // Skip unnamed / empty / VM internal sentinel classes (e.g. "::").
      if (name == null || name.isEmpty || name == '::') continue;

      final newSpace = item['new'];
      final oldSpace = item['old'];
      final newInstances = _asInt(newSpace is Map ? newSpace['count'] : null);
      final newBytes = _asInt(newSpace is Map ? newSpace['size'] : null);
      final oldInstances = _asInt(oldSpace is Map ? oldSpace['count'] : null);
      final oldBytes = _asInt(oldSpace is Map ? oldSpace['size'] : null);

      // 旧版协议兜底（新协议用 new/old，不应同时出现，优先用 new/old）。
      // Legacy protocol fallback. Prefer new/old when present to avoid double
      // counting if both shapes ever appear.
      final legacyInstances = _asInt(item['count']) + _asInt(item['instances']);
      final legacyBytes = _asInt(item['size']) + _asInt(item['bytes']);
      final hasNewOld = (newInstances + oldInstances + newBytes + oldBytes) > 0;
      final instances = hasNewOld
          ? (newInstances + oldInstances)
          : legacyInstances;
      final bytes = hasNewOld ? (newBytes + oldBytes) : legacyBytes;

      if (instances <= 0 && bytes <= 0) continue;

      entries.add(
        ClassAllocationEntry(
          className: name,
          classId: classMap is Map ? (classMap['id'] as String? ?? '') : '',
          instances: instances,
          bytes: bytes,
          newInstances: newInstances,
          newBytes: newBytes,
        ),
      );
    }

    entries.sort((a, b) => b.bytes.compareTo(a.bytes));
    return entries;
  }

  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  @override
  String toString() =>
      'ClassAllocationEntry($className: $instances objs, ${bytes}B)';
}
