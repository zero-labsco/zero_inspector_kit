import 'dart:async';
import 'dart:ui' show FramePhase;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

import 'alert_service.dart';

/// 帧耗时记录 / Frame duration record
///
/// 记录单帧的耗时信息，用于掉帧分析 / Records frame duration info for jank analysis
class FrameRecord {
  /// 帧开始时间戳（微秒，来自 FramePhase.buildStart）/ Frame start timestamp (microseconds, from FramePhase.buildStart)
  final int timestamp;

  /// 帧总耗时（微秒）= rasterFinish - buildStart，包含 build 和 raster 全过程
  /// Frame total duration (microseconds) = rasterFinish - buildStart, includes both build and raster phases
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
    for (final timing in timings) {
      // 使用帧真实开始时间戳（buildStart 阶段），避免批量回调时间戳相同问题
      // Use the real frame start timestamp (buildStart phase) to avoid
      // batch-callback timestamp collision (all frames in a batch sharing
      // the same DateTime.now() value)
      final frameStartUs = timing.timestampInMicroseconds(
        FramePhase.buildStart,
      );

      // 帧总耗时 = rasterFinish - buildStart，包含 build 和 raster 全过程
      // Frame total duration = rasterFinish - buildStart, includes both
      // build phase (widget tree construction) and raster phase (GPU painting)
      // 注意：不能只用 buildDuration，否则会漏判 GPU 光栅化卡顿
      // Note: cannot use buildDuration alone, otherwise GPU raster jank is missed
      final rasterFinishUs = timing.timestampInMicroseconds(
        FramePhase.rasterFinish,
      );
      final durationUs = rasterFinishUs - frameStartUs;

      // 添加记录 / Add record
      final record = FrameRecord(
        timestamp: frameStartUs,
        durationUs: durationUs,
      );
      _frameRecords.add(record);
      _totalFrameCount++;

      // 检测掉帧 / Detect jank
      if (durationUs > _jankThresholdUs) {
        _totalJankyCount++;
      }

      // 每帧添加真实时间戳用于 FPS 计算 / Add real frame timestamp per frame for FPS calculation
      _recentFrameTimestamps.add(frameStartUs);
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

    // 重要：必须使用与帧时间戳相同的时钟基准 / Must use same clock base as frame timestamps
    // FrameTiming.timestampInMicroseconds 返回 monotonic time（引擎启动以来微秒数），
    // 而 DateTime.now().microsecondsSinceEpoch 返回 wall clock（自 1970 UTC 微秒数）。
    // 两者差值巨大，混用会导致所有时间戳被误清理，FPS 永远为 0。
    // FrameTiming.timestampInMicroseconds returns monotonic time (microseconds since
    // engine start), while DateTime.now().microsecondsSinceEpoch returns wall clock
    // (microseconds since 1970 UTC). Mixing them causes all timestamps to be
    // erroneously purged, making FPS always 0.
    //
    // 因此用帧时间戳中的最大值作为 "now"：有新帧时它自然推进，无新帧时旧帧仍被清理。
    // Use the max frame timestamp as "now": it advances naturally when new frames
    // arrive, and old frames are still purged correctly when idle.
    if (_recentFrameTimestamps.isEmpty) {
      _currentFps = 0;
    } else {
      final now = _recentFrameTimestamps.reduce((a, b) => a > b ? a : b);

      // 清理超过 1 秒的旧时间戳 / Remove timestamps older than 1 second
      _recentFrameTimestamps.removeWhere((ts) => now - ts > 1000000);

      // FPS = 最近 1 秒内的帧数 / FPS = frames in the most recent second
      _currentFps = _recentFrameTimestamps.length.toDouble();
    }

    // 记录 FPS 历史 / Record FPS history
    _fpsHistory.add(_currentFps);
    if (_fpsHistory.length > 60) {
      _fpsHistory.removeAt(0);
    }

    // 告警检测 / Alert check
    AlertService.instance.checkFps(_currentFps);

    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
