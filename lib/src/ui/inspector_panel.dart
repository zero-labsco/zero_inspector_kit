import 'package:flutter/material.dart';
import '../models/log_entry.dart';
import '../services/inspector_service.dart';
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

class _InspectorPanelState extends State<InspectorPanel> {
  /// 当前选中的标签页索引 / Currently selected tab index
  int _selectedIndex = 0;

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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: const Color(0xFF1a1a2e),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }

  /// 构建面板头部 / Build panel header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF16213e),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bug_report, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          const Text(
            'Zero Inspector Kit',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: widget.onClose,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  /// 构建标签栏 / Build tab bar
  Widget _buildTabBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF2d2d44)),
        ),
      ),
      child: Row(
        children: List.generate(_titles.length, (index) {
          return Expanded(
            child: _buildTab(index),
          );
        }),
      ),
    );
  }

  /// 构建单个标签 / Build single tab
  Widget _buildTab(int index) {
    final isSelected = _selectedIndex == index;
    final count = _getCount(index);

    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: isSelected
            ? const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.blueAccent, width: 2),
                ),
              )
            : null,
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _titles[index],
                style: TextStyle(
                  color: isSelected ? Colors.blueAccent : Colors.grey,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 获取标签页的计数（错误数量等）/ Get tab count (error count, etc.)
  int _getCount(int index) {
    final service = InspectorService.instance;
    switch (index) {
      case 0:
        return service.networkRequests.length;
      case 1:
        return service.logEntries.where((e) => e.level == LogLevel.error).length;
      case 2:
        return 0;
      case 3:
        return service.routeEntries.length;
      default:
        return 0;
    }
  }
}