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

/// 检查器面板 / Inspector panel
/// 包含网络、日志、数据库、内存、FPS、路由六个查看器 / Contains six viewers: network, logs, database, memory, FPS, routes
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
  /// 使用 IndexedStack + ValueKey 保持各页面状态 / Use IndexedStack + ValueKey to preserve state of each page
  late final List<Widget> _pages = const [
    NetworkViewer(key: ValueKey('network')),
    LogViewer(key: ValueKey('logs')),
    DatabaseViewer(key: ValueKey('database')),
    MemoryViewer(key: ValueKey('memory')),
    FpsViewer(key: ValueKey('fps')),
    RouteViewer(key: ValueKey('routes')),
    AlertsViewer(key: ValueKey('alerts')),
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
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _titles.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    FpsService.instance.addListener(_onMonitorChanged);
    MemoryInspectorService.instance.addListener(_onMonitorChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    FpsService.instance.removeListener(_onMonitorChanged);
    MemoryInspectorService.instance.removeListener(_onMonitorChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// 监控开关变化 → 刷新头部状态行 / Monitor toggle → refresh header status row
  void _onMonitorChanged() => setState(() {});

  /// 当前已开启的实时监控标签 / Currently active real-time monitor labels
  List<String> get _activeMonitors {
    final list = <String>[];
    if (FpsService.instance.isRunning) list.add('FPS');
    if (MemoryInspectorService.instance.isEnabled) list.add('Memory');
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
        gradient: InspectorGradients.background,
        borderRadius: BorderRadius.circular(InspectorDimensions.panelRadius),
        border: Border.all(color: InspectorColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 15),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(InspectorDimensions.panelRadius),
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              // IndexedStack 保持所有页面状态不丢失 / IndexedStack preserves state of all pages
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建面板头部 / Build panel header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        gradient: InspectorGradients.header,
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
              gradient: InspectorGradients.primary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: InspectorColors.primary.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.bug_report_rounded,
              color: InspectorColors.textPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Column(
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
          const Spacer(),
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
        Text(
          active.isEmpty ? 'No live monitor' : 'Monitoring: ${active.join(' · ')}',
          style: TextStyle(
            color: InspectorColors.textSecondary,
            fontSize: 10,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 6个Tab(图标+文字)在宽度小于480时需要滚动，否则均匀分布 / 6 tabs need scrolling when width < 480, otherwise evenly distributed
          final isScrollable = constraints.maxWidth < 480;
          return TabBar(
            controller: _tabController,
            isScrollable: isScrollable,
            tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
            indicator: BoxDecoration(
              gradient: InspectorGradients.tabIndicator,
              borderRadius: BorderRadius.circular(
                InspectorDimensions.chipRadius,
              ),
            ),
            // 始终使用 tab 宽度作为指示器大小，确保选中指示器填满整个 Tab
            // Always use tab width as indicator size to ensure selection indicator fills the entire tab
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
            labelPadding: isScrollable
                ? const EdgeInsets.symmetric(horizontal: 16)
                : null,
            dividerColor: Colors.transparent,
            labelColor: InspectorColors.textPrimary,
            unselectedLabelColor: InspectorColors.textSecondary,
            labelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
            tabs: List.generate(_titles.length, (index) {
              return Tab(
                icon: Icon(_icons[index], size: 18),
                text: _titles[index],
                height: 44,
              );
            }),
          );
        },
      ),
    );
  }
}
