import 'package:flutter/material.dart';
import '../theme/inspector_theme.dart';

/// 检查器统一图标按钮 / Shared inspector icon button
///
/// 替换各 viewer 中重复的 `Tooltip` + `Material` + `InkWell` 图标按钮实现。
/// Replaces duplicated icon-button implementations across viewers.
class InspectorIconButton extends StatelessWidget {
  /// 图标 / Icon
  final IconData icon;

  /// 提示文案 / Tooltip
  final String tooltip;

  /// 点击回调 / Tap callback
  final VoidCallback onTap;

  /// 图标尺寸 / Icon size
  final double size;

  /// 图标颜色（默认 [InspectorColors.textSecondary]）/ Icon color
  final Color? color;

  /// 是否可用（不可用则变灰且不可点击）/ Enabled state
  final bool enabled;

  /// 是否处于激活状态（激活时用强调色高亮，用于视图切换等）/ Active state
  final bool active;

  const InspectorIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 18,
    this.color,
    this.enabled = true,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: active
                  ? InspectorColors.accent.withValues(alpha: 0.16)
                  : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: active
                  ? InspectorColors.accent
                  : (enabled
                        ? (color ?? InspectorColors.textSecondary)
                        : InspectorColors.textHint),
              size: size,
            ),
          ),
        ),
      ),
    );
  }
}
