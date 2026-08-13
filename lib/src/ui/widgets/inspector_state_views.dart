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

/// 功能关闭占位 / Disabled-feature placeholder
///
/// 在 viewer 顶部总开关关闭时使用，配合 [InspectorSwitchCard] 告知用户开启后的行为。
/// Shown when a viewer's master switch is off; pairs with [InspectorSwitchCard].
class InspectorDisabledState extends StatelessWidget {
  /// 标题 / Title
  final String title;

  /// 说明文案 / Hint message
  final String message;

  /// 图标 / Icon
  final IconData icon;

  const InspectorDisabledState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.sensors_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: InspectorColors.textHint),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: InspectorColors.textHint,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

/// 通用顶部总开关卡片 / Generic top master-switch card
///
/// 与 Memory 监控一致：功能默认关闭，开启后才采集/渲染数据，避免无谓开销。
/// Same pattern as Memory monitoring: feature is off by default; enabling turns
/// on data collection/rendering to avoid needless overhead.
///
/// [title] 功能名 / feature name
/// [subtitleEnabled]/[subtitleDisabled] 开关两侧说明 / on/off captions
/// [icon] 图标 / icon
/// [value] 当前开关状态 / current state
/// [onChanged] 切换回调 / toggle callback
class InspectorSwitchCard extends StatelessWidget {
  const InspectorSwitchCard({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitleEnabled = 'Enabled',
    this.subtitleDisabled = 'Disabled',
    this.icon = Icons.power_settings_new_rounded,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  final String subtitleEnabled;
  final String subtitleDisabled;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(
          color: value
              ? InspectorColors.success.withValues(alpha: 0.3)
              : InspectorColors.border,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            value ? icon : Icons.power_off_rounded,
            size: 18,
            color: value ? InspectorColors.success : InspectorColors.textHint,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: InspectorColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? subtitleEnabled : subtitleDisabled,
                  style: TextStyle(
                    color: value
                        ? InspectorColors.success
                        : InspectorColors.textHint,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: InspectorColors.success,
            activeTrackColor: InspectorColors.success.withValues(alpha: 0.3),
            inactiveThumbColor: InspectorColors.textHint,
            inactiveTrackColor: InspectorColors.border,
            onChanged: onChanged,
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
