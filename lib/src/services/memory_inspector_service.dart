import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';

/// 内存检查服务 / Memory inspector service
///
/// 负责采集应用内存相关数据，提供图片缓存和存储统计功能
/// Responsible for collecting app memory-related data, providing image cache and storage statistics
///
/// 使用方式 / Usage:
/// ```dart
/// MemoryInspectorService.instance.startMonitoring();
/// ```
///
/// TODO: 恢复 Dart VM Heap 内存监控功能
/// TODO: Restore Dart VM Heap memory monitoring feature
/// 之前通过 VM Service 实现 Dart Heap 内存采集和趋势图，
/// 但在 Android 真机上连接 VM Service 存在问题，暂时移除。
/// Previously implemented Dart Heap memory collection and trend chart via VM Service,
/// but there are issues connecting to VM Service on Android real devices, temporarily removed.
class MemoryInspectorService extends ChangeNotifier {
  MemoryInspectorService._();

  /// 单例实例 / Singleton instance
  static final MemoryInspectorService instance = MemoryInspectorService._();

  /// 存储统计刷新间隔（毫秒）/ Storage stats refresh interval (milliseconds)
  final int _storageRefreshIntervalMs = 3000;

  /// 是否正在监控 / Whether monitoring is active
  bool _isMonitoring = false;

  /// 获取是否正在监控 / Get whether monitoring is active
  bool get isMonitoring => _isMonitoring;

  /// 存储统计刷新定时器 / Storage stats refresh timer
  Timer? _storageTimer;

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

  /// 开始内存监控 / Start memory monitoring
  ///
  /// 启动存储统计定时刷新
  /// Starts periodic storage stats refresh
  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _startStorageStatsRefresh();
    notifyListeners();
  }

  /// 停止内存监控 / Stop memory monitoring
  void stopMonitoring() {
    _storageTimer?.cancel();
    _storageTimer = null;
    _isMonitoring = false;
    notifyListeners();
  }

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
    } catch (e) {
      debugPrint('MemoryInspector: Failed to refresh storage stats - $e');
    }
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

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
