import 'dart:async';
import 'package:flutter/material.dart';

/// 插件内统一提示（toast）组件。
///
/// 所有面板内的反馈（复制 / 导出 / 分享 / 重放 / bug report 等）都通过
/// [InspectorToast.show] 触发，集中控制样式，避免各处重复创建 [SnackBar]。
///
/// 提示以悬浮卡片形式插入面板所在的根 [Overlay] 最上层，并锚定在屏幕
/// 顶部，因此始终位于面板之上、且不会被面板遮挡（普通的 [SnackBar]
/// 只能固定在底部，无法满足"置顶"需求）。
///
/// Centralized toast for all in-panel feedback. Wrapping it in one component
/// keeps styling consistent and guarantees the prompt renders above the panel.
/// It is a floating card inserted on top of the root [Overlay] and anchored to
/// the top of the screen (a plain [SnackBar] is always bottom-anchored).
class InspectorToast {
  const InspectorToast._();

  /// 在 [context] 所属的根 [Overlay] 顶部弹出一个置顶提示。
  /// Show a top-anchored toast on the root [Overlay] above [context].
  static void show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    _showOn(
      Overlay.of(context, rootOverlay: true),
      message,
      duration: duration,
      action: action,
    );
  }

  /// 在指定的 [OverlayState] 上弹出置顶提示。
  ///
  /// 适用于 `await` 之后需要弹提示的场景：先在异步间隙之前用
  /// `Overlay.of(context, rootOverlay: true)` 解析出 [OverlayState] 保存下来，
  /// 再传给本方法，即可避免 `use_build_context_synchronously` 告警
  /// （不再跨异步间隙使用 [BuildContext]）。
  ///
  /// Show a top-anchored toast on a pre-resolved [OverlayState]. Use this inside
  /// an async gap: resolve `Overlay.of(context, rootOverlay: true)` *before* the
  /// await and pass the state here, so no [BuildContext] crosses the async
  /// boundary.
  static void showOn(
    OverlayState overlay,
    String message, {
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    _showOn(overlay, message, duration: duration, action: action);
  }

  static void _showOn(
    OverlayState overlay,
    String message, {
    required Duration duration,
    SnackBarAction? action,
  }) {
    late final OverlayEntry entry;
    void remove() => entry.remove();
    entry = OverlayEntry(
      builder: (_) => _InspectorToastWidget(
        message: message,
        action: action,
        onDismiss: remove,
      ),
    );
    overlay.insert(entry);
    Timer(duration, remove);
  }
}

/// 置顶悬浮提示卡片 / Top-anchored floating toast card.
class _InspectorToastWidget extends StatelessWidget {
  final String message;
  final SnackBarAction? action;
  final VoidCallback onDismiss;

  const _InspectorToastWidget({
    required this.message,
    this.action,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: onDismiss,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                decoration: BoxDecoration(
                  color: colorScheme.inverseSurface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x40000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onInverseSurface,
                        ),
                      ),
                    ),
                    if (action != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          action!.onPressed();
                          onDismiss();
                        },
                        child: Text(action!.label),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
