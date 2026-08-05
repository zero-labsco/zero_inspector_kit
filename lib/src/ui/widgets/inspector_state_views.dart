import 'package:flutter/material.dart';
import '../theme/inspector_theme.dart';

/// 空状态占位 / Empty-state placeholder
///
/// 在各 viewer 无数据时使用，统一视觉风格。
/// Used by viewers when there is no data; keeps the visual style consistent.
class InspectorEmptyState extends StatelessWidget {
  /// 提示文案 / Hint text
  final String message;

  /// 图标 / Icon
  final IconData icon;

  const InspectorEmptyState({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: InspectorColors.textHint),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

/// 错误状态卡片 / Error-state card
///
/// 在各 viewer 加载/查询失败时显示，可附带重试按钮。
/// Shown by viewers when a load/query fails; optionally with a retry button.
class InspectorErrorState extends StatelessWidget {
  /// 错误标题 / Error title
  final String title;

  /// 错误详情 / Error detail
  final String? detail;

  /// 重试回调 / Retry callback
  final VoidCallback? onRetry;

  const InspectorErrorState({
    super.key,
    this.title = 'Something went wrong',
    this.detail,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InspectorColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(
          color: InspectorColors.error.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 16,
                color: InspectorColors.error,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: InspectorColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (detail != null) ...[
            const SizedBox(height: 8),
            Text(
              detail!,
              style: TextStyle(
                color: InspectorColors.textSecondary,
                fontSize: 11,
                fontFamily: 'monospace',
                height: 1.4,
              ),
            ),
          ],
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 14),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: InspectorColors.error.withValues(alpha: 0.15),
                foregroundColor: InspectorColors.error,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
