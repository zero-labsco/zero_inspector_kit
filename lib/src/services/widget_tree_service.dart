import 'package:flutter/foundation.dart';

/// Widget 树检查器开关服务 / Widget tree inspector toggle service.
///
/// 与 [MemoryInspectorService]（默认关闭、需手动开启）**不同**：Widget 树检查
/// 默认**开启**。它是快照式的，只在打开面板时才遍历 Element 树，不影响运行时
/// 性能，因此不需要用户先手动打开；`init(enableWidgetInspector: false)` 可将
/// 其关掉（此前该参数只会在 true 时赋值，传 false 完全无效）。
///
/// Unlike [MemoryInspectorService] (off by default, manual enable): the widget
/// tree inspector is **on by default**. It is snapshot-based and only walks the
/// element tree when the panel opens, so it has no runtime cost and needs no
/// manual toggle; `init(enableWidgetInspector: false)` turns it off (that flag
/// used to assign only when true, so passing false did nothing).
///
/// ```dart
/// WidgetTreeService.instance.isEnabled = false;
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
