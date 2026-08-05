import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../models/alert_rule.dart';
import '../models/network_request.dart';
import '../models/log_entry.dart';

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

    _events.addFirst(AlertEvent(source: source, message: message));
    while (_events.length > _maxEvents) {
      _events.removeLast();
    }
    unreadCount.value = unreadCount.value + 1;
  }
}

/// 告警事件 / Alert event
class AlertEvent {
  /// 来源（url / memory / fps / log）/ Source
  final String source;

  /// 描述 / Description
  final String message;

  /// 触发时间 / Timestamp
  final DateTime time;

  AlertEvent({required this.source, required this.message})
    : time = DateTime.now();
}
