/// 内存快照模型 / Memory snapshot model
///
/// 记录某一时刻的内存使用数据，包含进程级 RSS、Native 内存分项 与 Dart Heap 详细数据
/// Records memory usage data at a specific moment, including process-level RSS,
/// Native memory breakdown, and Dart Heap details
///
/// 数据来源 / Data sources:
/// - [processRss] 来自 `ProcessInfo.currentRss`，进程级常驻内存大小，始终可用
///   [processRss] from `ProcessInfo.currentRss`, process-level resident memory size, always available
/// - Native 内存分项字段来自原生 Platform Channel（Android Debug.MemoryInfo / iOS mach task_info），
///   真机上 100% 可用
///   Native memory breakdown fields are from native Platform Channel
///   (Android Debug.MemoryInfo / iOS mach task_info), 100% available on real devices
/// - Dart Heap 相关字段来自 VM Service 的 `getMemoryUsage` RPC，仅在 VM Service 可用时有效
///   Dart Heap related fields are from VM Service `getMemoryUsage` RPC, only valid when VM Service is available
class MemorySnapshot {
  /// 采样时间戳（毫秒）/ Sampling timestamp (milliseconds)
  final DateTime timestamp;

  /// 进程常驻内存大小（字节）/ Process resident set size (bytes)
  ///
  /// 来自 `ProcessInfo.currentRss`，包含 Dart Heap + Native 内存 + 共享库等
  /// From `ProcessInfo.currentRss`, includes Dart Heap + Native memory + shared libraries etc.
  /// 此字段始终可用，即使 VM Service 不可用
  /// This field is always available even when VM Service is unavailable
  final int processRss;

  // ============== Native 内存分项（来自 Platform Channel）==============
  // ============== Native memory breakdown (from Platform Channel) ==============

  /// 总 PSS（字节）/ Total PSS (bytes)
  ///
  /// PSS = Private + 按比例分摊的 Shared，Android 上最常用的内存指标
  /// PSS = Private + proportionally shared, most commonly used memory metric on Android
  /// 仅 Android 可用 / Android only
  final int totalPss;

  /// Dalvik/ART PSS（字节）/ Dalvik/ART PSS (bytes)
  ///
  /// Java/Kotlin 堆内存（含 Flutter Framework 的 Java 部分）
  /// Java/Kotlin heap memory (including Java part of Flutter Framework)
  /// 仅 Android 可用 / Android only
  final int dalvikPss;

  /// Native PSS（字节）/ Native PSS (bytes)
  ///
  /// C/C++ 层内存（含 Skia、Flutter Engine Native 部分）
  /// C/C++ layer memory (including Skia, Flutter Engine Native part)
  /// 仅 Android 可用 / Android only
  final int nativePss;

  /// Native 私有脏页（字节）/ Native private dirty (bytes)
  ///
  /// Native 层独占的脏页，不会被共享
  /// Native layer exclusive dirty pages, not shared
  /// 仅 Android 可用 / Android only
  final int nativePrivateDirty;

  /// Dalvik 私有脏页（字节）/ Dalvik private dirty (bytes)
  ///
  /// Java 层独占的脏页
  /// Java layer exclusive dirty pages
  /// 仅 Android 可用 / Android only
  final int dalvikPrivateDirty;

  /// 总私有脏页（字节）/ Total private dirty (bytes)
  final int totalPrivateDirty;

  /// 总 RSS 分项（字节）/ Total RSS breakdown (bytes)
  ///
  /// 来自 Android Debug.MemoryInfo，API 23+ 可用
  /// From Android Debug.MemoryInfo, available on API 23+
  /// 仅 Android 可用 / Android only
  final int totalRss;

  /// Native RSS（字节）/ Native RSS (bytes)
  ///
  /// Native 层 RSS 分项
  /// Native layer RSS breakdown
  /// 仅 Android API 23+ 可用 / Android API 23+ only
  final int nativeRss;

  /// Dalvik RSS（字节）/ Dalvik RSS (bytes)
  ///
  /// Java 层 RSS 分项
  /// Java layer RSS breakdown
  /// 仅 Android API 23+ 可用 / Android API 23+ only
  final int dalvikRss;

  /// iOS 物理内存占用（字节）/ iOS physical memory footprint (bytes)
  ///
  /// iOS 上最准确的内存指标（包含压缩内存）
  /// Most accurate memory metric on iOS (includes compressed memory)
  /// 仅 iOS 可用 / iOS only
  final int physicalFootprint;

  /// iOS 已压缩内存（字节）/ iOS compressed memory (bytes)
  ///
  /// 被系统压缩的内存量
  /// Amount of memory compressed by the system
  /// 仅 iOS 可用 / iOS only
  final int internalCompressed;

  /// iOS 内部内存总量（字节）/ iOS internal memory size (bytes)
  ///
  /// 仅 iOS 可用 / iOS only
  final int internalSize;

  /// 设备物理内存总量（字节）/ Device total physical memory (bytes)
  final int deviceTotalMem;

  /// 设备可用物理内存（字节）/ Device available physical memory (bytes)
  final int deviceAvailMem;

  /// 是否处于低内存状态 / Whether in low memory state
  final bool isLowMemory;

  /// 是否已获取到 Native 内存分项 / Whether Native memory breakdown is available
  ///
  /// 为 false 时表示 Platform Channel 不可用（如桌面平台），Native 字段均为 0
  /// When false, Platform Channel is unavailable (e.g., desktop platforms), all Native fields are 0
  final bool isNativeDataAvailable;

  // ============== Dart Heap 字段（来自 VM Service）==============
  // ============== Dart Heap fields (from VM Service) ==============

  /// Dart Heap 已使用大小（字节）/ Dart Heap used size (bytes)
  ///
  /// 来自 VM Service `getMemoryUsage` RPC 的 `heapUsage` 字段
  /// From `heapUsage` field of VM Service `getMemoryUsage` RPC
  /// 仅在 [isHeapDataAvailable] 为 true 时有效
  /// Only valid when [isHeapDataAvailable] is true
  final int heapUsage;

  /// Dart Heap 容量（字节）/ Dart Heap capacity (bytes)
  final int heapCapacity;

  /// Dart 外部内存使用量（字节）/ Dart external memory usage (bytes)
  ///
  /// 来自 VM Service `getMemoryUsage` RPC 的 `externalUsage` 字段
  /// From `externalUsage` field of VM Service `getMemoryUsage` RPC
  /// 表示通过 dart:ffi 分配的 Native 内存
  /// Represents Native memory allocated via dart:ffi
  final int externalUsage;

  /// 新生代已使用大小（字节）/ New space used size (bytes)
  final int newSpaceUsage;

  /// 新生代容量（字节）/ New space capacity (bytes)
  final int newSpaceCapacity;

  /// 新生代外部内存使用量（字节）/ New space external memory usage (bytes)
  final int newSpaceExternalUsage;

  /// 老生代已使用大小（字节）/ Old space used size (bytes)
  final int oldSpaceUsage;

  /// 老生代容量（字节）/ Old space capacity (bytes)
  final int oldSpaceCapacity;

  /// 老生代外部内存使用量（字节）/ Old space external memory usage (bytes)
  final int oldSpaceExternalUsage;

  /// 是否已获取到 Dart Heap 详细数据 / Whether Dart Heap detailed data is available
  ///
  /// 为 false 时表示 VM Service 不可用，所有 Dart Heap 字段均为 0
  /// When false, VM Service is unavailable and all Dart Heap fields are 0
  /// UI 应据此判断是否显示 N/A 占位
  /// UI should use this to determine whether to show N/A placeholder
  final bool isHeapDataAvailable;

  /// 构造函数 / Constructor
  ///
  /// [processRss] 必填，其他字段在相应数据源不可用时使用默认值 0
  /// [processRss] is required, other fields default to 0 when corresponding data source is unavailable
  MemorySnapshot({
    required this.processRss,
    // Native 字段默认值 / Native field defaults
    this.totalPss = 0,
    this.dalvikPss = 0,
    this.nativePss = 0,
    this.nativePrivateDirty = 0,
    this.dalvikPrivateDirty = 0,
    this.totalPrivateDirty = 0,
    this.totalRss = 0,
    this.nativeRss = 0,
    this.dalvikRss = 0,
    this.physicalFootprint = 0,
    this.internalCompressed = 0,
    this.internalSize = 0,
    this.deviceTotalMem = 0,
    this.deviceAvailMem = 0,
    this.isLowMemory = false,
    this.isNativeDataAvailable = false,
    // Dart Heap 字段默认值 / Dart Heap field defaults
    this.heapUsage = 0,
    this.heapCapacity = 0,
    this.externalUsage = 0,
    this.newSpaceUsage = 0,
    this.newSpaceCapacity = 0,
    this.newSpaceExternalUsage = 0,
    this.oldSpaceUsage = 0,
    this.oldSpaceCapacity = 0,
    this.oldSpaceExternalUsage = 0,
    this.isHeapDataAvailable = false,
  }) : timestamp = DateTime.now();

  /// 创建一个仅包含进程 RSS 的快照 / Create a snapshot with only process RSS
  ///
  /// 用于 Platform Channel 和 VM Service 均不可用时的降级场景
  /// Used for degraded scenarios when both Platform Channel and VM Service are unavailable
  factory MemorySnapshot.processOnly(int processRss) {
    return MemorySnapshot(
      processRss: processRss,
      isHeapDataAvailable: false,
      isNativeDataAvailable: false,
    );
  }

  /// 从 Platform Channel Map 创建 Native 内存数据 / Create Native memory data from Platform Channel Map
  ///
  /// [map] 为 PlatformChannel.getProcessMemoryInfo() 返回的 Map
  /// [map] is the Map returned by PlatformChannel.getProcessMemoryInfo()
  static MemorySnapshot fromNativeMap({
    required int processRss,
    required Map<String, dynamic> map,
    bool isHeapDataAvailable = false,
  }) {
    // 辅助函数：从 Map 读取 int 值 / Helper: read int value from Map
    int readInt(String key) {
      final value = map[key];
      if (value == null) return 0;
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    // 辅助函数：从 Map 读取 bool 值 / Helper: read bool value from Map
    bool readBool(String key) {
      final value = map[key];
      if (value is bool) return value;
      return false;
    }

    return MemorySnapshot(
      processRss: processRss,
      // Native 字段 / Native fields
      totalPss: readInt('totalPss'),
      dalvikPss: readInt('dalvikPss'),
      nativePss: readInt('nativePss'),
      nativePrivateDirty: readInt('nativePrivateDirty'),
      dalvikPrivateDirty: readInt('dalvikPrivateDirty'),
      totalPrivateDirty: readInt('totalPrivateDirty'),
      totalRss: readInt('totalRss'),
      nativeRss: readInt('nativeRss'),
      dalvikRss: readInt('dalvikRss'),
      physicalFootprint: readInt('physicalFootprint'),
      internalCompressed: readInt('internalCompressed'),
      internalSize: readInt('internalSize'),
      deviceTotalMem: readInt('totalMem'),
      deviceAvailMem: readInt('availMem'),
      isLowMemory: readBool('lowMemory'),
      isNativeDataAvailable: true,
      // Dart Heap 字段默认 0，由服务层后续填充
      // Dart Heap fields default to 0, filled by service layer later
      isHeapDataAvailable: isHeapDataAvailable,
    );
  }

  /// 创建一个包含完整 Dart Heap 数据的快照 / Create a snapshot with full Dart Heap data
  ///
  /// 用于 VM Service 可用时 / Used when VM Service is available
  factory MemorySnapshot.withHeapData({
    required int processRss,
    required int heapUsage,
    required int heapCapacity,
    required int externalUsage,
    required int newSpaceUsage,
    required int newSpaceCapacity,
    required int newSpaceExternalUsage,
    required int oldSpaceUsage,
    required int oldSpaceCapacity,
    required int oldSpaceExternalUsage,
  }) {
    return MemorySnapshot(
      processRss: processRss,
      heapUsage: heapUsage,
      heapCapacity: heapCapacity,
      externalUsage: externalUsage,
      newSpaceUsage: newSpaceUsage,
      newSpaceCapacity: newSpaceCapacity,
      newSpaceExternalUsage: newSpaceExternalUsage,
      oldSpaceUsage: oldSpaceUsage,
      oldSpaceCapacity: oldSpaceCapacity,
      oldSpaceExternalUsage: oldSpaceExternalUsage,
      isHeapDataAvailable: true,
    );
  }

  /// 在现有快照基础上补充 Dart Heap 数据
  /// Supplement Dart Heap data on top of existing snapshot
  ///
  /// 用于合并 Native 数据和 Dart Heap 数据 / Used to merge Native data and Dart Heap data
  MemorySnapshot copyWithHeapData({
    required int heapUsage,
    required int heapCapacity,
    required int externalUsage,
    required int newSpaceUsage,
    required int newSpaceCapacity,
    required int newSpaceExternalUsage,
    required int oldSpaceUsage,
    required int oldSpaceCapacity,
    required int oldSpaceExternalUsage,
    required bool isHeapDataAvailable,
  }) {
    return MemorySnapshot(
      processRss: processRss,
      // 保留 Native 字段 / Preserve Native fields
      totalPss: totalPss,
      dalvikPss: dalvikPss,
      nativePss: nativePss,
      nativePrivateDirty: nativePrivateDirty,
      dalvikPrivateDirty: dalvikPrivateDirty,
      totalPrivateDirty: totalPrivateDirty,
      totalRss: totalRss,
      nativeRss: nativeRss,
      dalvikRss: dalvikRss,
      physicalFootprint: physicalFootprint,
      internalCompressed: internalCompressed,
      internalSize: internalSize,
      deviceTotalMem: deviceTotalMem,
      deviceAvailMem: deviceAvailMem,
      isLowMemory: isLowMemory,
      isNativeDataAvailable: isNativeDataAvailable,
      // 设置 Dart Heap 字段 / Set Dart Heap fields
      heapUsage: heapUsage,
      heapCapacity: heapCapacity,
      externalUsage: externalUsage,
      newSpaceUsage: newSpaceUsage,
      newSpaceCapacity: newSpaceCapacity,
      newSpaceExternalUsage: newSpaceExternalUsage,
      oldSpaceUsage: oldSpaceUsage,
      oldSpaceCapacity: oldSpaceCapacity,
      oldSpaceExternalUsage: oldSpaceExternalUsage,
      isHeapDataAvailable: isHeapDataAvailable,
    );
  }

  /// 转换为 JSON Map / Convert to JSON Map
  ///
  /// 用于序列化存储或调试输出
  /// Used for serialization storage or debug output
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'processRss': processRss,
      // Native 字段 / Native fields
      'totalPss': totalPss,
      'dalvikPss': dalvikPss,
      'nativePss': nativePss,
      'nativePrivateDirty': nativePrivateDirty,
      'dalvikPrivateDirty': dalvikPrivateDirty,
      'totalPrivateDirty': totalPrivateDirty,
      'totalRss': totalRss,
      'nativeRss': nativeRss,
      'dalvikRss': dalvikRss,
      'physicalFootprint': physicalFootprint,
      'internalCompressed': internalCompressed,
      'internalSize': internalSize,
      'deviceTotalMem': deviceTotalMem,
      'deviceAvailMem': deviceAvailMem,
      'isLowMemory': isLowMemory,
      'isNativeDataAvailable': isNativeDataAvailable,
      // Dart Heap 字段 / Dart Heap fields
      'heapUsage': heapUsage,
      'heapCapacity': heapCapacity,
      'externalUsage': externalUsage,
      'newSpaceUsage': newSpaceUsage,
      'newSpaceCapacity': newSpaceCapacity,
      'newSpaceExternalUsage': newSpaceExternalUsage,
      'oldSpaceUsage': oldSpaceUsage,
      'oldSpaceCapacity': oldSpaceCapacity,
      'oldSpaceExternalUsage': oldSpaceExternalUsage,
      'isHeapDataAvailable': isHeapDataAvailable,
    };
  }

  @override
  String toString() {
    return 'MemorySnapshot(rss=${processRss}B, '
        'native(pss=${totalPss}B, nativePss=${nativePss}B, dalvikPss=${dalvikPss}B, '
        'footprint=${physicalFootprint}B), '
        'heap=${heapUsage}B/${heapCapacity}B, '
        'new=$newSpaceUsage/$newSpaceCapacity, old=$oldSpaceUsage/$oldSpaceCapacity, '
        'nativeAvailable=$isNativeDataAvailable, heapAvailable=$isHeapDataAvailable)';
  }
}
