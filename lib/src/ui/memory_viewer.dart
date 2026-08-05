import 'package:flutter/material.dart';
import 'theme/inspector_theme.dart';
import '../models/leak_record.dart';
import '../services/memory_inspector_service.dart';
import 'memory_trend_chart.dart';

/// 内存查看器 / Memory viewer
///
/// 展示以下内容：
/// Displays the following:
/// - 内存趋势图（可切换 RSS/Heap/New/Old 指标）/ Memory trend chart (switchable RSS/Heap/New/Old metrics)
/// - Native 内存概览卡片（Android PSS 或 iOS physicalFootprint，真机可用）
///   Native memory overview card (Android PSS or iOS physicalFootprint, available on real devices)
/// - Dart Heap 内存概览卡片（VM Service 可用时显示详细数据，否则显示 N/A）
///   Dart Heap memory overview card (shows details when VM Service available, otherwise N/A)
/// - 新生代/老生代详细内存数据 / New/Old space detailed memory data
/// - 操作按钮（触发 GC、清空历史快照等）/ Action buttons (trigger GC, clear history, etc.)
/// - 图片缓存统计 / Image cache statistics
/// - 应用存储统计 / App storage statistics
///
/// 优雅降级 / Graceful degradation:
/// - Native 内存分项在桌面平台不可用，UI 会显示 N/A
///   Native memory breakdown is unavailable on desktop platforms, UI will show N/A
/// - Dart Heap 数据在 release 模式或 Android 真机连接失败时不可用，UI 会显示 N/A
///   Dart Heap data is unavailable in release mode or when Android real device
///   connection fails, UI will display N/A placeholder
class MemoryViewer extends StatefulWidget {
  const MemoryViewer({super.key});

  @override
  State<MemoryViewer> createState() => _MemoryViewerState();
}

class _MemoryViewerState extends State<MemoryViewer> {
  /// 当前选中的趋势图指标 / Currently selected trend chart metric
  MemoryMetric _selectedMetric = MemoryMetric.processRss;

  @override
  void initState() {
    super.initState();
    // 不再自动启动监控，由用户通过开关控制
    // Don't auto-start monitoring; user controls it via switch
    MemoryInspectorService.instance.addListener(_onMemoryChanged);
  }

  @override
  void dispose() {
    MemoryInspectorService.instance.removeListener(_onMemoryChanged);
    super.dispose();
  }

  /// 内存数据变化回调 / Memory data change callback
  void _onMemoryChanged() {
    if (mounted) setState(() {});
  }

  /// 格式化字节数为可读字符串 / Format bytes to readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final service = MemoryInspectorService.instance;
    final enabled = service.isEnabled;

    return Container(
      color: InspectorColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 顶部开关卡片 / Top switch card
            _buildEnabledSwitchCard(),
            const SizedBox(height: 12),
            // 未启用时显示占位说明 / Show placeholder when not enabled
            if (!enabled)
              _buildDisabledPlaceholder()
            else ...[
              _buildTrendChartCard(),
              const SizedBox(height: 12),
              _buildNativeOverviewCard(),
              const SizedBox(height: 12),
              _buildHeapOverviewCard(),
              const SizedBox(height: 12),
              _buildHeapDetailsCard(),
              const SizedBox(height: 12),
              _buildLeakDetectionCard(),
              const SizedBox(height: 12),
              _buildImageCacheCard(),
              const SizedBox(height: 12),
              _buildStorageCard(),
              const SizedBox(height: 12),
              _buildActionsCard(),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建开关卡片 / Build enable/disable switch card
  ///
  /// 顶部总开关，控制是否启用内存监控功能
  /// Top master switch, controls whether memory monitoring is enabled
  /// 关闭时会停止所有定时器和 VM Service 连接，避免性能开销
  /// When disabled, all timers and VM Service connections are stopped
  /// to avoid performance overhead
  Widget _buildEnabledSwitchCard() {
    final service = MemoryInspectorService.instance;
    final enabled = service.isEnabled;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(
          color: enabled
              ? InspectorColors.success.withValues(alpha: 0.3)
              : InspectorColors.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            enabled
                ? Icons.power_settings_new_rounded
                : Icons.power_off_rounded,
            size: 18,
            color: enabled ? InspectorColors.success : InspectorColors.textHint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Memory Monitoring',
                  style: TextStyle(
                    color: InspectorColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled
                      ? 'Enabled · collecting data'
                      : 'Disabled · no data collection',
                  style: TextStyle(
                    color: enabled
                        ? InspectorColors.success
                        : InspectorColors.textHint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            activeThumbColor: InspectorColors.success,
            activeTrackColor: InspectorColors.success.withValues(alpha: 0.3),
            inactiveThumbColor: InspectorColors.textHint,
            inactiveTrackColor: InspectorColors.border,
            onChanged: (value) {
              service.isEnabled = value;
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
    );
  }

  /// 构建未启用占位 / Build disabled placeholder
  ///
  /// 监控未启用时显示的说明文案，告知用户开启后的行为
  /// Shows instruction text when monitoring is disabled,
  /// explaining what happens when enabled
  Widget _buildDisabledPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(
            Icons.sensors_off_rounded,
            size: 40,
            color: InspectorColors.textHint,
          ),
          const SizedBox(height: 12),
          Text(
            'Memory monitoring is disabled',
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Turn on the switch above to start collecting memory data.\n'
            'Enabling will start timers and connect to VM Service (debug/profile only).',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: InspectorColors.textHint,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建趋势图卡片 / Build trend chart card
  Widget _buildTrendChartCard() {
    final service = MemoryInspectorService.instance;
    return MemoryTrendChart(
      snapshots: service.memorySnapshots,
      metric: _selectedMetric,
      vmServiceAvailable: service.vmServiceAvailable,
      onMetricChanged: (m) {
        setState(() {
          _selectedMetric = m;
        });
      },
    );
  }

  /// 构建 Native 内存概览卡片 / Build Native memory overview card
  ///
  /// 真机（Android/iOS）上显示进程级 Native 内存数据：
  /// Shows process-level Native memory data on real devices (Android/iOS):
  /// - Android: Total PSS、Dalvik PSS、Native PSS、Native Private Dirty
  /// - iOS: Physical Footprint、Compressed、Internal、Device Memory
  /// 桌面平台显示 N/A 占位 / Desktop platforms show N/A placeholder
  Widget _buildNativeOverviewCard() {
    final service = MemoryInspectorService.instance;
    final available = service.isNativeSupported;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.phone_android_rounded,
                size: 16,
                color: InspectorColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Native Memory',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildNativeStatusChip(available),
            ],
          ),
          const SizedBox(height: 14),
          if (available)
            _buildNativeMemoryDetails()
          else
            _buildUnavailableRow(
              'Native memory data unavailable\nRequires Android or iOS device',
            ),
        ],
      ),
    );
  }

  /// 构建 Native 内存详情内容 / Build Native memory detail content
  ///
  /// 根据 Android / iOS 平台显示不同的内存分项
  /// Shows different memory breakdowns based on Android / iOS platform
  Widget _buildNativeMemoryDetails() {
    final service = MemoryInspectorService.instance;
    final isAndroid = service.isNativeSupported && _isAndroidPlatform();
    final isIOS = service.isNativeSupported && _isIOSPlatform();

    if (isAndroid) {
      // Android: 显示 PSS 和 Private Dirty 分项
      // Android: Show PSS and Private Dirty breakdown
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 总 PSS（最重要的指标）/ Total PSS (most important metric)
          _buildNativeStatRow(
            label: 'Total PSS',
            value: formatBytes(service.currentTotalPss),
            color: InspectorColors.success,
            isHeader: true,
          ),
          const SizedBox(height: 10),
          // 分项 PSS / PSS breakdown
          Row(
            children: [
              Expanded(
                child: _buildCacheStat(
                  'Dalvik PSS',
                  formatBytes(service.currentDalvikPss),
                  InspectorColors.info,
                ),
              ),
              Expanded(
                child: _buildCacheStat(
                  'Native PSS',
                  formatBytes(service.currentNativePss),
                  InspectorColors.accent,
                ),
              ),
              Expanded(
                child: _buildCacheStat(
                  'Native Dirty',
                  formatBytes(service.currentNativePrivateDirty),
                  InspectorColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 设备内存状态 / Device memory status
          _buildDeviceMemoryRow(service),
        ],
      );
    } else if (isIOS) {
      // iOS: 显示 physicalFootprint（最准确指标）和压缩内存
      // iOS: Show physicalFootprint (most accurate metric) and compressed memory
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Physical Footprint（iOS 最准确的内存指标）
          // Physical Footprint (most accurate iOS memory metric)
          _buildNativeStatRow(
            label: 'Physical Footprint',
            value: formatBytes(service.currentPhysicalFootprint),
            color: InspectorColors.success,
            isHeader: true,
          ),
          const SizedBox(height: 10),
          // 分项 / Breakdown
          Row(
            children: [
              Expanded(
                child: _buildCacheStat(
                  'Compressed',
                  formatBytes(service.currentInternalCompressed),
                  InspectorColors.warning,
                ),
              ),
              Expanded(
                child: _buildCacheStat(
                  'Process RSS',
                  formatBytes(service.currentProcessRss),
                  InspectorColors.info,
                ),
              ),
              Expanded(
                child: _buildCacheStat(
                  'Device Avail',
                  formatBytes(service.deviceAvailMem),
                  InspectorColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 设备内存状态 / Device memory status
          _buildDeviceMemoryRow(service),
        ],
      );
    }

    // 未知平台时显示通用 RSS / Show generic RSS for unknown platform
    return _buildNativeStatRow(
      label: 'Process RSS',
      value: formatBytes(service.currentProcessRss),
      color: InspectorColors.info,
      isHeader: true,
    );
  }

  /// 构建设备内存状态行 / Build device memory status row
  Widget _buildDeviceMemoryRow(MemoryInspectorService service) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.memory_rounded,
            size: 12,
            color: service.isLowMemory
                ? InspectorColors.error
                : InspectorColors.textHint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Device: ${formatBytes(service.deviceAvailMem)} / ${formatBytes(service.deviceTotalMem)}',
              style: TextStyle(
                color: InspectorColors.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Spacer(),
          if (service.isLowMemory)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: InspectorColors.error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'LOW',
                style: TextStyle(
                  color: InspectorColors.error,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 构建 Native 状态标签 / Build Native status chip
  Widget _buildNativeStatusChip(bool available) {
    final color = available
        ? InspectorColors.success
        : InspectorColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            available ? 'Native: ON' : 'Native: OFF',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 Native 内存统计行 / Build Native memory stat row
  ///
  /// [isHeader] 为 true 时使用更大字体和高亮颜色
  /// When [isHeader] is true, uses larger font and highlight color
  Widget _buildNativeStatRow({
    required String label,
    required String value,
    required Color color,
    bool isHeader = false,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHeader
                ? InspectorColors.textPrimary
                : InspectorColors.textSecondary,
            fontSize: isHeader ? 12 : 11,
            fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isHeader ? 16 : 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// 判断当前是否 Android 平台 / Determine whether current platform is Android
  bool _isAndroidPlatform() {
    // 通过 deviceTotalMem > 0 且 currentPhysicalFootprint == 0 判断为 Android
    // Determine as Android when deviceTotalMem > 0 and currentPhysicalFootprint == 0
    final service = MemoryInspectorService.instance;
    return service.deviceTotalMem > 0 && service.currentPhysicalFootprint == 0;
  }

  /// 判断当前是否 iOS 平台 / Determine whether current platform is iOS
  bool _isIOSPlatform() {
    // 通过 currentPhysicalFootprint > 0 判断为 iOS
    // Determine as iOS when currentPhysicalFootprint > 0
    final service = MemoryInspectorService.instance;
    return service.currentPhysicalFootprint > 0;
  }

  /// 构建 Dart Heap 概览卡片 / Build Dart Heap overview card
  ///
  /// 当 VM Service 可用时显示 Heap Usage / Capacity / External 三个核心指标
  /// When VM Service is available, shows Heap Usage / Capacity / External three core metrics
  /// 不可用时显示 N/A 占位说明
  /// Otherwise shows N/A placeholder
  Widget _buildHeapOverviewCard() {
    final service = MemoryInspectorService.instance;
    final available = service.vmServiceAvailable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.memory_rounded,
                size: 16,
                color: InspectorColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Dart Heap',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildVmServiceStatusChip(available),
            ],
          ),
          const SizedBox(height: 14),
          if (available)
            Row(
              children: [
                Expanded(
                  child: _buildCacheStat(
                    'Usage',
                    formatBytes(service.currentHeapUsage),
                    InspectorColors.success,
                  ),
                ),
                Expanded(
                  child: _buildCacheStat(
                    'Capacity',
                    formatBytes(service.currentHeapCapacity),
                    InspectorColors.info,
                  ),
                ),
                Expanded(
                  child: _buildCacheStat(
                    'External',
                    formatBytes(service.currentExternalUsage),
                    InspectorColors.accent,
                  ),
                ),
              ],
            )
          else
            _buildUnavailableRow(
              'Dart Heap data unavailable\nAvailable in debug/profile mode only',
            ),
          if (available) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: service.currentHeapCapacity > 0
                    ? service.currentHeapUsage / service.currentHeapCapacity
                    : 0,
                backgroundColor: InspectorColors.surface,
                valueColor: AlwaysStoppedAnimation<Color>(
                  InspectorColors.success,
                ),
                minHeight: 4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建新生代/老生代详细数据卡片 / Build new/old space detail card
  ///
  /// VM Service 可用时显示 New Space / Old Space 的 Usage / Capacity / External
  /// When VM Service is available, shows New Space / Old Space Usage / Capacity / External
  /// 不可用时显示 N/A 占位说明
  /// Otherwise shows N/A placeholder
  Widget _buildHeapDetailsCard() {
    final service = MemoryInspectorService.instance;
    final available = service.vmServiceAvailable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.data_usage_rounded,
                size: 16,
                color: InspectorColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Heap Generations',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (available) ...[
            _buildGenerationRow(
              title: 'New Space',
              color: InspectorColors.warning,
              usage: service.currentNewSpaceUsage,
              capacity: service.currentNewSpaceCapacity,
              external: service.currentNewSpaceExternalUsage,
            ),
            const SizedBox(height: 12),
            _buildGenerationRow(
              title: 'Old Space',
              color: InspectorColors.accent,
              usage: service.currentOldSpaceUsage,
              capacity: service.currentOldSpaceCapacity,
              external: service.currentOldSpaceExternalUsage,
            ),
          ] else
            _buildUnavailableRow(
              'New/Old space data unavailable\nRequires VM Service connection',
            ),
        ],
      ),
    );
  }

  /// 构建内存代际行 / Build generation row
  ///
  /// [title] 标题，[color] 主色，[usage] 已使用，[capacity] 容量，[external] 外部内存
  /// [title] title, [color] primary color, [usage] used, [capacity] capacity, [external] external memory
  Widget _buildGenerationRow({
    required String title,
    required Color color,
    required int usage,
    required int capacity,
    required int external,
  }) {
    final usageRate = capacity > 0 ? usage / capacity : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${formatBytes(usage)} / ${formatBytes(capacity)}',
              style: TextStyle(
                color: InspectorColors.textPrimary,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: usageRate,
            backgroundColor: InspectorColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(
              usageRate > 0.85
                  ? InspectorColors.error
                  : usageRate > 0.7
                  ? InspectorColors.warning
                  : color,
            ),
            minHeight: 3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'External: ${formatBytes(external)}',
          style: TextStyle(
            color: InspectorColors.textHint,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// 构建 VM Service 状态标签 / Build VM Service status chip
  Widget _buildVmServiceStatusChip(bool available) {
    final color = available
        ? InspectorColors.success
        : InspectorColors.textHint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            available ? 'VM: ON' : 'VM: OFF',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w500,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// 构建不可用占位行 / Build unavailable placeholder row
  Widget _buildUnavailableRow(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Text(
            'N/A',
            style: TextStyle(
              color: InspectorColors.textHint,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: InspectorColors.textHint,
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建缓存统计项 / Build cache stat item
  Widget _buildCacheStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: InspectorColors.textHint, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// 构建图片缓存卡片 / Build image cache card
  Widget _buildImageCacheCard() {
    final service = MemoryInspectorService.instance;
    final currentSize = service.imageCacheCurrentSize;
    final currentSizeBytes = service.imageCacheCurrentSizeBytes;
    final maxSize = service.imageCacheMaximumSize;
    final maxSizeBytes = service.imageCacheMaximumSizeBytes;
    final pendingCount = service.imageCachePendingCount;
    final liveCount = service.imageCacheLiveCount;
    final usageRate = maxSizeBytes > 0 ? currentSizeBytes / maxSizeBytes : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.image_rounded,
                size: 16,
                color: InspectorColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Image Cache',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  service.clearImageCache();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: InspectorColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: InspectorColors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.delete_sweep_rounded,
                        size: 14,
                        color: InspectorColors.error,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Clear',
                        style: TextStyle(
                          color: InspectorColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildCacheStat(
                  'Size',
                  '${formatBytes(currentSizeBytes)} / ${formatBytes(maxSizeBytes)}',
                  InspectorColors.info,
                ),
              ),
              Expanded(
                child: _buildCacheStat(
                  'Count',
                  '$currentSize / $maxSize',
                  InspectorColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: usageRate,
              backgroundColor: InspectorColors.surface,
              valueColor: AlwaysStoppedAnimation<Color>(
                usageRate > 0.85
                    ? InspectorColors.error
                    : usageRate > 0.7
                    ? InspectorColors.warning
                    : InspectorColors.info,
              ),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatusChip(
                'Pending',
                pendingCount,
                InspectorColors.warning,
              ),
              const SizedBox(width: 10),
              _buildStatusChip('Live', liveCount, InspectorColors.success),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建状态标签 / Build status chip
  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$label: $count',
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建存储统计卡片 / Build storage stats card
  Widget _buildStorageCard() {
    final service = MemoryInspectorService.instance;
    final documentsSize = service.cachedDocumentsSize;
    final cacheSize = service.cachedCacheSize;
    final databaseSize = service.cachedDatabaseSize;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sd_storage_rounded,
                size: 16,
                color: InspectorColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'App Storage',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await MemoryInspectorService.instance.clearCacheDir();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: InspectorColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: InspectorColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cleaning_services_rounded,
                        size: 14,
                        color: InspectorColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Clear Cache',
                        style: TextStyle(
                          color: InspectorColors.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildStorageStat(
            label: 'Documents',
            icon: Icons.folder_rounded,
            color: InspectorColors.info,
            size: documentsSize,
          ),
          const SizedBox(height: 10),
          _buildStorageStat(
            label: 'Temp Cache',
            icon: Icons.timer_rounded,
            color: InspectorColors.warning,
            size: cacheSize,
          ),
          const SizedBox(height: 10),
          _buildStorageStat(
            label: 'Databases',
            icon: Icons.storage_rounded,
            color: InspectorColors.success,
            size: databaseSize,
          ),
        ],
      ),
    );
  }

  /// 构建存储统计项 / Build storage stat item
  Widget _buildStorageStat({
    required String label,
    required IconData icon,
    required Color color,
    required int size,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(color: InspectorColors.textSecondary, fontSize: 12),
        ),
        const Spacer(),
        Text(
          formatBytes(size),
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// 构建操作按钮卡片 / Build action buttons card
  ///
  /// 包含以下按钮 / Contains the following buttons:
  /// - Trigger GC（仅 VM Service 可用时可点击，否则禁用并显示提示）
  ///   Trigger GC (only clickable when VM Service is available, otherwise disabled with hint)
  /// - Clear History（清空内存历史快照）/ Clear History (clear memory history snapshots)
  /// - Clear Image Cache / Clear App Cache
  Widget _buildActionsCard() {
    final service = MemoryInspectorService.instance;
    final vmAvailable = service.vmServiceAvailable;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune_rounded,
                size: 16,
                color: InspectorColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Actions',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Trigger\nGC',
                  color: vmAvailable
                      ? InspectorColors.success
                      : InspectorColors.textHint,
                  enabled: vmAvailable,
                  onTap: () async {
                    final ok = await service.triggerGc();
                    if (mounted) {
                      _showToast(
                        ok
                            ? 'GC triggered'
                            : 'GC failed (VM Service unavailable)',
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.history_rounded,
                  label: 'Clear\nHistory',
                  color: InspectorColors.accent,
                  onTap: () {
                    service.clearMemorySnapshots();
                    if (mounted) {
                      _showToast('Memory history cleared');
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  icon: Icons.image_not_supported_rounded,
                  label: 'Clear Image\nCache',
                  color: InspectorColors.error,
                  onTap: () {
                    MemoryInspectorService.instance.clearImageCache();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.cleaning_services_rounded,
                  label: 'Clear App\nCache',
                  color: InspectorColors.warning,
                  onTap: () async {
                    await MemoryInspectorService.instance.clearCacheDir();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建操作按钮 / Build action button
  ///
  /// [enabled] 为 false 时按钮变灰且不可点击
  /// When [enabled] is false, button is grayed out and not clickable
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final effectiveColor = enabled ? color : InspectorColors.textHint;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: effectiveColor.withValues(alpha: enabled ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: effectiveColor.withValues(alpha: enabled ? 0.3 : 0.1),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: effectiveColor),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: effectiveColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建内存泄漏检测卡片 / Build memory leak detection card
  ///
  /// 展示以下内容 / Displays the following:
  /// - 状态统计：追踪中 / 疑似泄漏 / 已释放 数量
  ///   Status stats: Tracking / Suspected Leaked / Released counts
  /// - 疑似泄漏对象列表（红色高亮，显示类型、标签、超时时长）
  ///   Suspected leak object list (red highlight, shows type, tag, overdue duration)
  /// - 追踪中对象列表（显示类型、标签、注册时间、预期释放时间）
  ///   Tracking object list (shows type, tag, register time, expected release time)
  /// - "Clear All" 按钮：清空所有追踪记录
  ///   "Clear All" button: clear all tracking records
  ///
  /// 若无任何追踪记录，显示使用说明文案
  /// If no tracking records at all, shows usage instruction text
  Widget _buildLeakDetectionCard() {
    final service = MemoryInspectorService.instance;
    final trackingCount = service.trackingCount;
    final leakedCount = service.leakedCount;
    final releasedCount = service.releasedCount;
    final total = trackingCount + leakedCount + releasedCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行 / Title row
          Row(
            children: [
              Icon(
                Icons.bug_report_rounded,
                size: 16,
                color: leakedCount > 0
                    ? InspectorColors.error
                    : InspectorColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Memory Leak Detection',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // 清空所有记录按钮 / Clear all records button
              if (total > 0)
                GestureDetector(
                  onTap: () {
                    service.clearLeakRecords();
                    if (mounted) _showToast('All leak records cleared');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: InspectorColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: InspectorColors.error.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.delete_sweep_rounded,
                          size: 13,
                          color: InspectorColors.error,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          'Clear',
                          style: TextStyle(
                            color: InspectorColors.error,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 状态统计行 / Status stats row
          Row(
            children: [
              Expanded(
                child: _buildLeakStatChip(
                  'Tracking',
                  trackingCount,
                  InspectorColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLeakStatChip(
                  'Leaked',
                  leakedCount,
                  leakedCount > 0
                      ? InspectorColors.error
                      : InspectorColors.textHint,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLeakStatChip(
                  'Released',
                  releasedCount,
                  InspectorColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 无追踪记录时：显示使用说明
          // When no tracking records: show usage instructions
          if (total == 0)
            _buildLeakUsageInstructions()
          else ...[
            // 优先显示疑似泄漏列表
            // Prioritize showing suspected leak list
            if (leakedCount > 0) ...[
              _buildSectionTitle('Suspected Leaks', InspectorColors.error),
              const SizedBox(height: 8),
              ...service.leakedRecords.take(50).map((r) => _buildLeakItem(r)),
              if (service.leakedRecords.length > 50)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '... and ${service.leakedRecords.length - 50} more',
                    style: TextStyle(
                      color: InspectorColors.textHint,
                      fontSize: 10,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
            ],

            // 追踪中 / 验证中 列表
            // Tracking / Verifying list
            if (trackingCount > 0) ...[
              _buildSectionTitle('Tracking Objects', InspectorColors.info),
              const SizedBox(height: 8),
              ...(service.leakRecords
                      .where(
                        (r) =>
                            r.status == LeakStatus.tracking ||
                            r.status == LeakStatus.verifying,
                      )
                      .toList()
                    ..sort((a, b) => b.trackedAt.compareTo(a.trackedAt)))
                  .take(50)
                  .map((r) => _buildLeakItem(r)),
            ],
          ],
        ],
      ),
    );
  }

  /// 构建泄漏检测统计芯片 / Build leak detection stat chip
  Widget _buildLeakStatChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建小节标题 / Build section title
  Widget _buildSectionTitle(String text, Color color) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 构建单个泄漏追踪条目 / Build single leak tracking item
  Widget _buildLeakItem(LeakRecord record) {
    final isLeaked = record.status == LeakStatus.leaked;
    final isVerifying = record.status == LeakStatus.verifying;
    final isReleased = record.status == LeakStatus.released;

    Color statusColor;
    String statusText;
    if (isLeaked) {
      statusColor = InspectorColors.error;
      statusText = 'LEAKED · ${_formatDuration(record.overdue)} overdue';
    } else if (isVerifying) {
      statusColor = InspectorColors.warning;
      statusText = 'Verifying...';
    } else if (isReleased) {
      statusColor = InspectorColors.success;
      statusText = 'Released';
    } else {
      // tracking
      statusColor = InspectorColors.info;
      final remain = record.expectedReleaseAt.difference(DateTime.now());
      if (remain.isNegative) {
        statusText = 'Expiring...';
      } else {
        statusText = '${_formatDuration(remain)} remain';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: isLeaked
            ? InspectorColors.error.withValues(alpha: 0.08)
            : isVerifying
            ? InspectorColors.warning.withValues(alpha: 0.06)
            : isReleased
            ? InspectorColors.success.withValues(alpha: 0.05)
            : InspectorColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isLeaked
              ? InspectorColors.error.withValues(alpha: 0.3)
              : isVerifying
              ? InspectorColors.warning.withValues(alpha: 0.2)
              : isReleased
              ? InspectorColors.success.withValues(alpha: 0.15)
              : InspectorColors.border.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  record.displayName,
                  style: TextStyle(
                    color: InspectorColors.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'id: ${record.objectId.toRadixString(16).padLeft(8, '0')} · '
            'tracked: ${_formatDuration(record.elapsed)} ago',
            style: TextStyle(
              color: InspectorColors.textHint,
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// 构建泄漏检测使用说明 / Build leak detection usage instructions
  Widget _buildLeakUsageInstructions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to use',
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Register objects you expect to be released with the leak '
            'tracking API. Once an object outlives its expected release '
            'window, it will be reported here as a suspected leak.',
            style: TextStyle(
              color: InspectorColors.textHint,
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化 Duration 为简短可读字符串（如 "1m20s" / "30s" / "450ms"）
  /// Format Duration to short readable string (e.g. "1m20s" / "30s" / "450ms")
  static String _formatDuration(Duration d) {
    if (d.isNegative) return '0s';
    if (d.inMilliseconds < 1000) return '${d.inMilliseconds}ms';
    if (d.inSeconds < 60) return '${d.inSeconds}s';
    if (d.inMinutes < 60) {
      final s = d.inSeconds.remainder(60);
      return s > 0 ? '${d.inMinutes}m${s}s' : '${d.inMinutes}m';
    }
    if (d.inHours < 24) {
      final m = d.inMinutes.remainder(60);
      return m > 0 ? '${d.inHours}h${m}m' : '${d.inHours}h';
    }
    return '${d.inDays}d';
  }

  /// 显示 Toast 提示 / Show toast hint
  void _showToast(String message) {
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 80,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: InspectorColors.card.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: InspectorColors.border, width: 0.5),
              ),
              child: Text(
                message,
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);
    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }
}
