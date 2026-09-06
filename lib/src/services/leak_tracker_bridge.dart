import 'package:flutter/foundation.dart';

/// Flutter 官方泄漏追踪桥接（第二来源）/ Official Flutter leak-tracking bridge
///
/// 当前泄漏检测是自研的 [WeakReference] 四状态机方案。它有一个盲点：对象调用了
/// `dispose()` 但尚未被 GC 时，弱引用仍存活，会被判定为"疑似泄漏"（误报）。
/// 本服务额外桥接 Flutter foundation 的 [FlutterMemoryAllocations]（官方
/// leak_tracker 的数据源），把官方上报的 created/disposed 事件作为**第二来源**：
/// 只要官方上报了 disposed，即便弱引用仍存活也判定为已释放（等待 GC），
/// 从而显著降低误报。
/// The leak detector is our own [WeakReference] state machine. It has a blind
/// spot: an object whose `dispose()` ran but which is not yet GC'd still resolves
/// through the weak reference and is flagged as a suspected leak (false positive).
/// This service additionally bridges Flutter's [FlutterMemoryAllocations] (the data
/// source behind the official leak_tracker) as a **second source**: once the official
/// stream reports `disposed`, the object is treated as released (awaiting GC) even
/// if the weak reference still resolves — cutting false positives.
///
/// 说明：官方事件只覆盖会向 [FlutterMemoryAllocations] 上报的框架类型（如 Image /
/// Picture / Layer 等），不会覆盖普通业务对象，因此它是**补充**而非替代自研方案。
/// Note: official events only cover framework types that report to
/// [FlutterMemoryAllocations] (Image / Picture / Layer, …), not ordinary business
/// objects — so this supplements, rather than replaces, the custom detector.
class LeakTrackerBridge {
  LeakTrackerBridge._();

  /// 单例实例 / Singleton instance
  static final LeakTrackerBridge instance = LeakTrackerBridge._();

  /// 事件集合上限（环形，超出丢弃最旧的）/ Event-set cap (ring; oldest dropped)
  static const int _maxTracked = 2000;

  /// 官方上报的 created 对象身份哈希 / identityHashCode of created objects
  final Set<int> _created = {};

  /// 官方上报的 disposed 对象身份哈希 / identityHashCode of disposed objects
  final Set<int> _disposed = {};

  /// 订阅回调引用（用于取消订阅）/ Listener reference (for unsubscribe)
  late final ObjectEventListener _listener = _onEvent;

  /// 是否已启用 / Whether enabled
  bool _enabled = false;

  /// 是否可用（已启用且订阅成功）/ Whether usable (enabled and subscribed)
  bool get isEnabled => _enabled;

  /// 启用桥接：订阅 [FlutterMemoryAllocations] / Subscribe to official allocations
  ///
  /// 订阅失败（如官方开关关闭）时优雅降级，[isEnabled] 保持 false。
  /// Degrades gracefully when subscription fails (e.g. official toggle off);
  /// [isEnabled] stays false.
  void enable() {
    if (_enabled) return;
    try {
      FlutterMemoryAllocations.instance.addListener(_listener);
      _enabled = true;
    } catch (_) {
      _enabled = false;
    }
  }

  /// 关闭桥接并清理 / Disable and clean up
  void disable() {
    if (!_enabled) return;
    try {
      FlutterMemoryAllocations.instance.removeListener(_listener);
    } catch (_) {}
    _created.clear();
    _disposed.clear();
    _enabled = false;
  }

  /// 处理官方分配事件（单个回调同时接收 created / disposed）
  /// Handle official allocation events (one callback receives created & disposed)
  void _onEvent(ObjectEvent event) {
    final id = identityHashCode(event.object);
    if (event is ObjectDisposed) {
      _disposed.add(id);
      _created.remove(id);
    } else if (event is ObjectCreated) {
      _created.add(id);
      _disposed.remove(id);
    }
    _trim();
  }

  void _trim() {
    while (_created.length > _maxTracked) {
      _created.remove(_created.first);
    }
    while (_disposed.length > _maxTracked) {
      _disposed.remove(_disposed.first);
    }
  }

  /// 官方是否上报过该对象已 dispose / Whether the official source reported disposal
  bool hasDisposed(Object object) =>
      _enabled && _disposed.contains(identityHashCode(object));

  /// 官方是否上报过该对象已创建 / Whether the official source reported creation
  bool hasCreated(Object object) =>
      _enabled && _created.contains(identityHashCode(object));
}
