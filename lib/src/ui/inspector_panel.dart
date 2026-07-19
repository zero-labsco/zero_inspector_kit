import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/inspector_service.dart';
import 'theme/inspector_theme.dart';
import 'network_viewer.dart';
import 'log_viewer.dart';
import 'database_viewer.dart';
import 'route_viewer.dart';

/// 检查器面板 / Inspector panel
/// 包含网络请求、日志、数据库、路由四个查看器 / Contains four viewers: network requests, logs, database, routes
class InspectorPanel extends StatefulWidget {
  /// 关闭面板回调 / Close panel callback
  final VoidCallback onClose;

  const InspectorPanel({
    super.key,
    required this.onClose,
  });

  @override
  State<InspectorPanel> createState() => _InspectorPanelState();
}

class _InspectorPanelState extends State<InspectorPanel>
    with SingleTickerProviderStateMixin {
  /// 当前选中的标签页索引 / Currently selected tab index
  int _selectedIndex = 0;

  /// 标签页控制器 / Tab controller
  late final TabController _tabController;

  /// 各个标签页的内容 / Contents of each tab
  final List<Widget> _pages = const [
    NetworkViewer(),
    LogViewer(),
    DatabaseViewer(),
    RouteViewer(),
  ];

  /// 标签页标题 / Tab titles
  final List<String> _titles = [
    'Network',
    'Logs',
    'Database',
    'Routes',
  ];

  /// 标签页图标 / Tab icons
  final List<IconData> _icons = [
    Icons.http_rounded,
    Icons.article_rounded,
    Icons.storage_rounded,
    Icons.route_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _titles.length,
      vsync: this,
    );
    _tabController.addListener(() {
      setState(() => _selectedIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.92,
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        gradient: InspectorGradients.background,
        borderRadius: BorderRadius.circular(InspectorDimensions.panelRadius),
        border: Border.all(
          color: InspectorColors.border,
          width: 1,
        ),
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
              child: TabBarView(
                controller: _tabController,
                children: _pages,
              ),
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
            child: Icon(Icons.bug_report_rounded,
                color: InspectorColors.textPrimary, size: 20),
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
              child: Icon(Icons.close_rounded,
                  color: InspectorColors.textPrimary, size: 18),
            ),
          ),
        ],
      ),
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
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: InspectorGradients.tabIndicator,
          borderRadius: BorderRadius.circular(InspectorDimensions.chipRadius),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
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
      ),
    );
  }
}
