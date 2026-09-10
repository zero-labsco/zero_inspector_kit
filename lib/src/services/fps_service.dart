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

  /// build 阶段耗时（微秒）= buildFinish - buildStart（Widget 树构建，含 layout/paint 调度）
  /// Build-phase duration (microseconds) = buildFinish - buildStart (widget tree construction).
  final int buildDurationUs;

  /// raster 阶段耗时（微秒）= rasterFinish - rasterStart（GPU 光栅化/合成）
  /// Raster-phase duration (microseconds) = rasterFinish - rasterStart (GPU rasterization/compositing).
  final int rasterDurationUs;

  /// 帧总耗时（微秒）= rasterFinish - buildStart，包含 build 和 raster 全过程
  /// Frame total duration (microseconds) = rasterFinish - buildStart, includes both build and raster phases
  final int durationUs;

  /// 是否掉帧（默认 >16ms，可传入设备自适应阈值）/ Whether frame is janky
  ///
  /// 阈值默认 16ms（60fps 预算），但调用方应传入 [FpsService.jankThresholdUs]
  /// 以按设备刷新率自适应（如 120Hz 设备约 8.3ms）。
  /// Defaults to 16ms (60fps budget), but callers should pass the refresh-rate
  /// adaptive [FpsService.jankThresholdUs] (≈8.3ms on a 120Hz device).
  bool isJanky([int? thresholdUs]) => durationUs > (thresholdUs ?? 16000);

  const FrameRecord({
    required this.timestamp,
    required this.buildDurationUs,
    required this.rasterDurationUs,
    required this.durationUs,
  });
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
  /// 自适应：按设备标称刷新率换算每帧预算（60Hz≈16.7ms、120Hz≈8.3ms），
  /// 高刷设备上同样严格的卡顿判定，避免 120Hz 屏被宽松阈值放过。
  /// Adaptive: the per-frame budget is derived from the display refresh rate
  /// (≈16.7ms at 60Hz, ≈8.3ms at 120Hz) so high-refresh displays keep a tight
  /// jank bar instead of being let through by a fixed 16ms cutoff.
  int get _jankThresholdUs => (1000000 / _displayRefreshRate).round();

  /// 公开的自适应掉帧阈值（微秒）/ Public adaptive jank threshold (microseconds)
  int get jankThresholdUs => _jankThresholdUs;

  /// 低活跃判定：1 秒窗口内帧数不超过此值视为无持续动画渲染。
  /// Low-activity threshold: at most this many frames per 1s window means no
  /// continuous animation is being rendered.
  ///
  /// 无动画/静止时 Flutter 引擎不产帧，监控 UI 自身每 500ms 的周期重绘
  /// 每秒只贡献约 2 帧。这类帧与真实动画帧差异巨大，可用于区分「静止」
  /// 与「掉帧卡顿」，避免把静止页面误报为低 FPS 告警。
  /// When the UI is still, the engine produces no frames except the monitor's
  /// own periodic rebuilds (~2 fps). This distinguishes a "still" screen from
  /// genuine jank, so a static page is not misreported as a low-FPS alert.
  static const int _lowActivityFrameThreshold = 4;

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

  /// 是否处于空闲（无渲染请求）状态 / Whether idle (no render requested)
  bool _isIdle = false;

  /// 获取是否空闲（无动画/无渲染时为真，此时低 FPS 不算性能问题）
  /// Get whether idle (true when no animation/render; low FPS then is not a perf problem)
  bool get isIdle => _isIdle;

  /// 最近一次活跃渲染时的 FPS，空闲时回退显示，避免把"静止"误判为 0/卡顿。
  /// Last active FPS, used as the idle fallback display so a still app isn't
  /// misread as 0 FPS / jank.
  double _lastActiveFps = 0;

  /// 设备标称刷新率（Hz），空闲时用作回退显示值 / Nominal display refresh rate
  double get _displayRefreshRate {
    try {
      final views = WidgetsBinding.instance.platformDispatcher.views;
      if (views.isNotEmpty) return views.first.display.refreshRate;
    } catch (_) {}
    return 60.0;
  }

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
      _frameRecords.isNotEmpty && _frameRecords.last.isJanky(_jankThresholdUs);

  // ==================== 公开方法 / Public methods ====================

  /// 启动 FPS 监控 / Start FPS monitoring
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _currentFps = 0;
    _isIdle = false;
    _lastActiveFps = 0;
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
    _isIdle = false;
    _lastActiveFps = 0;
    _currentFps = 0;
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
      final buildFinishUs = timing.timestampInMicroseconds(
        FramePhase.buildFinish,
      );
      final rasterStartUs = timing.timestampInMicroseconds(
        FramePhase.rasterStart,
      );

      // 帧总耗时 = rasterFinish - buildStart，包含 build 和 raster 全过程
      // Frame total duration = rasterFinish - buildStart, includes both
      // build phase (widget tree construction) and raster phase (GPU painting)
      // 注意：不能只用 buildDuration，否则会漏判 GPU 光栅化卡顿
      // Note: cannot use buildDuration alone, otherwise GPU raster jank is missed
      final rasterFinishUs = timing.timestampInMicroseconds(
        FramePhase.rasterFinish,
      );
      final buildDurationUs = buildFinishUs - frameStartUs;
      final rasterDurationUs = rasterFinishUs - rasterStartUs;
      final durationUs = rasterFinishUs - frameStartUs;

      // 添加记录 / Add record
      final record = FrameRecord(
        timestamp: frameStartUs,
        buildDurationUs: buildDurationUs,
        rasterDurationUs: rasterDurationUs,
        durationUs: durationUs,
      );
      _frameRecords.add(record);
      _totalFrameCount++;

      // 检测掉帧 / Detect jank (adaptive threshold)
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
      // 空闲：无渲染请求。FPS 回退为显示刷新率并标记空闲态，不告警，
      // 避免把"静止/无动画"误判为性能 FPS 问题。
      // Idle: no render requested. Fall back to the display refresh rate, mark
      // idle, and skip the alert so a still app isn't misjudged as jank.
      _isIdle = true;
      _currentFps = _lastActiveFps > 0 ? _lastActiveFps : _displayRefreshRate;
    } else {
      final now = _recentFrameTimestamps.reduce((a, b) => a > b ? a : b);

      // 清理超过 1 秒的旧时间戳 / Remove timestamps older than 1 second
      _recentFrameTimestamps.removeWhere((ts) => now - ts > 1000000);
      final framesInWindow = _recentFrameTimestamps.length;

      // 低活跃判定（即空闲）：1 秒窗口内帧数 ≤ 阈值即视为"无持续动画渲染"。
      // 无动画时 Flutter 引擎不产帧，唯一帧源是监控 UI 自身每 500ms 的周期
      // 重绘（约 2fps）；真实动画即使掉帧，帧请求仍按 vsync 持续产生，帧率
      // 几乎不可能掉到该阈值以下。因此仅凭窗口帧数即可区分「静止」与「卡顿」，
      // 不参考单帧耗时——开发（debug/模拟器）模式下一次简单重绘整帧耗时常常
      // 就超过 16ms，若以耗时为条件会把静止页面重新误报成低 FPS 告警。
      // Low-activity (idle) detection: ≤ threshold frames in the 1s window means
      // no continuous animation is rendered. A still page only ever renders the
      // monitor's own ~2fps periodic rebuilds; real animations keep requesting
      // frames every vsync even while janking, so their FPS stays far above this
      // floor. Frame duration is intentionally NOT consulted — a trivial
      // debug/emulator rebuild routinely exceeds 16ms, which would re-flag a
      // static page as low-FPS jank.
      if (framesInWindow <= _lowActivityFrameThreshold) {
        _isIdle = true;
        _currentFps = _lastActiveFps > 0 ? _lastActiveFps : _displayRefreshRate;
      } else {
        _isIdle = false;
        // FPS = 最近 1 秒内的帧数 / FPS = frames in the most recent second
        _currentFps = framesInWindow.toDouble();
        _lastActiveFps = _currentFps;

        // 仅活跃渲染时检测 FPS 告警；空闲不告警。
        // Only check FPS alerts while actively rendering; idle produces no alert.
        AlertService.instance.checkFps(_currentFps);
      }
    }

    // 记录 FPS 历史 / Record FPS history
    _fpsHistory.add(_currentFps);
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
