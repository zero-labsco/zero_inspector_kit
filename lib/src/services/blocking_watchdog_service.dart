import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/blocking_event.dart';
import '../models/log_entry.dart';
import 'inspector_service.dart';

/// 主线程阻塞看门狗 / Main-thread blocking watchdog
///
/// FPS 监控只能看见"有帧产出"的卡顿：真正卡死时（长同步任务、锁等待、
/// 平台通道阻塞）引擎根本不产帧，FPS 反而显示为空闲。本服务用一个低频心跳
/// 定时器直接测量 UI isolate 的响应间隔，补上这块盲区。
/// FPS monitoring only sees jank that still produces frames. During a real
/// stall (long synchronous work, lock wait, blocked platform channel) the engine
/// produces no frames at all, and FPS reads as "idle". This service measures the
/// UI isolate's responsiveness directly with a low-frequency heartbeat, closing
/// that blind spot.
///
/// 心跳本身极轻（每 100ms 只做一次时间比较），默认关闭，由 FPS 页开关启动。
/// The heartbeat is extremely cheap (one time comparison per 100ms), off by
/// default, and started from the FPS tab switch.
class BlockingWatchdogService extends ChangeNotifier {
  BlockingWatchdogService._();

  /// 单例实例 / Singleton instance
  static final BlockingWatchdogService instance = BlockingWatchdogService._();

  /// 心跳间隔 / Heartbeat interval
  static const Duration tickInterval = Duration(milliseconds: 100);

  /// 默认阻塞判定阈值（毫秒）：心跳间隔的 3 倍，留足定时器抖动余量。
  /// Default blocking threshold (ms): 3× the tick interval, leaving room for
  /// normal timer jitter.
  static const int defaultThresholdMs = 300;

  /// 阻塞记录上限（环形）/ Blocking record cap (ring)
  static const int _maxEvents = 50;

  /// 每条阻塞附带的上下文日志条数 / Context logs attached per blocking event
  static const int _nearbyLogCount = 3;

  /// 心跳定时器 / Heartbeat timer
  Timer? _timer;

  /// 上一次心跳时刻 / Last heartbeat timestamp
  DateTime? _lastTick;

  /// 阻塞记录（最新在前）/ Blocking records (newest first)
  final ListQueue<BlockingEvent> _events = ListQueue<BlockingEvent>();

  /// 当前阻塞判定阈值（毫秒）/ Current blocking threshold (ms)
  int _thresholdMs = defaultThresholdMs;

  /// 是否在监听 / Whether watching
  bool get isRunning => _timer != null;

  /// 当前阻塞判定阈值（毫秒）/ Current blocking threshold (ms)
  int get thresholdMs => _thresholdMs;

  /// 阻塞记录只读视图（最新在前）/ Read-only blocking records (newest first)
  UnmodifiableListView<BlockingEvent> get events =>
      UnmodifiableListView(_events);

  /// 阻塞次数 / Blocking count
  int get eventCount => _events.length;

  /// 最长阻塞时长（毫秒）/ Longest blocking duration (ms)
  int get longestBlockingMs {
    var max = 0;
    for (final e in _events) {
      if (e.durationMs > max) max = e.durationMs;
    }
    return max;
  }

  /// 启动看门狗 / Start the watchdog
  ///
  /// [thresholdMs] 可覆盖判定阈值；已在运行时只更新阈值。
  /// [thresholdMs] overrides the threshold; when already running it just
  /// updates the threshold.
  void start({int? thresholdMs}) {
    if (thresholdMs != null && thresholdMs > 0) {
      _thresholdMs = thresholdMs;
    }
    if (_timer != null) {
      notifyListeners();
      return;
    }
    _lastTick = null;
    _timer = Timer.periodic(tickInterval, (_) => handleTick(DateTime.now()));
    notifyListeners();
  }

  /// 停止看门狗 / Stop the watchdog
  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastTick = null;
    notifyListeners();
  }

  /// 清空阻塞记录 / Clear blocking records
  void clear() {
    _events.clear();
    notifyListeners();
  }

  /// 处理一次心跳 / Handle one heartbeat
  ///
  /// 暴露给测试注入时间戳；定时器回调同样走这里。
  /// Exposed so tests can inject timestamps; the timer callback uses it too.
  @visibleForTesting
  void handleTick(DateTime now) {
    final last = _lastTick;
    _lastTick = now;
    if (last == null) return;

    final gapMs = now.difference(last).inMilliseconds;
    // 只关心"明显超过阈值"的间隔：debug 模式下定时器抖动常见，阈值已留 3 倍余量。
    // Only gaps clearly past the threshold matter: timer jitter is common in
    // debug, and the threshold already leaves a 3× margin.
    if (gapMs < _thresholdMs) return;

    _events.addFirst(
      BlockingEvent(
        startAt: last,
        endAt: now,
        durationMs: gapMs,
        nearbyLogs: _collectNearbyLogs(last, now),
      ),
    );
    while (_events.length > _maxEvents) {
      _events.removeLast();
    }
    notifyListeners();
  }

  /// 收集阻塞窗口附近的日志摘要 / Collect log summaries around the stall window
  ///
  /// 主线程阻塞时拿不到阻塞点的堆栈（定时器回调有自己的栈），因此退而记录
  /// 前后 1 秒内最近的几条日志 —— 实践中这比"知道卡了 800ms"有用得多。
  /// The blocking stack is unavailable (the timer callback has its own stack),
  /// so we record the nearest logs within ±1s instead — far more actionable than
  /// just knowing "it stalled for 800ms".
  List<String> _collectNearbyLogs(DateTime start, DateTime end) {
    try {
      final from = start.subtract(const Duration(seconds: 1));
      final to = end.add(const Duration(seconds: 1));
      final found = <String>[];
      for (final LogEntry log in InspectorService.instance.logEntries) {
        if (log.timestamp.isBefore(from)) break;
        if (!log.timestamp.isAfter(to)) {
          found.add(
            '${log.timestampText} ${log.levelText} ${_oneLine(log.message)}',
          );
          if (found.length >= _nearbyLogCount) break;
        }
      }
      return found;
    } catch (_) {
      return const <String>[];
    }
  }

  /// 取消息首行并压缩长度 / Take the first line and trim it down
  static String _oneLine(String message) {
    final line = message.split('\n').first.trim();
    return line.length <= 80 ? line : '${line.substring(0, 80)}…';
  }
}
