import 'package:flutter/material.dart';

import '../models/timeline_event.dart';
import '../services/alert_service.dart';
import '../services/error_service.dart';
import '../services/inspector_service.dart';
import '../services/timeline_service.dart';
import 'theme/inspector_theme.dart';

/// 统一会话时间线查看器 / Unified session timeline viewer
///
/// 把网络 / 日志 / 异常 / 路由 / 告警按时间归并成一条流，并支持"聚焦某条事件
/// 前后 N 秒"——这是单个标签页无法回答的"前后上下文"问题。
/// Merges network / log / error / route / alert into one time-ordered stream and
/// lets you focus the ±N seconds around any event — the "what happened around
/// it?" question no single tab can answer.
///
/// 只在本页挂载时监听各 notifier（面板用 IndexedStack 只挂载当前页），
/// 未打开时零开销；数据仍归属各自服务，这里只做归并展示。
/// Listens to the notifiers only while mounted (the panel mounts just the
/// active page), so a closed tab costs nothing. Data still lives in its own
/// service; this view only merges it for display.
class TimelineViewer extends StatefulWidget {
  const TimelineViewer({super.key});

  @override
  State<TimelineViewer> createState() => _TimelineViewerState();
}

class _TimelineViewerState extends State<TimelineViewer> {
  /// 被隐藏的来源（默认全部显示）/ Hidden sources (all shown by default)
  final Set<TimelineEventKind> _hidden = <TimelineEventKind>{};

  /// 聚焦的锚点事件（为空表示普通倒序列表）/ Focused anchor (null = normal list)
  TimelineEvent? _anchor;

  /// 上下文窗口时长 / Context window length
  Duration _window = TimelineService.defaultContextWindow;

  /// 当前展开的事件 key / Currently expanded event key
  String? _expandedKey;

  /// 缓存的归并结果 / Cached merge result
  List<TimelineEvent> _events = const <TimelineEvent>[];

  /// 数据已变化，下次 build 需重新归并 / Data changed; re-merge on next build
  bool _dirty = true;

  @override
  void initState() {
    super.initState();
    InspectorService.instance.networkNotifier.addListener(_markDirty);
    InspectorService.instance.logNotifier.addListener(_markDirty);
    InspectorService.instance.routeNotifier.addListener(_markDirty);
    ErrorService.instance.addListener(_markDirty);
    // AlertService 不是 ChangeNotifier，未读数变化即为新告警入队的信号。
    // AlertService is not a ChangeNotifier; the unread count changes whenever a
    // new alert is queued.
    AlertService.instance.unreadCount.addListener(_markDirty);
  }

  @override
  void dispose() {
    InspectorService.instance.networkNotifier.removeListener(_markDirty);
    InspectorService.instance.logNotifier.removeListener(_markDirty);
    InspectorService.instance.routeNotifier.removeListener(_markDirty);
    ErrorService.instance.removeListener(_markDirty);
    AlertService.instance.unreadCount.removeListener(_markDirty);
    super.dispose();
  }

  void _markDirty() {
    if (!mounted) return;
    setState(() => _dirty = true);
  }

  /// 重新归并（仅在脏数据或筛选变化时）/ Re-merge (only when dirty or filters changed)
  ///
  /// 短路条件只看 `_dirty`：此前附加了 `_events.isNotEmpty`，导致归并结果为空
  /// 时每次 build 都重新全量归并（空会话 / 全来源被隐藏的常见场景）。
  /// The short-circuit checks `_dirty` only: the old `&& _events.isNotEmpty`
  /// clause re-merged on every build whenever the result was empty (the common
  /// case for an empty session or all sources hidden).
  List<TimelineEvent> _computeEvents() {
    if (!_dirty) return _events;
    final kinds = TimelineEventKind.values
        .where((k) => !_hidden.contains(k))
        .toSet();
    _events = _anchor == null
        ? TimelineService.instance.build(kinds: kinds)
        : TimelineService.instance.contextAround(
            _anchor!,
            window: _window,
            kinds: kinds,
          );
    _dirty = false;
    return _events;
  }

  @override
  Widget build(BuildContext context) {
    final events = _computeEvents();

    return Container(
      color: InspectorColors.surface,
      child: Column(
        children: [
          _buildToolbar(events.length),
          if (_anchor != null) _buildContextBar(),
          Expanded(child: events.isEmpty ? _buildEmpty() : _buildList(events)),
        ],
      ),
    );
  }

  /// 构建工具栏（来源筛选 + 计数 + 复位）/ Build toolbar (source filter + count + reset)
  Widget _buildToolbar(int count) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(
          bottom: BorderSide(color: InspectorColors.border, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.timeline_rounded,
                size: 14,
                color: InspectorColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _anchor == null ? 'Session timeline' : 'Focused context',
                  style: const TextStyle(
                    color: InspectorColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$count',
                style: TextStyle(
                  color: InspectorColors.textHint,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(width: 8),
              _buildActionChip(
                label: 'Reset',
                color: InspectorColors.warning,
                onTap: _resetAll,
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final kind in TimelineEventKind.values)
                  _buildKindChip(kind),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 构建上下文模式提示条 / Build the context-mode bar
  Widget _buildContextBar() {
    final anchor = _anchor!;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: InspectorColors.primary.withValues(alpha: 0.10),
        border: Border(
          bottom: BorderSide(color: InspectorColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.center_focus_weak_rounded,
            size: 14,
            color: InspectorColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '±${_window.inSeconds}s around ${anchor.timeText}',
              style: const TextStyle(
                color: InspectorColors.textSecondary,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          for (final seconds in const [5, 10, 30])
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: _buildActionChip(
                label: '${seconds}s',
                color: _window.inSeconds == seconds
                    ? InspectorColors.primary
                    : InspectorColors.textHint,
                onTap: () => setState(() {
                  _window = Duration(seconds: seconds);
                  _dirty = true;
                }),
              ),
            ),
          IconButton(
            onPressed: () => setState(() {
              _anchor = null;
              _dirty = true;
            }),
            icon: Icon(
              Icons.close_rounded,
              size: 16,
              color: InspectorColors.textSecondary,
            ),
            tooltip: 'Exit context',
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(6),
          ),
        ],
      ),
    );
  }

  /// 构建来源筛选 chip / Build a source filter chip
  Widget _buildKindChip(TimelineEventKind kind) {
    final enabled = !_hidden.contains(kind);
    final color = _kindColor(kind);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() {
          if (enabled) {
            _hidden.add(kind);
          } else {
            _hidden.remove(kind);
          }
          _dirty = true;
        }),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: enabled ? color.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(InspectorDimensions.chipRadius),
            border: Border.all(
              color: enabled
                  ? color.withValues(alpha: 0.5)
                  : InspectorColors.border,
              width: 0.5,
            ),
          ),
          child: Text(
            kind.label,
            style: TextStyle(
              color: enabled ? color : InspectorColors.textHint,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ),
    );
  }

  /// 构建通用动作 chip / Build a generic action chip
  Widget _buildActionChip({
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(InspectorDimensions.chipRadius),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// 构建事件列表 / Build the event list
  Widget _buildList(List<TimelineEvent> events) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: events.length,
      itemBuilder: (context, index) => _buildRow(events[index]),
    );
  }

  /// 构建单条事件行 / Build a single event row
  Widget _buildRow(TimelineEvent event) {
    final color = _kindColor(event.kind);
    final expanded = _expandedKey == event.key;
    final isAnchor = _anchor?.key == event.key;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        // 圆角要求边框四边同色；左侧 kind 色条改为卡片内竖条实现。
        // Uniform border color is required with borderRadius; the left kind
        // accent is drawn as an inner bar below instead.
        border: Border.all(
          color: isAnchor
              ? InspectorColors.primary.withValues(alpha: 0.6)
              : InspectorColors.border,
          width: isAnchor ? 1.0 : 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
          onTap: () => setState(() {
            _expandedKey = expanded ? null : event.key;
          }),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            // Stack 而非 Row：Row + CrossAxisAlignment.stretch + Expanded 在 ListView
            // 的无限高约束下会算出无限高度并崩溃。用 Stack 让卡片高度由内容决定，
            // 竖条以 Positioned(top/bottom:0) 拉伸到该高度。
            // Stack instead of Row: a Row with stretch + Expanded resolves to
            // infinite height under ListView's unbounded vertical constraint and
            // crashes. With Stack the card height is driven by content, and the
            // bar stretches via Positioned(top/bottom:0).
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            event.timeText,
                            style: const TextStyle(
                              color: InspectorColors.textHint,
                              fontSize: 10,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              event.kind.label,
                              style: TextStyle(
                                color: color,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              event.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: InspectorColors.textPrimary,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (event.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: InspectorColors.textSecondary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      if (expanded) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: InspectorColors.surface,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                              color: InspectorColors.border,
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            event.detail,
                            maxLines: 10,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: InspectorColors.textSecondary,
                              fontSize: 10,
                              height: 1.4,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: _buildActionChip(
                            label: 'Focus ±${_window.inSeconds}s',
                            color: InspectorColors.primary,
                            onTap: () => setState(() {
                              _anchor = event;
                              _dirty = true;
                            }),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建空态 / Build the empty state
  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timeline_rounded,
            size: 40,
            color: InspectorColors.textHint,
          ),
          const SizedBox(height: 8),
          Text(
            _hidden.length == TimelineEventKind.values.length
                ? 'All sources hidden'
                : 'No events captured yet',
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Network · logs · errors · routes · alerts\nappear here in one time order.',
            textAlign: TextAlign.center,
            style: TextStyle(color: InspectorColors.textHint, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// 复位全部筛选与聚焦 / Reset all filters and focus
  void _resetAll() {
    setState(() {
      _hidden.clear();
      _anchor = null;
      _expandedKey = null;
      _window = TimelineService.defaultContextWindow;
      _dirty = true;
    });
  }

  /// 各类来源的标识色 / Identifying color per source kind
  Color _kindColor(TimelineEventKind kind) {
    switch (kind) {
      case TimelineEventKind.network:
        return InspectorColors.info;
      case TimelineEventKind.log:
        return InspectorColors.success;
      case TimelineEventKind.error:
        return InspectorColors.error;
      case TimelineEventKind.route:
        return InspectorColors.methodPut;
      case TimelineEventKind.alert:
        return InspectorColors.warning;
    }
  }
}
