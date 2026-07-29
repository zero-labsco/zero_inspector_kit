import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

/// 帧耗时记录 / Frame duration record
///
/// 记录单帧的耗时信息，用于掉帧分析 / Records frame duration info for jank analysis
class FrameRecord {
  /// 帧开始时间戳（微秒）/ Frame start timestamp (microseconds)
  final int timestamp;

  /// 帧耗时（微秒）/ Frame duration (microseconds)
  final int durationUs;

  /// 是否掉帧（>16ms）/ Whether frame is janky (>16ms)
  bool get isJanky => durationUs > 16000;

  const FrameRecord({required this.timestamp, required this.durationUs});
}

/// FPS 监控服务 / FPS monitoring service
///
/// 通过 `WidgetsBinding.instance.addTimingsCallback` 采集帧数据，
/// Collects frame data via `WidgetsBinding.instance.addTimingsCallback`,
/// 提供实时 FPS 计算、帧耗时统计、掉帧检测功能。
/// Provides real-time FPS calculation, frame duration stats, and jank detection.
///
/// 使用方式 / Usage:
/// ```dart
/// // 启动 FPS 监控 / Start FPS monitoring
/// FpsService.instance.start();
///
/// // 获取当前 FPS / Get current FPS
/// double currentFps = FpsService.instance.currentFps;
///
/// // 关闭 FPS 监控 / Stop FPS monitoring
/// FpsService.instance.stop();
/// ```
class FpsService extends ChangeNotifier {
  FpsService._();

  /// 单例实例 / Singleton instance
  static final FpsService instance = FpsService._();

  // ==================== 常量配置 / Constants ====================

  /// 最大历史帧记录数 / Maximum historical frame records
  static const int _maxFrameRecords = 3600;

  /// FPS 刷新间隔（毫秒）/ FPS refresh interval (ms)
  static const int _fpsRefreshIntervalMs = 500;

  /// 掉帧阈值（微秒）/ Jank threshold (microseconds)
  ///
  /// 60fps 下每帧耗时约 16.67ms，超过此值视为掉帧
  /// At 60fps each frame takes ~16.67ms, exceeding this is considered jank
  static const int _jankThresholdUs = 16000;

  // ==================== 状态变量 / State variables ====================

  /// 是否正在监控 / Whether monitoring is active
  bool _isRunning = false;

  /// 当前 FPS / Current FPS
  double _currentFps = 0;

  /// 最近帧耗时列表 / Recent frame duration list
  final List<FrameRecord> _frameRecords = [];

  /// 帧开始时间戳缓存 / Frame start timestamp cache
  final Map<int, int> _frameStartTimes = {};

  /// 最近一秒内的帧时间戳 / Frame timestamps in the most recent second
  final List<int> _recentFrameTimestamps = [];

  /// FPS 刷新定时器 / FPS refresh timer
  Timer? _fpsTimer;

  /// 累计掉帧数 / Total janky frame count
  int _totalJankyCount = 0;

  /// 累计总帧数 / Total frame count
  int _totalFrameCount = 0;

  /// 最近 60 个 FPS 历史值 / Recent 60 FPS history values
  final List<double> _fpsHistory = [];

  // ==================== 公开属性 / Public properties ====================

  /// 是否正在监控 / Whether monitoring is active
  bool get isRunning => _isRunning;

  /// 当前 FPS / Current FPS
  double get currentFps => _currentFps;

  /// 最近帧记录列表 / Recent frame record list
  List<FrameRecord> get frameRecords => List.unmodifiable(_frameRecords);

  /// 最近 FPS 历史值（60个）/ Recent FPS history values (60 entries)
  List<double> get fpsHistory => List.unmodifiable(_fpsHistory);

  /// 累计掉帧数 / Total janky frame count
  int get totalJankyCount => _totalJankyCount;

  /// 累计总帧数 / Total frame count
  int get totalFrameCount => _totalFrameCount;

  /// 掉帧率（百分比）/ Jank rate (percentage)
  double get jankRate =>
      _totalFrameCount > 0 ? (_totalJankyCount / _totalFrameCount) * 100 : 0;

  /// 最近一帧是否掉帧 / Whether the most recent frame is janky
  bool get lastFrameJanky =>
      _frameRecords.isNotEmpty && _frameRecords.last.isJanky;

  // ==================== 公开方法 / Public methods ====================

  /// 启动 FPS 监控 / Start FPS monitoring
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _currentFps = 0;
    _totalJankyCount = 0;
    _totalFrameCount = 0;
    _frameRecords.clear();
    _fpsHistory.clear();
    _recentFrameTimestamps.clear();
    _frameStartTimes.clear();

    WidgetsBinding.instance.addTimingsCallback(_onFrameTimings);
    _startFpsTimer();
    notifyListeners();
  }

  /// 停止 FPS 监控 / Stop FPS monitoring
  void stop() {
    if (!_isRunning) return;
    _isRunning = false;
    WidgetsBinding.instance.removeTimingsCallback(_onFrameTimings);
    _fpsTimer?.cancel();
    _fpsTimer = null;
    notifyListeners();
  }

  /// 清空历史数据 / Clear historical data
  void clear() {
    _frameRecords.clear();
    _fpsHistory.clear();
    _totalJankyCount = 0;
    _totalFrameCount = 0;
    notifyListeners();
  }

  // ==================== 内部实现 / Internal implementation ====================

  /// 帧时间回调（来自 Flutter 引擎）/ Frame timing callback (from Flutter engine)
  ///
  /// 注意：[timings] 是批量回调，一次可能包含多帧的 timing，
  /// 必须为每帧单独添加时间戳到 [_recentFrameTimestamps]，否则 FPS 计算严重偏低。
  /// Note: [timings] is batched, may contain multiple frames per call;
  /// must add a timestamp per frame to [_recentFrameTimestamps], otherwise
  /// FPS will be severely undercounted.
  void _onFrameTimings(List<FrameTiming> timings) {
    // 用当前时间作为本批次的时间戳 / Use current time as the timestamp for this batch
    // 关键是每帧都计一次，而不是时间戳的精确值 / Key is to count per frame, not the exact timestamp
    // 注意：FrameTiming 未公开帧原始时间戳，只能用 DateTime.now()
    // Note: FrameTiming does not expose raw frame timestamp; use DateTime.now()
    final now = DateTime.now().microsecondsSinceEpoch;

    for (final timing in timings) {
      // 获取帧时长 / Get frame duration
      // buildDuration: 构建耗时、rasterizationDuration: 光栅化耗时
      // buildDuration: build time, rasterizationDuration: raster time
      final durationUs = timing.buildDuration.inMicroseconds;

      // 添加记录 / Add record
      final record = FrameRecord(timestamp: now, durationUs: durationUs);
      _frameRecords.add(record);
      _totalFrameCount++;

      // 检测掉帧 / Detect jank
      if (durationUs > _jankThresholdUs) {
        _totalJankyCount++;
      }

      // 每帧添加一个时间戳用于 FPS 计算 / Add a timestamp per frame for FPS calculation
      _recentFrameTimestamps.add(now);
    }

    // 限制历史记录数量 / Limit history size
    if (_frameRecords.length > _maxFrameRecords) {
      _frameRecords.removeRange(0, _frameRecords.length - _maxFrameRecords);
    }
  }

  /// 启动 FPS 刷新定时器 / Start FPS refresh timer
  void _startFpsTimer() {
    _fpsTimer?.cancel();
    _fpsTimer = Timer.periodic(
      const Duration(milliseconds: _fpsRefreshIntervalMs),
      (_) => _refreshFps(),
    );
  }

  /// 刷新 FPS 计算 / Refresh FPS calculation
  void _refreshFps() {
    if (!_isRunning) return;

    final now = DateTime.now().microsecondsSinceEpoch;

    // 清理超过 1 秒的旧时间戳 / Remove timestamps older than 1 second
    _recentFrameTimestamps.removeWhere((ts) => now - ts > 1000000);

    // FPS = 最近 1 秒内的帧数 / FPS = frames in the most recent second
    final fps = _recentFrameTimestamps.length.toDouble();
    _currentFps = fps;

    // 记录 FPS 历史 / Record FPS history
    _fpsHistory.add(fps);
    if (_fpsHistory.length > 60) {
      _fpsHistory.removeAt(0);
    }

    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
