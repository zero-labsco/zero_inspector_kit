import 'package:flutter/material.dart';
import 'dart:convert';

import '../models/log_entry.dart';
import '../services/inspector_service.dart';
import '../services/export_service.dart';
import 'theme/inspector_theme.dart';
import 'widgets/widgets.dart';
import 'inspector_toast.dart';

/// 日志查看器 / Log viewer
/// 显示所有捕获的日志，支持按级别/标签过滤、正则搜索、自动滚动与单条复制。
/// Display all captured logs with level/tag filtering, regex search,
/// auto-scroll and per-entry copy.
class LogViewer extends StatefulWidget {
  const LogViewer({super.key});

  @override
  State<LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<LogViewer> {
  /// 当前过滤的日志级别 / Currently filtered log level
  LogLevel? _filterLevel;

  /// 当前过滤的标签（null 表示不限）/ Currently filtered tag (null = any)
  String? _filterTag;

  /// tag 下拉面板是否在 view 内展开 / Whether the in-view tag dropdown is open
  bool _tagDropdownOpen = false;

  /// 搜索关键词 / Search keyword
  String _searchKeyword = '';

  /// 是否使用正则搜索 / Whether regex search is enabled
  bool _useRegex = false;

  /// 编译后的正则（无效时为 null）/ Compiled regex (null when invalid)
  RegExp? _regex;

  /// 正则是否无效 / Whether the current regex is invalid
  bool _regexInvalid = false;

  /// 自动滚动到最新 / Auto-scroll to latest
  bool _autoScroll = true;

  /// 搜索控制器 / Search controller
  final TextEditingController _searchController = TextEditingController();

  /// 列表滚动控制器 / Scroll controller
  final ScrollController _scrollController = ScrollController();

  /// 所有日志级别 / All log levels
  final List<LogLevel> _levels = LogLevel.values;

  /// 当前选中的日志 id；非空时进入详情页（类似 Network 查看器）。
  /// Selected log id; non-null means we're in the detail view (like Network).
  String? _selectedLogId;

  /// 从实时列表中解析当前选中的日志；找不到（已被淘汰）时返回 null。
  /// Resolves the selected log from the live list; null if evicted.
  LogEntry? get _selectedLog {
    if (_selectedLogId == null) return null;
    final list = InspectorService.instance.logEntries;
    for (final e in list) {
      if (e.id == _selectedLogId) return e;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    InspectorService.instance.addListener(_onServiceChanged);
  }

  @override
  void dispose() {
    InspectorService.instance.removeListener(_onServiceChanged);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// 监听服务变化，在自动滚动开启时跳到最新（列表顶部）/ React to new logs
  void _onServiceChanged() {
    if (!_autoScroll || !_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedLog;
    // 计算 filter bar 底部偏移，下拉面板紧随其下方弹出。
    // Compute the filter bar's bottom offset so the panel drops right below it.
    var panelTop = 44.0;
    if (_tagDropdownOpen) {
      final bar = _filterBarKey.currentContext?.findRenderObject();
      if (bar is RenderBox) {
        final selfBox = context.findRenderObject();
        if (selfBox is RenderBox) {
          final barY = bar.localToGlobal(Offset.zero).dy;
          final selfY = selfBox.localToGlobal(Offset.zero).dy;
          panelTop = barY - selfY + bar.size.height;
        }
      }
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          children: [
            _buildToolbar(),
            // 详情页隐藏搜索栏与过滤栏 / Detail view hides the search & filter bars
            if (selected == null) _buildSearchBar(),
            if (selected == null) _buildFilterBar(),
            Expanded(
              child: ListenableBuilder(
                listenable: InspectorService.instance,
                builder: (context, child) {
                  if (selected != null) {
                    return _buildLogDetail(context, selected);
                  }

                  final logs = _filterLogs(
                    InspectorService.instance.logEntries,
                  );

                  if (logs.isEmpty) {
                    return InspectorEmptyState(
                      message:
                          _searchKeyword.isEmpty &&
                              _filterLevel == null &&
                              _filterTag == null
                          ? 'No logs yet'
                          : 'No matching logs',
                      icon: Icons.subject_rounded,
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: logs.length,
                    itemBuilder: (context, index) => _buildLogItem(logs[index]),
                  );
                },
              ),
            ),
          ],
        ),
        // 下拉面板：覆盖整个视图的蒙层 + 自绘面板，避免背景穿透点击。
        // Dropdown: a full-view modal barrier plus the self-drawn panel so
        // taps behind it are blocked (no click-through).
        if (_tagDropdownOpen && _selectedLog == null)
          Positioned.fill(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _tagDropdownOpen = false),
                  behavior: HitTestBehavior.opaque,
                ),
                Positioned(
                  top: panelTop,
                  left: 12,
                  child: _buildTagDropdownPanel(
                    _availableTags(InspectorService.instance.logEntries),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // 过滤结果缓存：避免每次重建都全表扫描 + 正则匹配。
  // Filter cache: avoids a full scan + regex matching on every rebuild.
  // 失效条件 = 数据源引用变化 / 列表长度变化 / 任一过滤条件变化。
  List<LogEntry>? _filteredLogsCache;
  List<LogEntry>? _filteredLogsSource;
  int _filteredLogsLength = -1;
  LogLevel? _filteredLevel;
  String? _filteredTag;
  String _filteredKeyword = '';
  bool _filteredUseRegex = false;
  RegExp? _filteredRegex;

  /// 模糊/正则搜索 + 级别 + 标签过滤日志 / Filter logs
  List<LogEntry> _filterLogs(List<LogEntry> logs) {
    final filtersUnchanged =
        _filteredLevel == _filterLevel &&
        _filteredTag == _filterTag &&
        _filteredKeyword == _searchKeyword &&
        _filteredUseRegex == _useRegex &&
        identical(_filteredRegex, _regex);
    if (_filteredLogsCache != null &&
        identical(logs, _filteredLogsSource) &&
        logs.length == _filteredLogsLength &&
        filtersUnchanged) {
      return _filteredLogsCache!;
    }

    var result = logs;

    if (_filterLevel != null) {
      result = result.where((e) => e.level == _filterLevel).toList();
    }

    if (_filterTag != null) {
      result = result.where((e) => e.tag == _filterTag).toList();
    }

    if (_searchKeyword.isNotEmpty) {
      if (_useRegex) {
        // 正则模式下无效正则不匹配任何结果，避免崩溃。
        // In regex mode an invalid pattern matches nothing instead of crashing.
        if (_regexInvalid || _regex == null) {
          result = const <LogEntry>[];
        } else {
          result = result.where((e) {
            return _regex!.hasMatch(e.message) ||
                (e.tag != null && _regex!.hasMatch(e.tag!));
          }).toList();
        }
      } else {
        final keyword = _searchKeyword.toLowerCase();
        result = result.where((e) {
          return e.message.toLowerCase().contains(keyword) ||
              (e.tag != null && e.tag!.toLowerCase().contains(keyword));
        }).toList();
      }
    }

    _filteredLogsCache = result;
    _filteredLogsSource = logs;
    _filteredLogsLength = logs.length;
    _filteredLevel = _filterLevel;
    _filteredTag = _filterTag;
    _filteredKeyword = _searchKeyword;
    _filteredUseRegex = _useRegex;
    _filteredRegex = _regex;
    return result;
  }

  /// 当前日志中所有去重后的标签 / Distinct tags from current logs
  List<String> _availableTags(List<LogEntry> logs) {
    final tags = <String>{};
    for (final e in logs) {
      if (e.tag != null && e.tag!.isNotEmpty) tags.add(e.tag!);
    }
    return tags.toList()..sort();
  }

  /// 构建工具栏 / Build toolbar
  Widget _buildToolbar() {
    final selected = _selectedLog;
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
              if (selected != null)
                InspectorIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => setState(() => _selectedLogId = null),
                )
              else
                InspectorCountBadge(
                  '${InspectorService.instance.logEntries.length}',
                ),
              const SizedBox(width: 8),
              Text(
                selected != null ? 'Log Detail' : 'Logs',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (selected == null)
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    reverse: true,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        InspectorIconButton(
                          icon: _autoScroll
                              ? Icons.vertical_align_top_rounded
                              : Icons.pause_circle_outline_rounded,
                          tooltip: _autoScroll
                              ? 'Auto-scroll on'
                              : 'Auto-scroll paused',
                          active: _autoScroll,
                          onTap: () =>
                              setState(() => _autoScroll = !_autoScroll),
                        ),
                        InspectorIconButton(
                          icon: Icons.content_copy_rounded,
                          tooltip: 'Copy as JSON',
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final logs = _filterLogs(
                              InspectorService.instance.logEntries,
                            );
                            if (logs.isEmpty) return;
                            await ExportService.instance.copyLogs(logs);
                            if (mounted) {
                              InspectorToast.showOn(
                                messenger,
                                'Copied ${logs.length} logs as JSON',
                              );
                            }
                          },
                        ),
                        InspectorIconButton(
                          icon: Icons.share_rounded,
                          tooltip: 'Share as Text',
                          onTap: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final logs = _filterLogs(
                              InspectorService.instance.logEntries,
                            );
                            if (logs.isEmpty) return;
                            await ExportService.instance.exportLogsAndShare(
                              logs,
                              json: false,
                            );
                            if (mounted) {
                              InspectorToast.showOn(
                                messenger,
                                'Sharing ${logs.length} logs as Text',
                              );
                            }
                          },
                        ),
                        InspectorIconButton(
                          icon: Icons.delete_outline_rounded,
                          tooltip: 'Clear',
                          onTap: () => InspectorService.instance.clearLogs(),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建搜索栏 / Build search bar
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: InspectorSearchField(
              controller: _searchController,
              hint: _useRegex
                  ? 'Search with regex...'
                  : 'Search message, tag...',
              onChanged: _onSearchChanged,
              onClear: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => setState(() => _useRegex = !_useRegex),
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: _useRegex
                      ? InspectorColors.accent.withValues(alpha: 0.15)
                      : InspectorColors.card,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _useRegex
                        ? InspectorColors.accent.withValues(alpha: 0.5)
                        : InspectorColors.border,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.code_rounded,
                      size: 14,
                      color: _useRegex
                          ? InspectorColors.accent
                          : InspectorColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '. *',
                      style: TextStyle(
                        fontSize: 11,
                        color: _useRegex
                            ? InspectorColors.accent
                            : InspectorColors.textSecondary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 搜索输入变化：更新关键词或编译正则 / Handle search input
  void _onSearchChanged(String value) {
    setState(() {
      _searchKeyword = value;
      _regexInvalid = false;
      _regex = null;
      if (_useRegex && value.isNotEmpty) {
        try {
          _regex = RegExp(value, caseSensitive: false);
        } catch (_) {
          _regexInvalid = true;
        }
      }
    });
  }

  /// 过滤栏容器 key，用于让下拉面板精准跟随其下方弹出。
  /// Key for the filter bar, so the panel can anchor right below it.
  final GlobalKey _filterBarKey = GlobalKey();

  /// 构建过滤栏 / Build filter bar
  /// tag 筛选位于级别 chip 同一栏、且排在 All 之前。
  /// Tag filter shares the level row, placed before the "All" chip.
  Widget _buildFilterBar() {
    return ListenableBuilder(
      listenable: InspectorService.instance,
      builder: (context, child) {
        final tags = _availableTags(InspectorService.instance.logEntries);
        return Container(
          key: _filterBarKey,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: InspectorColors.surface,
            border: Border(bottom: BorderSide(color: InspectorColors.border)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                if (tags.isNotEmpty) ...[
                  _buildTagDropdown(tags),
                  const SizedBox(width: 6),
                ],
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
      },
    );
  }

  /// 构建标签下拉触发 chip / Build tag filter trigger chip
  Widget _buildTagDropdown(List<String> tags) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(InspectorDimensions.chipRadius),
        onTap: () => setState(() => _tagDropdownOpen = !_tagDropdownOpen),
        child: Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: _tagDropdownOpen || _filterTag != null
                ? InspectorColors.accent.withValues(alpha: 0.15)
                : InspectorColors.card,
            borderRadius: BorderRadius.circular(InspectorDimensions.chipRadius),
            border: Border.all(
              color: _tagDropdownOpen || _filterTag != null
                  ? InspectorColors.accent.withValues(alpha: 0.5)
                  : InspectorColors.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.local_offer_outlined,
                size: 13,
                color: _tagDropdownOpen || _filterTag != null
                    ? InspectorColors.accent
                    : InspectorColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _filterTag ?? 'Tag',
                style: TextStyle(
                  fontSize: 11.5,
                  color: _tagDropdownOpen || _filterTag != null
                      ? InspectorColors.accent
                      : InspectorColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(width: 2),
              Icon(
                _tagDropdownOpen
                    ? Icons.arrow_drop_up_rounded
                    : Icons.arrow_drop_down_rounded,
                size: 16,
                color: _tagDropdownOpen || _filterTag != null
                    ? InspectorColors.accent
                    : InspectorColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 自绘下拉面板（渲染在主视图内，不依赖 Navigator Overlay）
  /// In-view dropdown panel (renders inside the view, not the Navigator Overlay)
  Widget _buildTagDropdownPanel(List<String> tags) {
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(8),
      color: InspectorColors.surface,
      type: MaterialType.card,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: 240,
          minWidth: 140,
          maxWidth: 260,
        ),
        decoration: BoxDecoration(
          color: InspectorColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: InspectorColors.border, width: 0.5),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTagMenuItem(null, 'All tags'),
              ...tags.map((t) => _buildTagMenuItem(t, t)),
            ],
          ),
        ),
      ),
    );
  }

  /// 下拉面板中的单条 tag / A single tag item in the dropdown panel
  Widget _buildTagMenuItem(String? tag, String label) {
    final selected = _filterTag == tag;
    return InkWell(
      onTap: () => setState(() {
        _filterTag = tag;
        _tagDropdownOpen = false;
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: selected ? InspectorColors.accent.withValues(alpha: 0.12) : null,
        child: Row(
          children: [
            if (selected)
              Icon(Icons.check_rounded, size: 14, color: InspectorColors.accent)
            else
              const SizedBox(width: 14),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  color: selected
                      ? InspectorColors.accent
                      : InspectorColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
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
          onTap: () => setState(() {
            _filterLevel = level;
            _tagDropdownOpen = false;
          }),
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedLogId = entry.id),
        child: Container(
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
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
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      entry.timestampText,
                      style: TextStyle(
                        color: InspectorColors.textSecondary,
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (entry.tag != null) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
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
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  InspectorIconButton(
                    icon: Icons.copy_rounded,
                    tooltip: 'Copy this log',
                    size: 18,
                    onTap: () => _copySingle(entry),
                  ),
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
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 复制单条日志为 JSON / Copy a single log entry as JSON
  Future<void> _copySingle(LogEntry entry) async {
    await ExportService.instance.copyText(jsonEncode(entry.toJson()));
    if (mounted) {
      InspectorToast.show(context, 'Copied log as JSON');
    }
  }

  /// 根据日志级别获取颜色 / Get color by log level
  /// 复用文件级 _logLevelColor，避免重复实现 / Reuses file-level helper.
  Color _getLevelColor(LogLevel level) => _logLevelColor(level);
}

/// 日志详情（view 内切换，类似 Network 查看器）/ In-view log detail
Widget _buildLogDetail(BuildContext context, LogEntry entry) {
  final levelColor = _logLevelColor(entry.level);
  return SingleChildScrollView(
    padding: const EdgeInsets.all(16),
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
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                entry.timestamp.toString(),
                style: TextStyle(
                  color: InspectorColors.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InspectorIconButton(
              icon: Icons.copy_rounded,
              tooltip: 'Copy JSON',
              onTap: () async {
                await ExportService.instance.copyText(
                  jsonEncode(entry.toJson()),
                );
                if (context.mounted) {
                  InspectorToast.show(context, 'Copied log as JSON');
                }
              },
            ),
          ],
        ),
        if (entry.tag != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: InspectorColors.card,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: Text(
              entry.message,
              style: TextStyle(
                color: InspectorColors.textPrimary,
                fontSize: 12.5,
                height: 1.4,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// 根据日志级别获取颜色 / Get color by log level
Color _logLevelColor(LogLevel level) {
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
