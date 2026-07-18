import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/route_entry.dart';
import '../services/inspector_service.dart';

/// 路由查看器 / Route viewer
/// 显示应用中的路由导航记录 / Display route navigation records in the app
class RouteViewer extends StatefulWidget {
  const RouteViewer({super.key});

  @override
  State<RouteViewer> createState() => _RouteViewerState();
}

class _RouteViewerState extends State<RouteViewer> {
  /// 当前选中的路由记录 / Currently selected route record
  RouteEntry? _selectedRoute;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: ListenableBuilder(
            listenable: InspectorService.instance,
            builder: (context, child) {
              final routes = InspectorService.instance.routeEntries;

              return Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: ListView.builder(
                      itemCount: routes.length,
                      itemBuilder: (context, index) => _buildRouteItem(routes[index]),
                    ),
                  ),
                  if (_selectedRoute != null)
                    Expanded(
                      flex: 1,
                      child: _buildRouteDetail(_selectedRoute!),
                    ),
                ],
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF2d2d44))),
          ),
          child: Row(
            children: [
              Text(
                '${InspectorService.instance.routeEntries.length} Routes',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => InspectorService.instance.clearRoutes(),
                icon: const Icon(Icons.delete, color: Colors.grey, size: 16),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建单个路由记录项 / Build single route record item
  Widget _buildRouteItem(RouteEntry entry) {
    final isSelected = _selectedRoute?.id == entry.id;

    return GestureDetector(
      onTap: () => setState(() => _selectedRoute = entry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2d2d44) : Colors.transparent,
          border: Border(
            left: BorderSide(
              color: _getActionColor(entry.action),
              width: 3,
            ),
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
                    color: _getActionColor(entry.action),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    entry.actionText,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.routeName,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            Text(
              _formatTimestamp(entry.timestamp),
              style: const TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建路由详情面板 / Build route detail panel
  Widget _buildRouteDetail(RouteEntry entry) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: Color(0xFF2d2d44))),
      ),
      child: ListView(
        children: [
          _buildDetailSection('Action', entry.actionText),
          _buildDetailSection('Route Name', entry.routeName),
          _buildDetailSection('Timestamp', _formatTimestamp(entry.timestamp)),
          if (entry.arguments != null)
            _buildDetailSection('Arguments', _formatJson(entry.arguments)),
        ],
      ),
    );
  }

  /// 构建详情分段 / Build detail section
  Widget _buildDetailSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Colors.grey, fontSize: 11),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF16213e),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            content,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Monaco'),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  /// 格式化时间戳 / Format timestamp
  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}.${timestamp.millisecond.toString().padLeft(3, '0')}';
  }

  /// 根据路由操作类型获取颜色 / Get color by route action type
  Color _getActionColor(RouteAction action) {
    switch (action) {
      case RouteAction.push:
      case RouteAction.pushNamed:
        return Colors.greenAccent;
      case RouteAction.pop:
      case RouteAction.popUntil:
        return Colors.redAccent;
      case RouteAction.pushReplacement:
        return Colors.yellowAccent;
      default:
        return Colors.grey;
    }
  }

  /// 格式化JSON数据 / Format JSON data
  String _formatJson(dynamic data) {
    if (data == null) return 'null';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}