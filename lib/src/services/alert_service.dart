import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/alert_event.dart';
import '../models/alert_rule.dart';
import '../models/network_request.dart';
import '../models/log_entry.dart';
import 'persistence_service.dart';

export '../models/alert_event.dart';

/// 告警服务 / Alert service
///
/// 在数据写入（网络/日志/内存/FPS）时被调用以检测是否命中规则。
/// 命中的告警以 [AlertEvent] 形式入队，并通过 [unreadCount] 暴露未读数，
/// 供悬浮球显示红点。告警列表有上限（环形缓冲），避免无限增长。
/// Invoked on data write to detect rule hits. Hit events are queued and exposed
/// via [unreadCount] for the floating button red dot. Bounded ring buffer.
class AlertService {
  AlertService._();

  /// 单例实例 / Singleton instance
  static final AlertService instance = AlertService._();

  /// 告警事件环形缓冲上限 / Alert event ring buffer cap
  static const int _maxEvents = 100;

  /// 同一来源的告警最小触发间隔（毫秒）/ Min interval between alerts from the same source (ms)
  ///
  /// 防止同一来源（如持续高位内存、慢请求）高频触发导致告警风暴。
  /// 设为 1 秒：内存/FPS 定时器周期 500ms 下同一来源至少 1 秒 1 条；
  /// 突发 5xx/慢请求在同一秒内只记 1 条，1 秒后再次出现仍会触发。
  /// Prevents alert storms from high-frequency checks on a single source
  /// (e.g. sustained high memory, a slow endpoint). 1s: at most one event
  /// per source per second; a new occurrence after the cooldown still fires.
  static const int _perSourceCooldownMs = 1000;

  /// 节流表硬上限 / Hard cap for the throttle table
  ///
  /// key 是 `(source, message)`，其中 source 多为完整 URL，长跑 App 里会单调
  /// 增长且永不淘汰 —— 这是本服务唯一的确定性内存泄漏。超过上限即按插入顺序
  /// 淘汰最旧的项。
  /// Keys are `(source, message)` where source is often a full URL, so the map
  /// grows monotonically and is never evicted — a deterministic leak. Past the
  /// cap, the oldest entries (insertion order) are dropped.
  static const int _maxThrottleEntries = 512;

  /// 节流表触发清扫的软阈值 / Soft threshold that triggers a sweep
  static const int _throttleSweepThreshold = 384;

  /// 已启用的规则（默认内置）/ Enabled rules (defaults built-in)
  final List<AlertRule> _rules = List.of(AlertRule.defaults);

  /// 告警事件缓冲 / Alert event buffer
  final ListQueue<AlertEvent> _events = ListQueue();

  /// 各来源上次触发时间（毫秒时间戳），用于节流同源重复告警
  /// Last fire time per (source, message) key (ms timestamp), used to
  /// throttle duplicate alerts. Keyed on a (source, message) record so a
  /// single request that hits multiple rules (e.g. 5xx + slow) still
  /// surfaces each distinct alert, and there is no string-collision risk
  /// when a URL contains the `|` separator.
  final Map<(String, String), int> _lastFiredAt = <(String, String), int>{};

  /// 未读告警数（供红点）/ Unread alert count (for red dot)
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  /// 规则列表只读视图 / Read-only rule list
  UnmodifiableListView<AlertRule> get rules => UnmodifiableListView(_rules);

  /// 告警事件只读视图（最新在前）/ Read-only event view (newest first)
  UnmodifiableListView<AlertEvent> get events => UnmodifiableListView(_events);

  /// 获取/设置规则 / Get/set rules
  void setRules(List<AlertRule> rules) {
    _rules
      ..clear()
      ..addAll(rules);
  }

  /// 新增一条规则 / Add a rule
  void addRule(AlertRule rule) => _rules.add(rule);

  /// 移除规则 / Remove a rule
  void removeRule(String id) => _rules.removeWhere((r) => r.id == id);

  /// 清空未读 / Clear unread
  void clearUnread() {
    if (unreadCount.value != 0) unreadCount.value = 0;
  }

  /// 清空全部告警 / Clear all alerts
  void clearAll() {
    _events.clear();
    _lastFiredAt.clear();
    unreadCount.value = 0;
  }

  /// 恢复持久化的告警事件（跨重启不丢）。
  /// Restore persisted alert events (survives restarts).
  ///
  /// 已存在相同 (source, message) 的事件会被跳过，避免重复计数。
  /// Events whose (source, message) already exist are skipped to avoid
  /// double counting.
  void restore(Iterable<AlertEvent> records) {
    for (final r in records) {
      final exists = _events.any(
        (e) => e.source == r.source && e.message == r.message,
      );
      if (exists) continue;
      _events.addLast(r);
    }
    while (_events.length > _maxEvents) {
      _events.removeLast();
    }
  }

  /// 检测网络请求是否命中规则 / Check a network request against rules
  void checkNetwork(NetworkRequest r) {
    for (final rule in _rules) {
      if (!rule.enabled || rule.kind != AlertKind.httpStatus) continue;
      if (r.statusCode != null && r.statusCode! >= rule.threshold) {
        _fire(r.url, 'HTTP ${r.statusCode} ${r.method}');
      }
    }
    for (final rule in _rules) {
      if (!rule.enabled || rule.kind != AlertKind.requestDuration) continue;
      if (r.duration != null && r.duration! >= rule.threshold) {
        _fire(r.url, 'Slow ${r.duration}ms ${r.method}');
      }
    }
  }

  /// 检测日志是否命中规则 / Check a log entry against rules
  void checkLog(LogEntry e) {
    for (final rule in _rules) {
      if (!rule.enabled || rule.kind != AlertKind.logLevel) continue;
      // ERROR=4, WTF=5 / LogLevel ordinal
      if (e.level.index >= rule.threshold) {
        _fire(e.tag ?? 'log', '${e.level.name}: ${e.message}');
      }
    }
  }

  /// 检测内存占用（MB）/ Check memory usage in MB
  void checkMemory(double mb) {
    for (final rule in _rules) {
      if (!rule.enabled || rule.kind != AlertKind.memoryMb) continue;
      if (mb >= rule.threshold) {
        _fire('memory', '${mb.toStringAsFixed(0)} MB used');
      }
    }
  }

  /// 检测 FPS / Check FPS
  void checkFps(double fps) {
    for (final rule in _rules) {
      if (!rule.enabled || rule.kind != AlertKind.fpsLow) continue;
      if (fps > 0 && fps < rule.threshold) {
        _fire('fps', 'FPS dropped to ${fps.toStringAsFixed(0)}');
      }
    }
  }

  /// 触发一条告警：入队并累加未读 / Fire an alert: enqueue and bump unread
  ///
  /// 同 (source, message) 在 [_perSourceCooldownMs] 毫秒内重复触发会被节流，
  /// 避免高频检查（如 500ms 内存/FPS 轮询、慢请求循环）淹没告警缓冲。
  /// Repeated firings for the same (source, message) within
  /// [_perSourceCooldownMs] are throttled to avoid alert storms.
  void _fire(String source, String message) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final key = (source, message);
    final last = _lastFiredAt[key];
    if (last != null && now - last < _perSourceCooldownMs) {
      return;
    }
    _lastFiredAt[key] = now;
    _trimThrottleTable(now);

    _events.addFirst(AlertEvent(source: source, message: message));
    while (_events.length > _maxEvents) {
      _events.removeLast();
    }
    unreadCount.value = unreadCount.value + 1;
    // 异步落盘（磁盘环形缓冲），崩溃后可在 Alerts 标签回看。
    // Async persist (disk ring buffer) so alerts survive a crash.
    PersistenceService.instance.enqueueAlert(
      AlertEvent(source: source, message: message),
    );
  }

  /// 裁剪节流表，防止无界增长 / Trim the throttle table so it cannot grow unbounded
  ///
  /// 两级策略 / Two-stage strategy:
  /// 1. 过期清扫：任何 `now - ts >= _perSourceCooldownMs` 的项都不再具备节流
  ///    能力（下次同 key 触发时必然放行），属于纯垃圾，可直接丢弃。
  ///    Sweep: any entry already past the cooldown can never throttle again
  ///    (the next fire for that key passes regardless), so it is garbage.
  /// 2. 硬上限：按插入顺序淘汰最旧项，兜住"极短时间内出现大量不同 URL"的场景。
  ///    Hard cap: evict oldest by insertion order as a backstop for a burst of
  ///    many distinct URLs within a short window.
  void _trimThrottleTable(int now) {
    if (_lastFiredAt.length > _throttleSweepThreshold) {
      _lastFiredAt.removeWhere((_, ts) => now - ts >= _perSourceCooldownMs);
    }
    final overflow = _lastFiredAt.length - _maxThrottleEntries;
    if (overflow <= 0) return;
    final keys = _lastFiredAt.keys.take(overflow).toList();
    for (final k in keys) {
      _lastFiredAt.remove(k);
    }
  }
}
