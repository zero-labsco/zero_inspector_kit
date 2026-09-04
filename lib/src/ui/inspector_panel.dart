import 'package:flutter/material.dart';

import 'theme/inspector_theme.dart';
import '../services/fps_service.dart';
import '../services/memory_inspector_service.dart';
import 'network_viewer.dart';
import 'log_viewer.dart';
import 'database_viewer.dart';
import 'memory_viewer.dart';
import 'route_viewer.dart';
import 'fps_viewer.dart';
import 'alerts_viewer.dart';
import 'widget_tree_viewer.dart';
import 'widgets/inspector_error_boundary.dart';
import 'inspector_toast.dart';

import '../services/inspector_service.dart';
import '../services/ws_inspector_service.dart';
import '../services/export_service.dart';
import '../utils/device_info.dart';
import '../utils/formatters.dart';

/// 检查器面板 / Inspector panel
/// 包含网络、日志、数据库、内存、FPS、路由、告警、Widget 八个查看器
/// Contains eight viewers: network, logs, database, memory, FPS, routes, alerts, widgets
class InspectorPanel extends StatefulWidget {
  /// 关闭面板回调 / Close panel callback
  final VoidCallback onClose;

  const InspectorPanel({super.key, required this.onClose});

  @override
  State<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends State<InspectorPanel>
    with SingleTickerProviderStateMixin {
  /// 标签页控制器 / Tab controller
  late final TabController _tabController;

  /// 当前选中的 Tab 索引 / Currently selected tab index
  int _currentIndex = 0;

  /// 各个标签页的内容 / Contents of each tab
  /// 仅当前激活页会被挂载到组件树（其余只构造、不监听全局 notifier），
  /// 因此每次 notify 只重建当前页；代价是切换标签会重建对应页面、瞬时状态（搜索词/筛选）重置。
  /// Only the active page is mounted into the tree (others are only constructed, not
  /// listening to the global notifier), so each notify rebuilds just the current page.
  /// Trade-off: switching tabs rebuilds the page and resets its transient state.
  late final List<Widget> _pages = [
    InspectorErrorBoundary(
      label: 'Network',
      child: NetworkViewer(key: ValueKey('network')),
    ),
    InspectorErrorBoundary(
      label: 'Logs',
      child: LogViewer(key: ValueKey('logs')),
    ),
    InspectorErrorBoundary(
      label: 'Database',
      child: DatabaseViewer(key: ValueKey('database')),
    ),
    InspectorErrorBoundary(
      label: 'Memory',
      child: MemoryViewer(key: ValueKey('memory')),
    ),
    InspectorErrorBoundary(
      label: 'FPS',
      child: FpsViewer(key: ValueKey('fps')),
    ),
    InspectorErrorBoundary(
      label: 'Routes',
      child: RouteViewer(key: ValueKey('routes')),
    ),
    InspectorErrorBoundary(
      label: 'Alerts',
      child: AlertsViewer(key: ValueKey('alerts')),
    ),
    InspectorErrorBoundary(
      label: 'Widgets',
      child: WidgetTreeInspector(key: ValueKey('widgets')),
    ),
  ];

  /// 标签页标题 / Tab titles
  final List<String> _titles = const [
    'Network',
    'Logs',
    'Database',
    'Memory',
    'FPS',
    'Routes',
    'Alerts',
    'Widgets',
  ];

  /// 标签页图标 / Tab icons
  final List<IconData> _icons = const [
    Icons.http_rounded,
    Icons.article_rounded,
    Icons.storage_rounded,
    Icons.memory_rounded,
    Icons.speed_rounded,
    Icons.route_rounded,
    Icons.notifications_active_rounded,
    Icons.visibility_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _titles.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    FpsService.instance.addListener(_onMonitorChanged);
    MemoryInspectorService.instance.addListener(_onMonitorChanged);
    WsInspectorService.instance.addListener(_onMonitorChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    FpsService.instance.removeListener(_onMonitorChanged);
    MemoryInspectorService.instance.removeListener(_onMonitorChanged);
    WsInspectorService.instance.removeListener(_onMonitorChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// 监控开关变化 → 刷新头部状态行 / Monitor toggle → refresh header status row
  /// 仅在"已开启监控集合"真正变化时才重建面板，避免内存监控每 500ms 的数据
  /// 刷新（enabled 未变）持续重建整个面板、打断趋势图手势。
  /// Only rebuilds the panel when the set of active monitors actually changes,
  /// so the per-500ms data ticks (enabled unchanged) don't keep rebuilding the
  /// whole panel and interrupt trend-chart gestures.
  String? _lastActiveMonitors;
  void _onMonitorChanged() {
    final current = _activeMonitors.join(',');
    if (current == _lastActiveMonitors) return;
    _lastActiveMonitors = current;
    if (mounted) setState(() {});
  }

  /// 当前已开启的实时监控标签 / Currently active real-time monitor labels
  List<String> get _activeMonitors {
    final list = <String>[];
    if (FpsService.instance.isRunning) list.add('FPS');
    if (MemoryInspectorService.instance.isEnabled) list.add('Memory');
    if (WsInspectorService.instance.isEnabled) list.add('WebSocket');
    return list;
  }

  /// Tab 变化回调 / Tab change callback
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    setState(() {
      _currentIndex = _tabController.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: BorderRadius.circular(InspectorDimensions.panelRadius),
        border: Border.all(color: InspectorColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 24,
            offset: const Offset(0, 12),
            spreadRadius: -6,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(InspectorDimensions.panelRadius),
        // 透明 Material 祖先：面板作为浮层（Overlay）渲染，宿主不一定提供
        // Material，而搜索框(Switch/TextField 等)需要 Material 祖先，否则 debug
        // 模式会抛 "No Material widget found"。用透明 Material 既满足断言又不影响外观。
        // Transparent Material ancestor: the panel is rendered as an Overlay, so the
        // host may not provide a Material. Material widgets (TextField/Switch/…) need
        // one, else debug builds throw "No Material widget found". A transparent
        // Material satisfies the assertion without changing the appearance.
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                // 仅挂载当前激活的页面，避免非激活 viewer 也监听全局 notifier 造成叠加重建。
                // Only mount the active page so inactive viewers don't also listen to the
                // global notifier and pile up rebuilds on every notify.
                child: _pages[_currentIndex],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建面板头部 / Build panel header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(
          bottom: BorderSide(color: InspectorColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: InspectorColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.terminal_rounded,
              color: Colors.black87,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Zero Inspector Kit',
                  style: TextStyle(
                    color: InspectorColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  'Developer Tools',
                  style: TextStyle(
                    color: InspectorColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 3),
                _buildStatusRow(),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _shareBugReport(context),
            tooltip: 'Share bug report (device + memory + logs + network)',
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.bug_report_rounded,
                color: InspectorColors.textPrimary,
                size: 18,
              ),
            ),
          ),
          IconButton(
            onPressed: widget.onClose,
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.close_rounded,
                color: InspectorColors.textPrimary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建头部实时监控状态行 / Build header real-time monitor status row
  ///
  /// 显示当前已开启的监控（FPS / Memory），让用户直观知道开启了什么。
  /// Shows currently active monitors (FPS / Memory) so the user knows what's on.
  Widget _buildStatusRow() {
    final active = _activeMonitors;
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active.isEmpty
                ? InspectorColors.textSecondary
                : InspectorColors.success,
          ),
        ),
        const SizedBox(width: 6),
        // Expanded + 省略号：窄屏或系统大字号下文本过长时收缩并省略，
        // 避免状态行 Row 在右侧溢出（实测窄屏溢出 12px、大字号溢出 47px）。
        // Expanded + ellipsis: on narrow screens / large system fonts the text can
        // outgrow the row; shrink-and-ellipsize instead of overflowing on the right.
        Expanded(
          child: Text(
            active.isEmpty
                ? 'No live monitor'
                : 'Monitoring: ${active.join(' · ')}',
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  /// 一键生成并分享 Bug 报告（设备信息 + 当前内存 + 最近日志 + 最近网络）
  /// One-click generate & share a bug report.
  Future<void> _shareBugReport(BuildContext context) async {
    final messenger = Overlay.of(context, rootOverlay: true);
    final memory = MemoryInspectorService.instance;
    final memoryInfo = <String>[
      '=== Memory (current) ===',
      'Process RSS: ${InspectorFormatters.formatBytes(memory.currentProcessRss)}',
      'Heap Usage: ${InspectorFormatters.formatBytes(memory.currentHeapUsage)}',
      'Native memory: ${memory.isNativeSupported ? 'supported' : 'unsupported'}',
    ].join('\n');

    final deviceInfo = DeviceInfoUtil.toReportString(
      await DeviceInfoUtil.collect(),
    );
    final inspector = InspectorService.instance;

    await ExportService.instance.exportBugReportAndShare(
      deviceInfo: deviceInfo,
      memoryInfo: memoryInfo,
      logs: inspector.logEntries.toList(),
      requests: inspector.networkRequests.toList(),
      maskSensitive: true,
    );

    if (mounted) {
      InspectorToast.showOn(messenger, 'Bug report shared');
    }
  }

  /// 构建标签栏 / Build tab bar
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        border: Border(
          bottom: BorderSide(color: InspectorColors.border, width: 1),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        // 始终允许横向滚动：8 个带文字的标签页在窄屏或系统大字体下
        // 可能超出可用宽度，可滚动才能保证在所有设备/字号下都不溢出。
        // Always scrollable: with 8 labeled tabs and large system fonts the
        // row can overflow on some devices; scrolling keeps it safe everywhere.
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        indicator: BoxDecoration(
          color: InspectorColors.primary,
          borderRadius: BorderRadius.circular(InspectorDimensions.chipRadius),
        ),
        // 始终使用 tab 宽度作为指示器大小，确保选中指示器填满整个 Tab
        // Always use tab width as indicator size to ensure selection indicator fills the entire tab
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
        labelPadding: const EdgeInsets.symmetric(horizontal: 16),
        dividerColor: Colors.transparent,
        labelColor: InspectorColors.textPrimary,
        unselectedLabelColor: InspectorColors.textSecondary,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
        tabs: List.generate(_titles.length, (index) {
          // 不设固定 height：让 tab 高度随图标 + 文字（含系统大字体缩放）自适应，
          // 否则固定 44 会约束内容，在系统大字体下文字被压出底部导致
          // RenderFlex bottom overflow。这样在任意设备/字号下都安全。
          // No fixed height: the tab sizes to its icon + label (including system
          // font scaling). A fixed 44 would clip/overflow the label on large
          // system fonts, so letting it size automatically is safe everywhere.
          return Tab(icon: Icon(_icons[index], size: 18), text: _titles[index]);
        }),
      ),
    );
  }
}
