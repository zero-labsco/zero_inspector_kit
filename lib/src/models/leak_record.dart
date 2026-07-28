/// 泄漏检测状态枚举 / Leak detection status enum
///
/// 描述单个被追踪对象当前所处的检测阶段
/// Describes the current detection phase of a single tracked object
enum LeakStatus {
  /// 追踪中，未到达预期释放时间 / Under tracking, not reached expected release time
  tracking,

  /// 已超过预期释放时间，正在验证（将触发 GC 后再检查）
  /// Exceeded expected release time, verifying (will trigger GC then re-check)
  verifying,

  /// 检测到疑似泄漏：对象在预期释放时间后仍存活
  /// Suspected leak detected: object still alive after expected release time
  leaked,

  /// 对象已正常释放（已被 GC）/ Object has been released normally (GC'd)
  released,
}

/// 单个被追踪对象的记录 / Record of a single tracked object
///
/// 使用 Dart 2.17+ 的 [WeakReference] 弱引用持有对象，不会阻止对象被 GC
/// Holds object using Dart 2.17+ [WeakReference] weak reference,
/// will not prevent object from being GC'd
///
/// 检测逻辑 / Detection logic:
/// 1. 调用 [MemoryInspectorService.trackObject] 注册对象，进入 [tracking] 状态
///    Call [MemoryInspectorService.trackObject] to register object, enters [tracking] state
/// 2. 超过 [expectedReleaseAfter] 时长后，进入 [verifying] 状态，尝试触发 GC
///    After [expectedReleaseAfter] duration, enters [verifying] state, attempts to trigger GC
/// 3. GC 后若 WeakReference.target != null，判定为 [leaked]（疑似泄漏）
///    After GC, if WeakReference.target != null, determined as [leaked] (suspected leak)
/// 4. 若 WeakReference.target == null，判定为 [released]（正常释放）
///    If WeakReference.target == null, determined as [released] (normal release)
class LeakRecord {
  /// 唯一标识（对象 hashCode）/ Unique identifier (object hashCode)
  final int objectId;

  /// 对象运行时类型字符串 / Object runtime type string
  ///
  /// 用于 UI 展示时识别对象类型，弱引用丢失后仍可保留类型信息
  /// Used for UI display to identify object type,
  /// type info is preserved even after weak reference becomes null
  final String objectType;

  /// 用户自定义标签（可选）/ User-defined custom tag (optional)
  ///
  /// 用于区分同类型的不同对象，如 "HomePage_controller"、"DetailPage_bloc"
  /// Used to distinguish different objects of same type,
  /// e.g. "HomePage_controller", "DetailPage_bloc"
  final String? tag;

  /// 对象的弱引用 / Weak reference to object
  ///
  /// 使用 [WeakReference] 不会阻止对象被 GC
  /// Using [WeakReference] will not prevent object from being GC'd
  /// 当对象被 GC 后，此引用的 [WeakReference.target] 将为 null
  /// After object is GC'd, [WeakReference.target] of this reference will be null
  final WeakReference<Object> weakRef;

  /// 注册追踪的时间 / Time when tracking was registered
  final DateTime trackedAt;

  /// 预期对象应被释放的时间 / Time when object is expected to be released
  ///
  /// 计算方式：trackedAt + expectedReleaseAfter
  /// Calculation: trackedAt + expectedReleaseAfter
  final DateTime expectedReleaseAt;

  /// 超过预期释放时间后，触发 GC 的时间（用于验证阶段）
  /// Time when GC was triggered after exceeding expected release time (for verification phase)
  ///
  /// 仅在 [status] 为 [LeakStatus.verifying] 或 [LeakStatus.leaked] 时有值
  /// Only has value when [status] is [LeakStatus.verifying] or [LeakStatus.leaked]
  DateTime? gcTriggeredAt;

  /// 判定为泄漏的时间 / Time when determined as leaked
  ///
  /// 仅在 [status] 为 [LeakStatus.leaked] 时有值
  /// Only has value when [status] is [LeakStatus.leaked]
  DateTime? leakedAt;

  /// 检测状态 / Detection status
  LeakStatus _status;

  /// 获取检测状态 / Get detection status
  LeakStatus get status => _status;

  /// 设置检测状态 / Set detection status
  set status(LeakStatus value) {
    _status = value;
    // 记录关键时间点 / Record key time points
    if (value == LeakStatus.leaked && leakedAt == null) {
      leakedAt = DateTime.now();
    }
  }

  /// 构造函数 / Constructor
  ///
  /// [objectId] 对象唯一标识（通常为 hashCode）/ Object unique id (usually hashCode)
  /// [objectType] 对象类型字符串 / Object type string
  /// [weakRef] 对象弱引用 / Object weak reference
  /// [trackedAt] 注册时间 / Registration time
  /// [expectedReleaseAt] 预期释放时间 / Expected release time
  /// [tag] 自定义标签 / Custom tag
  LeakRecord({
    required this.objectId,
    required this.objectType,
    required this.weakRef,
    required this.trackedAt,
    required this.expectedReleaseAt,
    this.tag,
    this.gcTriggeredAt,
    this.leakedAt,
    LeakStatus status = LeakStatus.tracking,
  }) : _status = status;

  /// 是否已过期（超过预期释放时间）/ Whether expired (exceeded expected release time)
  bool get isExpired => DateTime.now().isAfter(expectedReleaseAt);

  /// 是否已释放（弱引用 target 为 null）/ Whether released (weak ref target is null)
  bool get isReleased => weakRef.target == null;

  /// 从注册到现在经过的时长 / Elapsed duration since registration
  Duration get elapsed => DateTime.now().difference(trackedAt);

  /// 超过预期释放时间的时长（未过期返回 Duration.zero）
  /// Duration exceeding expected release time (returns Duration.zero if not expired)
  Duration get overdue {
    final now = DateTime.now();
    if (now.isBefore(expectedReleaseAt)) return Duration.zero;
    return now.difference(expectedReleaseAt);
  }

  /// 获取显示名称（标签 + 类型）/ Get display name (tag + type)
  String get displayName {
    if (tag != null && tag!.isNotEmpty) {
      return '$tag ($objectType)';
    }
    return objectType;
  }

  @override
  String toString() {
    return 'LeakRecord($displayName, id=$objectId, status=$status, '
        'trackedAt=${trackedAt.millisecondsSinceEpoch}, '
        'expectedReleaseAt=${expectedReleaseAt.millisecondsSinceEpoch}, '
        'isReleased=$isReleased)';
  }
}
