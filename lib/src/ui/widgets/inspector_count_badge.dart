import 'package:flutter/material.dart';
import '../theme/inspector_theme.dart';

/// 检查器计数胶囊徽章 / Shared count pill badge
///
/// 替换各 viewer 工具栏中重复的计数徽章实现。
/// Replaces duplicated count-badge implementations in viewer toolbars.
class InspectorCountBadge extends StatelessWidget {
  /// 显示文本 / Display text
  final String text;

  const InspectorCountBadge(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: InspectorColors.primary.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(InspectorDimensions.smallRadius),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: InspectorColors.accent,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
