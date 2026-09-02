import 'package:flutter/foundation.dart';

/// Widget 树检查器开关服务 / Widget tree inspector toggle service.
///
/// 与 [MemoryInspectorService] 一样，Widget 树默认**关闭**，需在面板顶部手动
/// 开启。开启后才构建并展示当前渲染树快照，避免无谓的 Element 遍历开销。
///
/// Like [MemoryInspectorService], the widget tree is **disabled by default** and
/// must be turned on in the panel. Only then is the element tree walked and
/// rendered, avoiding unnecessary traversal overhead.
///
/// ```dart
/// WidgetTreeService.instance.isEnabled = true;
/// ```
class WidgetTreeService extends ChangeNotifier {
  WidgetTreeService._();

  /// 单例实例 / Singleton instance
  static final WidgetTreeService instance = WidgetTreeService._();

  /// 是否启用 Widget 树检查 / Whether the widget tree inspector is enabled
  // 默认开启：Widget Inspector 为快照式、不影响运行时性能，无需用户开关。
  // On by default: the widget inspector is snapshot-based and has no runtime
  // performance cost, so it doesn't need a user toggle.
  bool _isEnabled = true;

  /// 获取是否启用 Widget 树检查 / Get whether the widget tree inspector is enabled
  bool get isEnabled => _isEnabled;

  /// 设置是否启用 Widget 树检查 / Set whether the widget tree inspector is enabled
  set isEnabled(bool value) {
    if (_isEnabled == value) return;
    _isEnabled = value;
    notifyListeners();
  }
}
