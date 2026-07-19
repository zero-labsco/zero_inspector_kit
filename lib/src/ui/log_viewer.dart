import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/inspector_service.dart';
import 'theme/inspector_theme.dart';

/// 日志查看器 / Log viewer
/// 显示所有捕获的日志，支持按级别过滤 / Display all captured logs, support filtering by level
class LogViewer extends StatefulWidget {
  const LogViewer({super.key});

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  /// 当前过滤的日志级别 / Currently filtered log level
  LogLevel? _filterLevel;

  /// 所有日志级别 / All log levels
  final List<LogLevel> _levels = LogLevel.values;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        _buildFilterBar(),
        Expanded(
          child: ListenableBuilder(
            listenable: InspectorService.instance,
            builder: (context, child) {
              final logs = InspectorService.instance.logEntries;
              final filteredLogs = _filterLevel != null
                  ? logs.where((e) => e.level == _filterLevel).toList()
                  : logs;

              return ListView.builder(
                itemCount: filteredLogs.length,
                itemBuilder: (context, index) =>
                    _buildLogItem(filteredLogs[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 构建工具栏 / Build toolbar
  Widget _buildToolbar() {
    return ListenableBuilder(
      listenable: InspectorService.instance,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: InspectorColors.surface,
            border: Border(bottom: BorderSide(color: InspectorColors.border)),
          ),
          child: Row(
            children: [
              _buildCountBadge(
                '${InspectorService.instance.logEntries.length}',
              ),
              const SizedBox(width: 8),
              Text(
                'Logs',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _buildIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Clear',
                onTap: () => InspectorService.instance.clearLogs(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建计数胶囊徽章 / Build count pill badge
  Widget _buildCountBadge(String text) {
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
      ),
    );
  }

  /// 构建图标按钮 / Build icon button
  Widget _buildIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(6),
            child: Icon(icon, color: InspectorColors.textSecondary, size: 18),
          ),
        ),
      ),
    );
  }

  /// 构建过滤栏 / Build filter bar
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(bottom: BorderSide(color: InspectorColors.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(null, 'All', Icons.filter_list_rounded),
            ..._levels.map(
              (level) => _buildFilterChip(
                level,
                _getLevelText(level),
                _getLevelIcon(level),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取日志级别图标 / Get log level icon
  IconData _getLevelIcon(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return Icons.more_horiz_rounded;
      case LogLevel.debug:
        return Icons.bug_report_rounded;
      case LogLevel.info:
        return Icons.info_outline_rounded;
      case LogLevel.warning:
        return Icons.warning_amber_rounded;
      case LogLevel.error:
        return Icons.error_outline_rounded;
    }
  }

  /// 获取日志级别缩写文本 / Get log level abbreviation text
  String _getLevelText(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return 'V';
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }

  /// 构建过滤标签 / Build filter chip
  Widget _buildFilterChip(LogLevel? level, String label, IconData icon) {
    final isSelected = _filterLevel == level;
    final color = level != null
        ? _getLevelColor(level)
        : InspectorColors.accent;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(InspectorDimensions.chipRadius),
          onTap: () => setState(() => _filterLevel = level),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.2)
                  : InspectorColors.card,
              borderRadius: BorderRadius.circular(
                InspectorDimensions.chipRadius,
              ),
              border: Border.all(
                color: isSelected
                    ? color.withValues(alpha: 0.5)
                    : InspectorColors.border,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: isSelected ? color : InspectorColors.textSecondary,
                ),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isSelected ? color : InspectorColors.textSecondary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建单个日志项 / Build single log item
  Widget _buildLogItem(LogEntry entry) {
    final levelColor = _getLevelColor(entry.level);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: entry.level == LogLevel.error
            ? InspectorColors.error.withValues(alpha: 0.05)
            : entry.level == LogLevel.warning
            ? InspectorColors.warning.withValues(alpha: 0.05)
            : Colors.transparent,
        border: Border(
          left: BorderSide(color: levelColor, width: 3),
          bottom: BorderSide(color: InspectorColors.divider, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  entry.levelText,
                  style: TextStyle(
                    color: levelColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry.timestampText,
                style: TextStyle(
                  color: InspectorColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              if (entry.tag != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: InspectorColors.border,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.tag!,
                    style: TextStyle(
                      color: InspectorColors.accent,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.message,
            style: TextStyle(
              color: entry.level == LogLevel.error
                  ? InspectorColors.logErrorText
                  : entry.level == LogLevel.warning
                  ? InspectorColors.logWarningText
                  : InspectorColors.textPrimary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// 根据日志级别获取颜色 / Get color by log level
  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.verbose:
        return InspectorColors.logVerbose;
      case LogLevel.debug:
        return InspectorColors.logDebug;
      case LogLevel.info:
        return InspectorColors.logInfo;
      case LogLevel.warning:
        return InspectorColors.logWarning;
      case LogLevel.error:
        return InspectorColors.logError;
    }
  }
}
