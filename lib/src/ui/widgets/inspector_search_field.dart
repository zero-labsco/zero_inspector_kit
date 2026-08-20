import 'package:flutter/material.dart';

import '../theme/inspector_theme.dart';

/// 检查器搜索框 / Shared search field
///
/// 替换各 viewer 中重复的搜索输入框实现。
/// Replaces duplicated search-field implementations across viewers.
class InspectorSearchField extends StatelessWidget {
  /// 控制器 / Controller
  final TextEditingController controller;

  /// 提示文案 / Hint text
  final String hint;

  /// 清空回调 / Clear callback
  final VoidCallback onClear;

  /// 输入变化回调 / Input change callback
  final ValueChanged<String>? onChanged;

  const InspectorSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onClear,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: InspectorColors.textPrimary, fontSize: 12),
        onChanged: onChanged,
        decoration: InputDecoration(
          // 使用 collapsed 避免 Material 默认上下内边距，配合精确 contentPadding 垂直居中
          // Use collapsed to drop Material's default vertical padding; exact
          // contentPadding keeps the hint/text centered within the 32px box.
          isCollapsed: true,
          hintText: hint,
          hintStyle: TextStyle(color: InspectorColors.textHint, fontSize: 12),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 16,
            color: InspectorColors.textHint,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 28,
            minHeight: 32,
          ),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: InspectorColors.textHint,
                  ),
                  onPressed: onClear,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
        ),
      ),
    );
  }
}
