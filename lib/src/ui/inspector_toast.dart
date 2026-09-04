import 'package:flutter/material.dart';

/// 插件内统一提示（toast）组件。
///
/// 所有面板内的反馈（复制 / 导出 / 分享 / 重放 / bug report 等）都通过
/// [InspectorToast.show] 触发，集中控制样式，避免各处重复创建 [SnackBar]。
///
/// 因为面板挂载处会提供自己的 [ScaffoldMessenger]（见
/// `_InspectorAppWrapper._buildPanelContent`），这里的提示会被渲染进面板
/// 所在的那一层 Overlay、且位于面板之上，不会被面板本身遮挡。
///
/// Centralized toast for all in-panel feedback. Wrapping it in one component
/// keeps styling consistent and guarantees the prompt renders above the panel
/// (the panel host supplies its own ScaffoldMessenger).
class InspectorToast {
  const InspectorToast._();

  /// 在 [context] 所属的最近 [ScaffoldMessenger] 上弹出一个提示。
  /// Show a toast on the nearest ScaffoldMessenger above [context].
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.down,
        action: action,
      ),
    );
  }

  /// 在指定的 [ScaffoldMessengerState] 上弹出提示。
  ///
  /// 适用于 `await` 之后需要弹提示的场景：先在异步间隙之前用
  /// `ScaffoldMessenger.of(context)` 解析出 [ScaffoldMessengerState] 保存下来，
  /// 再传给本方法，即可避免 `use_build_context_synchronously` 告警
  /// （不再跨异步间隙使用 [BuildContext]）。
  ///
  /// Show a toast on a pre-resolved [ScaffoldMessengerState]. Use this inside an
  /// async gap: resolve `ScaffoldMessenger.of(context)` *before* the await and
  /// pass the state here, so no [BuildContext] crosses the async boundary.
  static void showOn(
    ScaffoldMessengerState messenger,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        dismissDirection: DismissDirection.down,
        action: action,
      ),
    );
  }
}
