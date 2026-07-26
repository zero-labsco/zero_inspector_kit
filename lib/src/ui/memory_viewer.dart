import 'package:flutter/material.dart';
import 'theme/inspector_theme.dart';
import '../services/memory_inspector_service.dart';

/// 内存查看器 / Memory viewer
///
/// 展示图片缓存和应用存储统计信息
/// Displays image cache and app storage statistics
///
/// TODO: 恢复 Dart VM Heap 内存监控功能
/// TODO: Restore Dart VM Heap memory monitoring feature
/// 之前包含 Dart Heap 内存概览、实时趋势图、GC 触发等功能，
/// 但在 Android 真机上连接 VM Service 存在问题，暂时移除。
/// Previously included Dart Heap memory overview, real-time trend chart, GC trigger, etc.,
/// but there are issues connecting to VM Service on Android real devices, temporarily removed.
class MemoryViewer extends StatefulWidget {
  const MemoryViewer({super.key});

  @override
  State<MemoryViewer> createState() => _MemoryViewerState();
}

class _MemoryViewerState extends State<MemoryViewer> {
  @override
  void initState() {
    super.initState();
    MemoryInspectorService.instance.startMonitoring();
    MemoryInspectorService.instance.addListener(_onMemoryChanged);
  }

  @override
  void dispose() {
    MemoryInspectorService.instance.removeListener(_onMemoryChanged);
    super.dispose();
  }

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
    return Container(
      color: InspectorColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageCacheCard(),
            const SizedBox(height: 12),
            _buildStorageCard(),
            const SizedBox(height: 12),
            _buildActionsCard(),
          ],
        ),
      ),
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
  Widget _buildActionsCard() {
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
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
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
}
