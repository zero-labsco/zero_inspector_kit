import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/leak_record.dart';
import '../models/memory_snapshot.dart';
import '../platform/platform_channel.dart';
import 'database_service.dart';
import 'alert_service.dart';

/// 内存检查服务 / Memory inspector service
///
/// 负责采集应用内存相关数据，包括：
/// Responsible for collecting app memory-related data, including:
/// - 进程级 RSS 内存（来自 `ProcessInfo.currentRss`，始终可用）
///   Process-level RSS memory (from `ProcessInfo.currentRss`, always available)
/// - Native 内存分项（来自 Platform Channel，真机上 100% 可用）
///   Native memory breakdown (from Platform Channel, 100% available on real devices)
///   - Android: Debug.MemoryInfo（PSS、Private Dirty、RSS 分项）
///     Android: Debug.MemoryInfo (PSS, Private Dirty, RSS breakdown)
///   - iOS: mach task_info（physicalFootprint、compressed、internal）
///     iOS: mach task_info (physicalFootprint, compressed, internal)
/// - Dart Heap 详细数据（来自 VM Service，仅 debug/profile 模式可用，真机可能不可用）
///   Dart Heap detailed data (from VM Service, only available in debug/profile mode,
///   may be unavailable on real devices)
/// - 图片缓存统计 / Image cache statistics
/// - 应用存储统计 / App storage statistics
///
/// 使用方式 / Usage:
/// ```dart
/// // 启用监控（开启定时器和 VM Service 连接）
/// // Enable monitoring (start timers and VM Service connection)
/// MemoryInspectorService.instance.isEnabled = true;
///
/// // 或调用 startMonitoring() / Or call startMonitoring()
/// MemoryInspectorService.instance.startMonitoring();
///
/// // 关闭监控（停止所有定时器，断开 VM Service）
/// // Disable monitoring (stop all timers, disconnect VM Service)
/// MemoryInspectorService.instance.isEnabled = false;
/// ```
///
/// 优雅降级 / Graceful degradation:
/// - Native 内存分项在桌面平台不可用，UI 会显示 N/A
///   Native memory breakdown is unavailable on desktop platforms, UI will show N/A
/// - Dart Heap 数据在 release 模式或 Android 真机连接失败时不可用，UI 会显示 N/A
///   Dart Heap data is unavailable in release mode or when Android real device
///   connection fails, UI will display N/A placeholder
/// - 进程 RSS 始终可用 / Process RSS is always available
class MemoryInspectorService extends ChangeNotifier {
  MemoryInspectorService._();

  /// 单例实例 / Singleton instance
  static final MemoryInspectorService instance = MemoryInspectorService._();

  // ==================== 常量配置 / Constants ====================

  /// 进程 RSS 与 Dart Heap 采集间隔（毫秒）/ Process RSS and Dart Heap collection interval (ms)
  ///
  /// 与项目约定一致：500ms 刷新
  /// Consistent with project convention: 500ms refresh
  static const int _heapRefreshIntervalMs = 500;

  /// Native 内存采集间隔（毫秒）/ Native memory collection interval (ms)
  ///
  /// Platform Channel 调用比 ProcessInfo 慢，且数据变化较慢，3 秒采集一次
  /// Platform Channel calls are slower than ProcessInfo, and data changes slowly,
  /// so collect once every 3 seconds
  static const int _nativeRefreshIntervalMs = 3000;

  /// 存储统计刷新间隔（毫秒）/ Storage stats refresh interval (ms)
  static const int _storageRefreshIntervalMs = 3000;

  /// 历史快照最大数量 / Maximum number of historical snapshots
  ///
  /// 240 条 × 500ms = 2 分钟历史窗口
  /// 240 entries × 500ms = 2-minute history window
  static const int _maxSnapshots = 240;

  /// VM Service 连接初始延迟（毫秒）/ VM Service connection initial delay (ms)
  ///
  /// 等待 Flutter 引擎启动 VM Service Web Server
  /// Wait for Flutter engine to start VM Service web server
  static const int _vmServiceInitialDelayMs = 500;

  /// VM Service 连接最大重试次数 / VM Service connection max retry count
  static const int _vmServiceMaxRetries = 5;

  /// VM Service 连接重试间隔（毫秒）/ VM Service connection retry interval (ms)
  static const int _vmServiceRetryIntervalMs = 1000;

  /// 泄漏检测检查间隔（毫秒）/ Leak detection check interval (ms)
  ///
  /// 每 2 秒检查一次被追踪对象的存活状态
  /// Checks tracked objects' alive status every 2 seconds
  static const int _leakDetectionIntervalMs = 2000;

  /// 对象追踪的默认预期释放时间 / Default expected release time for object tracking
  ///
  /// 若用户调用 trackObject 时未指定 expectedReleaseAfter，默认 30 秒
  /// If expectedReleaseAfter is not specified when calling trackObject, defaults to 30 seconds
  static const Duration _defaultExpectedReleaseAfter = Duration(seconds: 30);

  /// 最大追踪对象数量 / Maximum tracked object count
  ///
  /// 超过此数量时，最旧的已释放（released）记录会被移除
  /// When exceeding this count, oldest released records will be removed
  static const int _maxTrackedRecords = 500;

  /// 超过预期释放时间后，GC 验证阶段的等待时长（毫秒）
  /// Wait duration for GC verification phase after exceeding expected release time (ms)
  ///
  /// 进入 verifying 状态后，等待此时长让 GC 完成再判定是否泄漏
  /// After entering verifying state, wait this duration for GC to complete
  /// before determining whether it's a leak
  static const int _leakVerifyWaitMs = 3000;

  // ==================== 监控状态 / Monitoring State ====================

  /// 是否正在监控 / Whether monitoring is active
  bool _isMonitoring = false;

  /// 获取是否正在监控 / Get whether monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// 内存数据采集定时器（RSS + Dart Heap）/ Memory data collection timer (RSS + Dart Heap)
  Timer? _memoryTimer;

  /// Native 内存采集定时器 / Native memory collection timer
  ///
  /// 每 3 秒通过 Platform Channel 采集一次 Native 内存分项
  /// Collects Native memory breakdown via Platform Channel every 3 seconds
  Timer? _nativeMemoryTimer;

  /// 存储统计刷新定时器 / Storage stats refresh timer
  Timer? _storageTimer;

  /// 泄漏检测检查定时器 / Leak detection check timer
  Timer? _leakDetectionTimer;

  // ==================== 泄漏检测 / Leak Detection ====================

  /// 所有被追踪对象的记录（按 objectId 索引）/ All tracked object records (indexed by objectId)
  ///
  /// 包含 tracking、verifying、leaked、released 四种状态的记录
  /// Contains records in all four states: tracking, verifying, leaked, released
  final Map<int, LeakRecord> _trackedRecords = {};

  /// 获取所有泄漏检测记录的只读快照 / Get read-only snapshot of all leak detection records
  List<LeakRecord> get leakRecords => _trackedRecords.values.toList();

  /// 获取检测到的疑似泄漏对象列表 / Get list of detected suspected leak objects
  List<LeakRecord> get leakedRecords => _trackedRecords.values
      .where((r) => r.status == LeakStatus.leaked)
      .toList();

  /// 获取追踪中（尚未过期）的对象数量 / Get count of objects under tracking (not yet expired)
  int get trackingCount => _trackedRecords.values
      .where((r) => r.status == LeakStatus.tracking)
      .length;

  /// 获取疑似泄漏对象数量 / Get suspected leak object count
  int get leakedCount =>
      _trackedRecords.values.where((r) => r.status == LeakStatus.leaked).length;

  /// 获取已正常释放的对象数量 / Get normally released object count
  int get releasedCount => _trackedRecords.values
      .where((r) => r.status == LeakStatus.released)
      .length;

  // ==================== 进程级内存 / Process-level Memory ====================

  /// 当前进程常驻内存大小（字节）/ Current process resident set size (bytes)
  ///
  /// 来自 `ProcessInfo.currentRss`，始终可用
  /// From `ProcessInfo.currentRss`, always available
  int _currentProcessRss = 0;

  /// 获取当前进程常驻内存大小 / Get current process resident set size
  int get currentProcessRss => _currentProcessRss;

  // ==================== Native 内存分项 / Native Memory Breakdown ====================

  /// 是否支持 Native 内存采集（仅 Android/iOS 真机）/ Whether Native memory collection is supported
  ///
  /// 桌面平台返回 false / Returns false on desktop platforms
  bool _isNativeSupported = false;

  /// 获取是否支持 Native 内存采集 / Get whether Native memory collection is supported
  bool get isNativeSupported => _isNativeSupported;

  /// 最近一次 Native 内存 Map（缓存）/ Last Native memory Map (cached)
  ///
  /// 由 _refreshNativeMemory() 每 3 秒更新一次
  /// Updated every 3 seconds by _refreshNativeMemory()
  /// _refreshMemoryData() 会将此 Map 合并到 MemorySnapshot
  /// _refreshMemoryData() merges this Map into MemorySnapshot
  Map<String, dynamic>? _lastNativeMemoryMap;

  // Native 字段缓存（供 UI 直接访问）/ Native field cache (for direct UI access)

  /// 当前总 PSS（仅 Android）/ Current total PSS (Android only)
  int _currentTotalPss = 0;
  int get currentTotalPss => _currentTotalPss;

  /// 当前 Dalvik PSS（仅 Android）/ Current Dalvik PSS (Android only)
  int _currentDalvikPss = 0;
  int get currentDalvikPss => _currentDalvikPss;

  /// 当前 Native PSS（仅 Android）/ Current Native PSS (Android only)
  int _currentNativePss = 0;
  int get currentNativePss => _currentNativePss;

  /// 当前 Native Private Dirty（仅 Android）/ Current Native Private Dirty (Android only)
  int _currentNativePrivateDirty = 0;
  int get currentNativePrivateDirty => _currentNativePrivateDirty;

  /// 当前 iOS 物理内存占用（仅 iOS）/ Current iOS physical footprint (iOS only)
  int _currentPhysicalFootprint = 0;
  int get currentPhysicalFootprint => _currentPhysicalFootprint;

  /// 当前 iOS 已压缩内存（仅 iOS）/ Current iOS compressed memory (iOS only)
  int _currentInternalCompressed = 0;
  int get currentInternalCompressed => _currentInternalCompressed;

  /// 设备物理内存总量 / Device total physical memory
  int _deviceTotalMem = 0;
  int get deviceTotalMem => _deviceTotalMem;

  /// 设备可用物理内存 / Device available physical memory
  int _deviceAvailMem = 0;
  int get deviceAvailMem => _deviceAvailMem;

  /// 是否处于低内存状态 / Whether in low memory state
  bool _isLowMemory = false;
  bool get isLowMemory => _isLowMemory;

  // ==================== Dart Heap 数据 / Dart Heap Data ====================

  /// VM Service 是否可用 / Whether VM Service is available
  ///
  /// 为 false 时表示无法获取 Dart Heap 详细数据
  /// When false, Dart Heap detailed data cannot be obtained
  bool _vmServiceAvailable = false;

  /// 获取 VM Service 是否可用 / Get whether VM Service is available
  bool get vmServiceAvailable => _vmServiceAvailable;

  /// 当前 Dart Heap 已使用大小 / Current Dart Heap used size
  int _currentHeapUsage = 0;

  /// 当前 Dart Heap 容量 / Current Dart Heap capacity
  int _currentHeapCapacity = 0;

  /// 当前外部内存使用量 / Current external memory usage
  int _currentExternalUsage = 0;

  /// 当前新生代已使用大小 / Current new space used size
  int _currentNewSpaceUsage = 0;

  /// 当前新生代容量 / Current new space capacity
  int _currentNewSpaceCapacity = 0;

  /// 当前新生代外部内存使用量 / Current new space external memory usage
  int _currentNewSpaceExternalUsage = 0;

  /// 当前老生代已使用大小 / Current old space used size
  int _currentOldSpaceUsage = 0;

  /// 当前老生代容量 / Current old space capacity
  int _currentOldSpaceCapacity = 0;

  /// 当前老生代外部内存使用量 / Current old space external memory usage
  int _currentOldSpaceExternalUsage = 0;

  /// 获取当前 Dart Heap 已使用大小 / Get current Dart Heap used size
  int get currentHeapUsage => _currentHeapUsage;

  /// 获取当前 Dart Heap 容量 / Get current Dart Heap capacity
  int get currentHeapCapacity => _currentHeapCapacity;

  /// 获取当前外部内存使用量 / Get current external memory usage
  int get currentExternalUsage => _currentExternalUsage;

  /// 获取当前新生代已使用大小 / Get current new space used size
  int get currentNewSpaceUsage => _currentNewSpaceUsage;

  /// 获取当前新生代容量 / Get current new space capacity
  int get currentNewSpaceCapacity => _currentNewSpaceCapacity;

  /// 获取当前新生代外部内存使用量 / Get current new space external memory usage
  int get currentNewSpaceExternalUsage => _currentNewSpaceExternalUsage;

  /// 获取当前老生代已使用大小 / Get current old space used size
  int get currentOldSpaceUsage => _currentOldSpaceUsage;

  /// 获取当前老生代容量 / Get current old space capacity
  int get currentOldSpaceCapacity => _currentOldSpaceCapacity;

  /// 获取当前老生代外部内存使用量 / Get current old space external memory usage
  int get currentOldSpaceExternalUsage => _currentOldSpaceExternalUsage;

  // ==================== 历史快照 / Historical Snapshots ====================

  /// 内存历史快照列表 / Memory historical snapshot list
  ///
  /// 按 时间顺序排列，最早的数据在最前
  /// Sorted in chronological order, earliest data first
  final List<MemorySnapshot> _memorySnapshots = <MemorySnapshot>[];

  /// 获取内存历史快照列表（不可修改）/ Get memory historical snapshot list (unmodifiable)
  List<MemorySnapshot> get memorySnapshots =>
      List.unmodifiable(_memorySnapshots);

  /// 获取最新快照 / Get the latest snapshot
  ///
  /// 返回 null 表示尚无数据 / Returns null if no data yet
  MemorySnapshot? get latestSnapshot =>
      _memorySnapshots.isEmpty ? null : _memorySnapshots.last;

  /// 清空内存历史快照 / Clear memory historical snapshots
  ///
  /// 仅清空历史数据，不影响当前正在监控的实时数据
  /// Only clears historical data, does not affect real-time data being monitored
  void clearMemorySnapshots() {
    _memorySnapshots.clear();
    notifyListeners();
  }

  // ==================== 存储统计缓存 / Storage Stats Cache ====================

  /// 缓存的文档目录大小 / Cached documents directory size
  int _cachedDocumentsSize = 0;

  /// 缓存的缓存目录大小 / Cached cache directory size
  int _cachedCacheSize = 0;

  /// 缓存的数据库总大小 / Cached total database size
  int _cachedDatabaseSize = 0;

  /// 获取缓存的文档目录大小 / Get cached documents directory size
  int get cachedDocumentsSize => _cachedDocumentsSize;

  /// 获取缓存的缓存目录大小 / Get cached cache directory size
  int get cachedCacheSize => _cachedCacheSize;

  /// 获取缓存的数据库总大小 / Get cached total database size
  int get cachedDatabaseSize => _cachedDatabaseSize;

  // ==================== VM Service 内部状态 / VM Service Internal State ====================

  /// VM Service 的 HTTP 基础 URL / VM Service HTTP base URL
  ///
  /// 形如 `http://127.0.0.1:xxxxx` / Format: `http://127.0.0.1:xxxxx`
  String? _vmServiceHttpUri;

  /// VM Service 的 WebSocket 完整 URL / VM Service full WebSocket URL
  ///
  /// 形如 `ws://127.0.0.1:xxxxx/yyyy=` / Format: `ws://127.0.0.1:xxxxx/yyyy=`
  /// 当 HTTP 端点不可用时降级使用 / Used as fallback when HTTP endpoint is unavailable
  String? _vmServiceWsUri;

  /// 是否使用 WebSocket 模式 / Whether to use WebSocket mode
  ///
  /// - false: 使用 HTTP 模式（_vmServiceHttpUri）
  /// - true: 使用 WebSocket 模式（_vmServiceWsUri）
  /// 通常桌面平台使用 HTTP，移动平台可能需要降级到 WebSocket
  /// Usually desktop uses HTTP, mobile platforms may need to fall back to WebSocket
  bool _useWebSocket = false;

  /// 主 Isolate 的 ID / Main Isolate ID
  ///
  /// 形如 `isolates/12345678` / Format: `isolates/12345678`
  /// 通过调用 `getVM` RPC 获取，用于后续 `getMemoryUsage` 和 `_collectAllGarbage` 调用
  /// Obtained by calling `getVM` RPC, used for subsequent `getMemoryUsage` and `_collectAllGarbage` calls
  /// 注意：VM Service 中没有 `isolateId=root`，必须使用真实 isolate ID
  /// Note: There is no `isolateId=root` in VM Service, must use real isolate ID
  String? _mainIsolateId;

  /// VM Service 是否正在连接中 / Whether VM Service is connecting
  bool _vmServiceConnecting = false;

  /// VM Service 连接重试计数 / VM Service connection retry count
  int _vmServiceRetryCount = 0;

  /// 是否已经触发过 VM Service 初始化 / Whether VM Service initialization has been triggered
  ///
  /// 避免重复触发初始化 / Avoid triggering initialization repeatedly
  bool _vmServiceInitTriggered = false;

  // ==================== 监控生命周期 / Monitoring Lifecycle ====================

  /// 是否启用内存监控功能（用户开关）/ Whether memory monitoring is enabled (user switch)
  ///
  /// 默认为 false，用户通过 UI 开关打开后才会启动定时器和 VM Service 连接
  /// Defaults to false; timers and VM Service connection only start
  /// after user toggles on via UI
  /// 关闭时会停止所有定时器、断开 VM Service、清空 WebSocket 连接
  /// When turned off, all timers are stopped, VM Service is disconnected,
  /// and WebSocket connection is cleared
  bool _isEnabled = false;

  /// 获取是否启用内存监控 / Get whether memory monitoring is enabled
  bool get isEnabled => _isEnabled;

  /// 设置是否启用内存监控 / Set whether memory monitoring is enabled
  ///
  /// - 开启时：等同于调用 [startMonitoring()]
  ///   When enabling: equivalent to calling [startMonitoring()]
  /// - 关闭时：等同于调用 [stopMonitoring()]，会额外清理 VM Service 连接
  ///   When disabling: equivalent to calling [stopMonitoring()],
  ///   additionally cleans up VM Service connection
  set isEnabled(bool value) {
    if (_isEnabled == value) return;
    if (value) {
      startMonitoring();
    } else {
      stopMonitoring();
    }
  }

  /// 开始内存监控 / Start memory monitoring
  ///
  /// 启动内存数据采集定时器、存储统计定时刷新、泄漏检测
  /// Starts memory data collection timer, storage stats refresh, and leak detection
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isEnabled = true;
    _isMonitoring = true;
    _startMemoryDataRefresh();
    _startStorageStatsRefresh();
    _startLeakDetection();

    // 检测平台支持并启动 Native 内存采集
    // Detect platform support and start Native memory collection
    _detectNativeSupport();
    if (_isNativeSupported) {
      _startNativeMemoryRefresh();
    }

    // 异步触发 VM Service 连接，不阻塞其他功能
    // Async trigger VM Service connection, does not block other features
    unawaited(_ensureVmServiceInitialized());

    notifyListeners();
  }

  /// 停止内存监控 / Stop memory monitoring
  ///
  /// 会停止所有定时器，并清理 VM Service 连接（HTTP/WebSocket）
  /// Stops all timers and cleans up VM Service connection (HTTP/WebSocket)
  void stopMonitoring() {
    _memoryTimer?.cancel();
    _memoryTimer = null;
    _nativeMemoryTimer?.cancel();
    _nativeMemoryTimer = null;
    _storageTimer?.cancel();
    _storageTimer = null;
    _leakDetectionTimer?.cancel();
    _leakDetectionTimer = null;
    _isMonitoring = false;
    _isEnabled = false;

    // 清理 VM Service 连接状态，避免 WebSocket 残留消耗性能
    // Clean up VM Service connection state to avoid residual WebSocket
    // consuming performance
    _cleanupVmServiceConnection();

    notifyListeners();
  }

  /// 清理 VM Service 连接状态 / Clean up VM Service connection state
  ///
  /// 停止监控时调用，清空 HTTP/WebSocket URI、isolate ID 等状态
  /// Called when stopping monitoring, clears HTTP/WebSocket URI, isolate ID, etc.
  /// 下次重新启用监控时会重新建立连接
  /// Connection will be re-established when monitoring is re-enabled
  void _cleanupVmServiceConnection() {
    _vmServiceHttpUri = null;
    _vmServiceWsUri = null;
    _mainIsolateId = null;
    _vmServiceAvailable = false;
    _vmServiceConnecting = false;
    _vmServiceRetryCount = 0;
    _vmServiceInitTriggered = false;

    // 清空 Dart Heap 缓存数据 / Clear Dart Heap cached data
    _currentHeapUsage = 0;
    _currentHeapCapacity = 0;
    _currentExternalUsage = 0;
    _currentNewSpaceUsage = 0;
    _currentNewSpaceCapacity = 0;
    _currentNewSpaceExternalUsage = 0;
    _currentOldSpaceUsage = 0;
    _currentOldSpaceCapacity = 0;
    _currentOldSpaceExternalUsage = 0;
  }

  /// 检测当前平台是否支持 Native 内存采集
  /// Detect whether current platform supports Native memory collection
  ///
  /// 仅 Android 和 iOS 真机支持 / Only Android and iOS real devices are supported
  void _detectNativeSupport() {
    _isNativeSupported = Platform.isAndroid || Platform.isIOS;
  }

  /// 开始 Native 内存数据采集刷新 / Start Native memory data collection refresh
  ///
  /// 每 3 秒通过 Platform Channel 调用原生代码采集一次
  /// Calls native code via Platform Channel every 3 seconds
  void _startNativeMemoryRefresh() {
    _nativeMemoryTimer?.cancel();
    _nativeMemoryTimer = Timer.periodic(
      Duration(milliseconds: _nativeRefreshIntervalMs),
      (_) => _refreshNativeMemory(),
    );
    // 立即采集一次 / Collect immediately once
    _refreshNativeMemory();
  }

  /// 刷新 Native 内存数据 / Refresh Native memory data
  ///
  /// 通过 Platform Channel 调用原生代码获取进程级内存分项
  /// Calls native code via Platform Channel to get process-level memory breakdown
  Future<void> _refreshNativeMemory() async {
    if (!_isNativeSupported) return;

    try {
      final map = await PlatformChannel.getProcessMemoryInfo();
      if (map == null) {
        _isNativeSupported = false;
        return;
      }

      _lastNativeMemoryMap = map;

      // 更新缓存字段（供 UI 直接访问）/ Update cached fields (for direct UI access)
      _currentTotalPss = _readInt(map, 'totalPss');
      _currentDalvikPss = _readInt(map, 'dalvikPss');
      _currentNativePss = _readInt(map, 'nativePss');
      _currentNativePrivateDirty = _readInt(map, 'nativePrivateDirty');
      _currentPhysicalFootprint = _readInt(map, 'physicalFootprint');
      _currentInternalCompressed = _readInt(map, 'internalCompressed');
      _deviceTotalMem = _readInt(map, 'totalMem');
      _deviceAvailMem = _readInt(map, 'availMem');
      _isLowMemory = _readBool(map, 'lowMemory');

      // 同步更新当前 RSS（Native 端口可能更准确）
      // Sync update current RSS (Native side may be more accurate)
      final nativeRss = _readInt(map, 'rss');
      if (nativeRss > 0) {
        _currentProcessRss = nativeRss;
      }

      notifyListeners();
    } catch (_) {}
  }

  /// 从 Map 中安全读取 int 值 / Safely read int value from Map
  static int _readInt(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  /// 从 Map 中安全读取 bool 值 / Safely read bool value from Map
  static bool _readBool(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is bool) return value;
    return false;
  }

  /// 开始内存数据采集刷新 / Start memory data collection refresh
  ///
  /// 同时采集进程 RSS 和 Dart Heap 数据
  /// Collects both process RSS and Dart Heap data
  void _startMemoryDataRefresh() {
    _memoryTimer?.cancel();
    _memoryTimer = Timer.periodic(
      Duration(milliseconds: _heapRefreshIntervalMs),
      (_) => _refreshMemoryData(),
    );
    _refreshMemoryData();
  }

  /// 刷新内存数据 / Refresh memory data
  ///
  /// 采集进程 RSS 并（如果 VM Service 可用）采集 Dart Heap 数据
  /// Collects process RSS and (if VM Service available) Dart Heap data
  /// 同时合并最近一次 Native 内存数据到快照
  /// Also merges last Native memory data into snapshot
  Future<void> _refreshMemoryData() async {
    // 1. 始终采集进程 RSS（来自 ProcessInfo，无需网络）
    // 1. Always collect process RSS (from ProcessInfo, no network required)
    // 注：Native 定时器（3 秒）会用更准确的 RSS 覆盖此值
    // Note: Native timer (3s) will overwrite this with more accurate RSS
    try {
      _currentProcessRss = ProcessInfo.currentRss;
    } catch (_) {}

    // 2. 如果 VM Service 已可用，则采集 Dart Heap 数据
    // 2. If VM Service is available, collect Dart Heap data
    if (_vmServiceAvailable && _vmServiceHttpUri != null) {
      await _fetchDartHeapData();
    }

    // 3. 创建并保存快照（合并 Native + Dart Heap 数据）
    // 3. Create and save snapshot (merging Native + Dart Heap data)
    final snapshot = _buildSnapshot();
    _memorySnapshots.add(snapshot);

    // 4. 限制历史快照数量，移除最旧的数据
    // 4. Limit snapshot count, remove oldest data
    while (_memorySnapshots.length > _maxSnapshots) {
      _memorySnapshots.removeAt(0);
    }

    // 告警检测：以进程 RSS（MB）为准 / Alert: use process RSS in MB
    AlertService.instance.checkMemory(_currentProcessRss / (1024 * 1024));

    notifyListeners();
  }

  /// 构建当前内存快照 / Build current memory snapshot
  ///
  /// 合并三个数据源 / Merges three data sources:
  /// 1. ProcessInfo.currentRss（始终可用）/ Always available
  /// 2. Platform Channel Native 内存（3 秒缓存）/ 3-second cache
  /// 3. VM Service Dart Heap（可用时）/ When available
  MemorySnapshot _buildSnapshot() {
    // 如果 Native 数据可用，从 Native Map 构建并补充 Dart Heap 字段
    // If Native data is available, build from Native Map and supplement Dart Heap fields
    if (_isNativeSupported && _lastNativeMemoryMap != null) {
      return MemorySnapshot.fromNativeMap(
        processRss: _currentProcessRss,
        map: _lastNativeMemoryMap!,
        isHeapDataAvailable: _vmServiceAvailable,
      ).copyWithHeapData(
        heapUsage: _currentHeapUsage,
        heapCapacity: _currentHeapCapacity,
        externalUsage: _currentExternalUsage,
        newSpaceUsage: _currentNewSpaceUsage,
        newSpaceCapacity: _currentNewSpaceCapacity,
        newSpaceExternalUsage: _currentNewSpaceExternalUsage,
        oldSpaceUsage: _currentOldSpaceUsage,
        oldSpaceCapacity: _currentOldSpaceCapacity,
        oldSpaceExternalUsage: _currentOldSpaceExternalUsage,
        isHeapDataAvailable: _vmServiceAvailable,
      );
    }

    // Native 不可用时，仅使用 Dart Heap 数据（如果可用）
    // When Native is unavailable, only use Dart Heap data (if available)
    if (_vmServiceAvailable) {
      return MemorySnapshot.withHeapData(
        processRss: _currentProcessRss,
        heapUsage: _currentHeapUsage,
        heapCapacity: _currentHeapCapacity,
        externalUsage: _currentExternalUsage,
        newSpaceUsage: _currentNewSpaceUsage,
        newSpaceCapacity: _currentNewSpaceCapacity,
        newSpaceExternalUsage: _currentNewSpaceExternalUsage,
        oldSpaceUsage: _currentOldSpaceUsage,
        oldSpaceCapacity: _currentOldSpaceCapacity,
        oldSpaceExternalUsage: _currentOldSpaceExternalUsage,
      );
    }

    // 两者都不可用时，仅返回进程 RSS
    // When both are unavailable, return only process RSS
    return MemorySnapshot.processOnly(_currentProcessRss);
  }

  // ==================== VM Service 连接 / VM Service Connection ====================

  /// 确保 VM Service 已初始化（异步、不阻塞）/ Ensure VM Service is initialized (async, non-blocking)
  ///
  /// 采用 HTTP 轮询方式连接 VM Service，相比 WebSocket 更稳定
  /// Uses HTTP polling to connect to VM Service, more stable than WebSocket
  /// 在 Android 真机上 WebSocket 会出现 Connection refused 错误
  /// WebSocket shows Connection refused error on Android real devices
  Future<void> _ensureVmServiceInitialized() async {
    if (_vmServiceInitTriggered) return;
    _vmServiceInitTriggered = true;

    // 初始延迟，等待 Flutter 引擎启动 VM Service Web Server
    // Initial delay, wait for Flutter engine to start VM Service web server
    await Future.delayed(Duration(milliseconds: _vmServiceInitialDelayMs));

    await _tryConnectVmService();
  }

  /// 尝试连接 VM Service（带重试）/ Try to connect to VM Service (with retries)
  Future<void> _tryConnectVmService() async {
    if (_vmServiceAvailable || _vmServiceConnecting) return;
    _vmServiceConnecting = true;

    try {
      // 1. 启动 VM Service Web Server 并直接获取返回的 ServiceProtocolInfo
      // 1. Start VM Service web server and directly get returned ServiceProtocolInfo
      ServiceProtocolInfo? serviceInfo;
      try {
        serviceInfo = await Service.controlWebServer(
          enable: true,
          silenceOutput: true,
        );
      } catch (_) {}

      // 2. 若 controlWebServer 未返回有效信息，再尝试 getInfo()
      // 2. If controlWebServer did not return valid info, try getInfo() again
      serviceInfo ??= await Service.getInfo();

      // 打印完整的调试信息 / Print complete debug info
      // serverUri: HTTP 端点（如 http://127.0.0.1:port/）
      // serverWebSocketUri: WebSocket 端点（如 ws://127.0.0.1:port/path）

      // 关键说明 / Key explanation:
      // - [serverUri] 是 VM Service 的 HTTP 端点（web server 启动后才有值）
      //   [serverUri] is the HTTP endpoint of VM Service (only available after web server starts)
      //   在 Android 真机上，web server 默认不启动，需要 controlWebServer(enable: true) 启动
      //   On Android real devices, web server doesn't start by default,
      //   need controlWebServer(enable: true) to start it
      //
      // - [serverWebSocketUri] 是 VM Service 的 WebSocket 端点（VM 原生支持，不依赖 web server）
      //   [serverWebSocketUri] is the WebSocket endpoint of VM Service
      //   (natively supported by VM, doesn't depend on web server)
      //
      // 同时保存两个端点，便于失败时自动降级
      // Save both endpoints simultaneously for automatic fallback on failure
      final httpServerUri = serviceInfo.serverUri;
      final wsServerUri = serviceInfo.serverWebSocketUri;

      if (httpServerUri == null && wsServerUri == null) {
        _scheduleRetry();
        return;
      }

      // 关键：同时保存两个端点的完整 URI（包含 path 部分，如 /mLbldAlQOnQ=/）
      // Key: Save full URIs of both endpoints (including path part, e.g. /mLbldAlQOnQ=/)
      // 丢弃 path 会导致 /getVM 请求 404 或 Connection refused
      // Discarding path will cause /getVM requests to 404 or Connection refused
      if (httpServerUri != null) {
        // 保留完整的 path 和 query / Preserve full path and query
        var path = httpServerUri.path;
        // 移除末尾的斜杠（避免 //getVM）/ Remove trailing slash (to avoid //getVM)
        if (path.endsWith('/') && path.length > 1) {
          path = path.substring(0, path.length - 1);
        }
        _vmServiceHttpUri =
            'http://${httpServerUri.host}:${httpServerUri.port}$path';
      } else {
        _vmServiceHttpUri = null;
      }

      if (wsServerUri != null) {
        _vmServiceWsUri = wsServerUri.toString();
      } else {
        _vmServiceWsUri = null;
      }

      // 选择初始模式：优先 HTTP，降级用 WebSocket
      // Choose initial mode: prefer HTTP, fall back to WebSocket
      // 注意：在 Android 真机上 HTTP 端点经常 Connection refused（web server 未真正启动）
      // Note: On Android real devices, HTTP endpoint often Connection refused
      // (web server not actually started)
      // _validateVmServiceConnection 会自动尝试两种模式并切换
      // _validateVmServiceConnection will automatically try both modes and switch
      _useWebSocket = (_vmServiceHttpUri == null);

      // 4. 验证连接：调用 getVM 获取 isolate 列表并提取主 isolate ID
      // 4. Validate connection: call getVM to get isolate list and extract main isolate ID
      final ok = await _validateVmServiceConnection();
      if (ok) {
        _vmServiceAvailable = true;
        _vmServiceRetryCount = 0;
        // 立即采集一次 Dart Heap 数据
        // Immediately collect Dart Heap data once
        await _fetchDartHeapData();
        notifyListeners();
      } else {
        // 验证失败时清空可能残留的 isolate ID
        // Clear potentially stale isolate ID on validation failure
        _mainIsolateId = null;
        _scheduleRetry();
      }
    } catch (_) {
      _scheduleRetry();
    } finally {
      _vmServiceConnecting = false;
    }
  }

  /// 安排 VM Service 重试连接 / Schedule VM Service retry connection
  void _scheduleRetry() {
    if (_vmServiceRetryCount >= _vmServiceMaxRetries) {
      _vmServiceAvailable = false;
      return;
    }

    _vmServiceRetryCount++;

    Timer(
      Duration(milliseconds: _vmServiceRetryIntervalMs),
      _tryConnectVmService,
    );
  }

  /// 验证 VM Service 连接是否可用并获取主 Isolate ID
  /// Validate VM Service connection availability and get main Isolate ID
  ///
  /// 通过调用 `getVM` RPC 验证连接，同时从响应中提取主 isolate ID
  /// Validates connection by calling `getVM` RPC, and extracts main isolate ID from response
  /// 主 isolate 通常是 name 为 "main" 的那个
  /// Main isolate is usually the one with name "main"
  Future<bool> _validateVmServiceConnection() async {
    // 尝试当前选定的模式 / Try the currently selected mode
    final result = await _tryValidateWithCurrentMode();
    if (result != null) return result;

    // 当前模式失败时尝试切换模式 / Try switching mode on current mode failure
    // 例如 HTTP 模式失败时降级到 WebSocket 模式 / E.g. fallback from HTTP to WebSocket
    if (!_useWebSocket && _vmServiceWsUri != null) {
      _useWebSocket = true;
      final wsResult = await _tryValidateWithCurrentMode();
      if (wsResult != null) return wsResult;
    } else if (_useWebSocket && _vmServiceHttpUri != null) {
      _useWebSocket = false;
      final httpResult = await _tryValidateWithCurrentMode();
      if (httpResult != null) return httpResult;
    }

    return false;
  }

  /// 尝试用当前模式验证连接，返回 null 表示应尝试另一种模式
  /// Try validating connection with current mode, returns null to indicate
  /// should try the other mode
  Future<bool?> _tryValidateWithCurrentMode() async {
    try {
      final dynamic data;
      if (_useWebSocket) {
        if (_vmServiceWsUri == null) return null;
        // WebSocket 模式：通过 ws:// 调用 getVM
        // WebSocket mode: call getVM via ws://
        data = await _callWebSocketRpc('getVM', {});
      } else {
        if (_vmServiceHttpUri == null) return null;
        // HTTP 模式：直接 GET /getVM
        // HTTP mode: directly GET /getVM
        final response = await http
            .get(
              Uri.parse('$_vmServiceHttpUri/getVM'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 2));

        if (response.statusCode != 200) {
          return null;
        }
        data = jsonDecode(response.body) as Map<String, dynamic>;
      }

      // 验证返回类型 / Validate response type
      if (data is! Map<String, dynamic> || data['type'] != 'VM') {
        return null;
      }

      // 从 isolates 列表中找到主 isolate / Find main isolate from isolates list
      final isolates = data['isolates'] as List<dynamic>?;
      if (isolates == null || isolates.isEmpty) {
        return false;
      }

      // 优先选择 name 为 "main" 的 isolate，否则取第一个
      // Prefer isolate with name "main", otherwise take the first one
      String? isolateId;
      for (final iso in isolates) {
        final isoMap = iso as Map<String, dynamic>;
        final name = isoMap['name']?.toString() ?? '';
        if (name == 'main') {
          isolateId = isoMap['id']?.toString();
          break;
        }
        isolateId ??= isoMap['id']?.toString();
      }

      if (isolateId == null || isolateId.isEmpty) {
        return false;
      }

      _mainIsolateId = isolateId;
      return true;
    } catch (_) {
      return null;
    }
  }

  /// 通过 WebSocket 调用 VM Service RPC
  /// Call VM Service RPC via WebSocket
  ///
  /// VM Service WebSocket 协议使用 JSON-RPC 格式：
  /// VM Service WebSocket protocol uses JSON-RPC format:
  /// ```
  /// 请求: {"jsonrpc": "2.0", "method": "getVM", "params": {}, "id": 1}
  /// 响应: {"jsonrpc": "2.0", "result": {...}, "id": 1}
  /// ```
  Future<Map<String, dynamic>> _callWebSocketRpc(
    String method,
    Map<String, dynamic> params,
  ) async {
    if (_vmServiceWsUri == null) {
      throw StateError('VM Service WebSocket URI is null');
    }

    final socket = await WebSocket.connect(_vmServiceWsUri!);
    try {
      // JSON-RPC 2.0 请求 / JSON-RPC 2.0 request
      final request = {
        'jsonrpc': '2.0',
        'method': method,
        'params': params,
        'id': 1,
      };
      socket.add(jsonEncode(request));

      // 等待响应 / Wait for response
      final completer = Completer<Map<String, dynamic>>();
      late StreamSubscription sub;
      sub = socket.listen(
        (msg) {
          if (completer.isCompleted) return;
          try {
            final decoded = jsonDecode(msg.toString()) as Map<String, dynamic>;
            // 排除通知（没有 id 字段的是通知）/ Exclude notifications (no id field)
            if (!decoded.containsKey('id') &&
                !decoded.containsKey('result') &&
                !decoded.containsKey('error')) {
              return;
            }
            // 检查错误 / Check for error
            if (decoded.containsKey('error')) {
              completer.completeError(
                Exception('RPC error: ${decoded['error']}'),
              );
              return;
            }
            // 返回 result 字段 / Return result field
            final result = decoded['result'];
            if (result is Map<String, dynamic>) {
              completer.complete(result);
            } else {
              completer.complete(<String, dynamic>{});
            }
          } catch (e) {
            completer.completeError(e);
          }
        },
        onError: (e) {
          if (!completer.isCompleted) {
            completer.completeError(e);
          }
        },
        onDone: () {
          if (!completer.isCompleted) {
            completer.completeError(
              StateError('WebSocket closed before response received'),
            );
          }
        },
        cancelOnError: true,
      );

      // 设置超时 / Set timeout
      final result = await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          throw TimeoutException('WebSocket RPC timeout: $method');
        },
      );
      await sub.cancel();
      return result;
    } finally {
      await socket.close();
    }
  }

  /// 采集 Dart Heap 数据 / Collect Dart Heap data
  ///
  /// 通过 VM Service HTTP 或 WebSocket 协议调用 `getMemoryUsage` RPC
  /// Calls `getMemoryUsage` RPC via VM Service HTTP or WebSocket protocol
  ///
  /// 注意：VM Service 协议中方法名是 `getMemoryUsage`（不带下划线前缀）
  /// Note: The method name in VM Service protocol is `getMemoryUsage` (no underscore prefix)
  /// isolateId 必须是真实的 isolate ID（如 `isolates/12345678`），不能是 "root"
  /// isolateId must be a real isolate ID (e.g. `isolates/12345678`), not "root"
  Future<void> _fetchDartHeapData() async {
    if (!_vmServiceAvailable) return;
    if (!_useWebSocket && _vmServiceHttpUri == null) return;
    if (_useWebSocket && _vmServiceWsUri == null) return;

    // 如果尚未获取到主 isolate ID，先尝试获取一次
    // If main isolate ID is not yet obtained, try to get it once
    if (_mainIsolateId == null) {
      final ok = await _validateVmServiceConnection();
      if (!ok || _mainIsolateId == null) {
        return;
      }
    }

    try {
      final Map<String, dynamic> data;
      if (_useWebSocket) {
        // WebSocket 模式 / WebSocket mode
        data = await _callWebSocketRpc('getMemoryUsage', {
          'isolateId': _mainIsolateId,
        });
      } else {
        // HTTP 模式 / HTTP mode
        final response = await http
            .get(
              Uri.parse(
                '$_vmServiceHttpUri/getMemoryUsage?isolateId=$_mainIsolateId',
              ),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 2));

        if (response.statusCode != 200) {
          return;
        }
        data = jsonDecode(response.body) as Map<String, dynamic>;
      }

      // VM Service 返回格式：{ type: 'MemoryUsage', ... }
      // VM Service response format: { type: 'MemoryUsage', ... }
      if (data['type'] != 'MemoryUsage') {
        return;
      }

      // 解析所有字段，缺失时默认为 0
      // Parse all fields, default to 0 if missing
      _currentHeapUsage = _asInt(data['heapUsage']);
      _currentHeapCapacity = _asInt(data['heapCapacity']);
      _currentExternalUsage = _asInt(data['externalUsage']);
      _currentNewSpaceUsage = _asInt(data['newSpaceUsage']);
      _currentNewSpaceCapacity = _asInt(data['newSpaceCapacity']);
      _currentNewSpaceExternalUsage = _asInt(data['newSpaceExternalUsage']);
      _currentOldSpaceUsage = _asInt(data['oldSpaceUsage']);
      _currentOldSpaceCapacity = _asInt(data['oldSpaceCapacity']);
      _currentOldSpaceExternalUsage = _asInt(data['oldSpaceExternalUsage']);
    } catch (_) {}
  }

  /// 手动触发 GC / Manually trigger GC
  ///
  /// 调用 VM Service 的 `_collectAllGarbage` RPC
  /// Calls VM Service `_collectAllGarbage` RPC
  ///
  /// 注意：`_collectAllGarbage` 是 VM Service 的私有方法（带下划线前缀）
  /// Note: `_collectAllGarbage` is a private method in VM Service (with underscore prefix)
  /// isolateId 必须是真实的 isolate ID（如 `isolates/12345678`），不能是 "root"
  /// isolateId must be a real isolate ID (e.g. `isolates/12345678`), not "root"
  ///
  /// 返回 true 表示成功 / Returns true on success
  /// 返回 false 表示 VM Service 不可用或调用失败
  /// Returns false if VM Service is unavailable or call failed
  Future<bool> triggerGc() async {
    if (!_vmServiceAvailable) {
      return false;
    }
    if (!_useWebSocket && _vmServiceHttpUri == null) {
      return false;
    }
    if (_useWebSocket && _vmServiceWsUri == null) {
      return false;
    }

    // 如果尚未获取到主 isolate ID，先尝试获取一次
    // If main isolate ID is not yet obtained, try to get it once
    if (_mainIsolateId == null) {
      final ok = await _validateVmServiceConnection();
      if (!ok || _mainIsolateId == null) {
        return false;
      }
    }

    try {
      if (_useWebSocket) {
        // WebSocket 模式 / WebSocket mode
        await _callWebSocketRpc('_collectAllGarbage', {
          'isolateId': _mainIsolateId,
        }).timeout(const Duration(seconds: 5));
      } else {
        // HTTP 模式 / HTTP mode
        final response = await http
            .get(
              Uri.parse(
                '$_vmServiceHttpUri/_collectAllGarbage?isolateId=$_mainIsolateId',
              ),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 5));

        if (response.statusCode != 200) {
          return false;
        }
      }

      // 立即刷新一次数据，让用户看到 GC 后的效果
      // Immediately refresh data once so user can see GC effect
      await _fetchDartHeapData();
      _currentProcessRss = ProcessInfo.currentRss;
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 将动态值安全转换为 int / Safely convert dynamic value to int
  ///
  /// VM Service 可能返回 int 或 num 类型 / VM Service may return int or num type
  static int _asInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  // ==================== 图片缓存 / Image Cache ====================

  /// 获取图片缓存当前数量 / Get current image cache count
  int get imageCacheCurrentSize {
    return PaintingBinding.instance.imageCache.currentSize;
  }

  /// 获取图片缓存当前大小（字节）/ Get current image cache size (bytes)
  int get imageCacheCurrentSizeBytes {
    return PaintingBinding.instance.imageCache.currentSizeBytes;
  }

  /// 获取图片缓存最大数量 / Get image cache maximum count
  int get imageCacheMaximumSize {
    return PaintingBinding.instance.imageCache.maximumSize;
  }

  /// 获取图片缓存最大大小（字节）/ Get image cache maximum size (bytes)
  int get imageCacheMaximumSizeBytes {
    return PaintingBinding.instance.imageCache.maximumSizeBytes;
  }

  /// 获取正在加载中的图片数量 / Get pending image count
  int get imageCachePendingCount {
    return PaintingBinding.instance.imageCache.pendingImageCount;
  }

  /// 获取正在使用中的图片数量 / Get live image count
  int get imageCacheLiveCount {
    return PaintingBinding.instance.imageCache.liveImageCount;
  }

  /// 清理图片缓存 / Clear image cache
  void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    notifyListeners();
  }

  /// 设置图片缓存最大数量 / Set image cache maximum count
  set imageCacheMaximumSize(int value) {
    PaintingBinding.instance.imageCache.maximumSize = value;
    notifyListeners();
  }

  /// 设置图片缓存最大大小（字节）/ Set image cache maximum size (bytes)
  set imageCacheMaximumSizeBytes(int value) {
    PaintingBinding.instance.imageCache.maximumSizeBytes = value;
    notifyListeners();
  }

  /// 刷新图片缓存数据（通知UI更新）/ Refresh image cache data (notify UI update)
  void refreshImageCache() {
    notifyListeners();
  }

  // ==================== 存储统计 / Storage Stats ====================

  /// 开始存储统计刷新 / Start storage stats refresh
  void _startStorageStatsRefresh() {
    _storageTimer?.cancel();
    _storageTimer = Timer.periodic(
      Duration(milliseconds: _storageRefreshIntervalMs),
      (_) => _refreshStorageStats(),
    );
    _refreshStorageStats();
  }

  /// 刷新存储统计数据 / Refresh storage statistics data
  Future<void> _refreshStorageStats() async {
    try {
      final results = await Future.wait([
        getDocumentsDirSize(),
        getCacheDirSize(),
        getTotalDatabaseSize(),
      ]);
      _cachedDocumentsSize = results[0];
      _cachedCacheSize = results[1];
      _cachedDatabaseSize = results[2];
      notifyListeners();
    } catch (_) {}
  }

  /// 获取所有数据库文件总大小（字节）/ Get total database file size (bytes)
  Future<int> getTotalDatabaseSize() async {
    try {
      final databases = await DatabaseService.instance.getDatabases();
      int total = 0;
      for (final db in databases) {
        try {
          final file = File(db.path);
          if (await file.exists()) {
            total += await file.length();
          }
        } catch (_) {}
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  /// 获取应用文档目录大小（字节）/ Get app documents directory size (bytes)
  Future<int> getDocumentsDirSize() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return _calculateDirSize(dir);
    } catch (_) {
      return 0;
    }
  }

  /// 获取应用临时缓存目录大小（字节）/ Get app temp cache directory size (bytes)
  Future<int> getCacheDirSize() async {
    try {
      final dir = await getTemporaryDirectory();
      return _calculateDirSize(dir);
    } catch (_) {
      return 0;
    }
  }

  /// 计算目录大小 / Calculate directory size
  Future<int> _calculateDirSize(Directory dir) async {
    int total = 0;
    try {
      if (!await dir.exists()) return 0;
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return total;
  }

  /// 清理应用临时缓存目录 / Clear app temporary cache directory
  Future<void> clearCacheDir() async {
    try {
      final dir = await getTemporaryDirectory();
      if (await dir.exists()) {
        await for (final entity in dir.list(followLinks: false)) {
          try {
            await entity.delete(recursive: true);
          } catch (_) {}
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  // ==================== 泄漏检测 API / Leak Detection API ====================

  /// 注册对象进行泄漏追踪 / Register object for leak tracking
  ///
  /// 使用 Dart 2.17+ 的 [WeakReference] 弱引用持有对象，不会阻止对象被 GC
  /// Uses Dart 2.17+ [WeakReference] weak reference to hold object,
  /// will not prevent object from being GC'd
  ///
  /// 使用方式 / Usage:
  /// ```dart
  /// final myBloc = MyBloc();
  /// MemoryInspectorService.instance.trackObject(
  ///   myBloc,
  ///   tag: 'HomePage_myBloc',
  ///   expectedReleaseAfter: Duration(seconds: 60),
  /// );
  /// ```
  ///
  /// [object] 要追踪的对象 / Object to track
  /// [tag] 可选的自定义标签，用于 UI 识别 / Optional custom tag for UI identification
  /// [expectedReleaseAfter] 预期对象在此时间后应被释放，超过将触发验证
  ///   Expected time after which object should be released,
  ///   exceeding will trigger verification
  ///
  /// 返回对象的追踪 ID（即 hashCode），可用于后续调用 [untrackObject]
  /// Returns tracking ID (hashCode) of object, can be used for subsequent [untrackObject] calls
  int trackObject(
    Object object, {
    String? tag,
    Duration? expectedReleaseAfter,
  }) {
    final now = DateTime.now();
    final releaseAfter = expectedReleaseAfter ?? _defaultExpectedReleaseAfter;

    final record = LeakRecord(
      objectId: identityHashCode(object),
      objectType: object.runtimeType.toString(),
      weakRef: WeakReference<Object>(object),
      trackedAt: now,
      expectedReleaseAt: now.add(releaseAfter),
      tag: tag,
      status: LeakStatus.tracking,
    );

    _trackedRecords[record.objectId] = record;

    // 超过最大数量时，移除最旧的已释放记录
    // When exceeding max count, remove oldest released records
    _trimExcessRecords();

    notifyListeners();
    return record.objectId;
  }

  /// 手动取消对象的泄漏追踪 / Manually cancel leak tracking of object
  ///
  /// [objectIdOrObject] 可以是对象本身或对象的 hashCode（trackObject 返回值）
  /// Can be the object itself or object's hashCode (return value of trackObject)
  void untrackObject(Object objectIdOrObject) {
    final id = objectIdOrObject is int
        ? objectIdOrObject
        : identityHashCode(objectIdOrObject);
    final removed = _trackedRecords.remove(id);
    if (removed != null) {
      notifyListeners();
    }
  }

  /// 清空所有泄漏检测记录 / Clear all leak detection records
  ///
  /// 清除所有 tracking/verifying/leaked/released 状态的记录
  /// Clears all records in tracking/verifying/leaked/released states
  void clearLeakRecords() {
    _trackedRecords.clear();
    notifyListeners();
  }

  /// 启动泄漏检测定时器 / Start leak detection timer
  ///
  /// 每 [_leakDetectionIntervalMs] 毫秒检查一次被追踪对象的状态
  /// Checks tracked objects' status every [_leakDetectionIntervalMs] milliseconds
  void _startLeakDetection() {
    _leakDetectionTimer?.cancel();
    _leakDetectionTimer = Timer.periodic(
      Duration(milliseconds: _leakDetectionIntervalMs),
      (_) => _checkLeakRecords(),
    );
    // 立即检查一次 / Check immediately once
    _checkLeakRecords();
  }

  /// 检查所有被追踪对象的泄漏状态 / Check leak status of all tracked objects
  ///
  /// 状态流转逻辑 / State transition logic:
  /// 1. tracking -> isReleased => released
  /// 2. tracking -> !isReleased && isExpired => verifying（触发 GC）
  /// 3. verifying -> isReleased => released
  /// 4. verifying -> !isReleased && 等待 >= _leakVerifyWaitMs => leaked
  /// 5. leaked -> isReleased => released（泄漏修复）
  Future<void> _checkLeakRecords() async {
    if (_trackedRecords.isEmpty) return;

    bool changed = false;
    // 是否需要触发 GC（verifying 状态的对象需要）
    // Whether need to trigger GC (for objects in verifying state)
    bool needGc = false;

    // 遍历副本，避免并发修改 / Iterate over copy to avoid concurrent modification
    final records = _trackedRecords.values.toList();
    for (final record in records) {
      // 已释放：直接标记 released
      // Released: mark as released directly
      if (record.isReleased) {
        if (record.status != LeakStatus.released) {
          record.status = LeakStatus.released;
          changed = true;
        }
        continue;
      }

      switch (record.status) {
        case LeakStatus.tracking:
          // 如果已超过预期释放时间，进入验证阶段
          // If exceeded expected release time, enter verification phase
          if (record.isExpired) {
            record.status = LeakStatus.verifying;
            record.gcTriggeredAt ??= DateTime.now();
            needGc = true;
            changed = true;
          }
          break;

        case LeakStatus.verifying:
          // 检查 GC 后是否已释放
          // Check whether released after GC
          final waitMs = record.gcTriggeredAt != null
              ? DateTime.now().difference(record.gcTriggeredAt!).inMilliseconds
              : 0;
          // GC 触发后已等待足够时长，仍未释放 => 疑似泄漏
          // Waited enough after GC trigger, still not released => suspected leak
          if (waitMs >= _leakVerifyWaitMs) {
            record.status = LeakStatus.leaked;
            changed = true;
          }
          break;

        case LeakStatus.leaked:
          // 泄漏状态下，如果对象已被释放（修复了泄漏），转回 released
          // In leaked state, if object has been released (leak fixed),
          // switch back to released
          if (record.isReleased) {
            record.status = LeakStatus.released;
            changed = true;
          }
          break;

        case LeakStatus.released:
          // released 状态无需处理，_trimExcessRecords 会清理旧数据
          // No processing needed for released state,
          // _trimExcessRecords will clean up old data
          break;
      }
    }

    // 有 verifying 状态对象时，尝试触发 GC 加速验证
    // When there are verifying objects, try to trigger GC to speed up verification
    if (needGc && _vmServiceAvailable) {
      // 触发 GC 时不等待结果，在下一次检查时验证
      // Don't wait for result when triggering GC, verify on next check
      unawaited(triggerGc());
    }

    // 超过最大数量时，清理最旧的已释放记录
    // When exceeding max count, clean up oldest released records
    if (_trackedRecords.length > _maxTrackedRecords) {
      _trimExcessRecords();
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// 清理超出数量的已释放记录 / Clean up released records exceeding quantity limit
  ///
  /// 优先保留 leaked、verifying、tracking 状态的记录
  /// Prioritize keeping leaked, verifying, tracking state records
  /// 仅在总数超过 [_maxTrackedRecords] 时，移除最旧的 released 记录
  /// Only remove oldest released records when total exceeds [_maxTrackedRecords]
  void _trimExcessRecords() {
    if (_trackedRecords.length <= _maxTrackedRecords) return;

    // 提取已释放记录，按 trackedAt 从旧到新排序
    // Extract released records, sorted by trackedAt from oldest to newest
    final releasedRecords =
        _trackedRecords.values
            .where((r) => r.status == LeakStatus.released)
            .toList()
          ..sort((a, b) => a.trackedAt.compareTo(b.trackedAt));

    int needRemove = _trackedRecords.length - _maxTrackedRecords;
    for (final r in releasedRecords) {
      if (needRemove <= 0) break;
      _trackedRecords.remove(r.objectId);
      needRemove--;
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
