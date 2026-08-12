import 'package:flutter/material.dart';
import '../models/route_entry.dart';
import '../services/inspector_service.dart';
import '../utils/formatters.dart';
import 'theme/inspector_theme.dart';
import 'widgets/widgets.dart';

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
              if (_selectedRoute != null) {
                return _buildRouteDetail(_selectedRoute!);
              }

              final routes = InspectorService.instance.routeEntries;
              return routes.isEmpty
                  ? InspectorEmptyState(
                      message: 'No routes yet',
                      icon: Icons.route_rounded,
                    )
                  : ListView.builder(
                      itemCount: routes.length,
                      itemBuilder: (context, index) =>
                          _buildRouteItem(routes[index]),
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
        final isDetail = _selectedRoute != null;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: InspectorColors.surface,
            border: Border(bottom: BorderSide(color: InspectorColors.border)),
          ),
          child: Row(
            children: [
              if (isDetail)
                InspectorIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Back',
                  onTap: () => setState(() => _selectedRoute = null),
                )
              else
                InspectorCountBadge(
                  '${InspectorService.instance.routeEntries.length}',
                ),
              const SizedBox(width: 8),
              Text(
                isDetail ? 'Route Detail' : 'Routes',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (!isDetail)
                InspectorIconButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Clear',
                  onTap: () => InspectorService.instance.clearRoutes(),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 构建单个路由记录项 / Build single route record item
  Widget _buildRouteItem(RouteEntry entry) {
    final actionColor = _getActionColor(entry.action);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedRoute = entry),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: actionColor, width: 3),
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
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: actionColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      entry.actionText,
                      style: TextStyle(
                        color: actionColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.routeName,
                      style: TextStyle(
                        color: InspectorColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: InspectorColors.textHint,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatTimestamp(entry.timestamp),
                style: TextStyle(
                  color: InspectorColors.textSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建路由详情页 / Build route detail page (same panel, list <-> detail)
  Widget _buildRouteDetail(RouteEntry entry) {
    final actionColor = _getActionColor(entry.action);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        _detailSection(
          'Action',
          entry.actionText,
          Icons.smart_toy_rounded,
          actionColor,
        ),
        _detailSection(
          'Route Name',
          entry.routeName,
          Icons.route_rounded,
          InspectorColors.accent,
        ),
        _detailSection(
          'Timestamp',
          _formatTimestamp(entry.timestamp),
          Icons.access_time_rounded,
          InspectorColors.textSecondary,
        ),
        if (entry.arguments != null)
          _detailSection(
            'Arguments',
            _formatJson(entry.arguments),
            Icons.data_object_rounded,
            InspectorColors.info,
          ),
      ],
    );
  }
}

/// 格式化JSON数据 / Format JSON data
String _formatJson(dynamic data) => InspectorFormatters.formatJson(data);

/// 格式化时间戳 / Format timestamp
String _formatTimestamp(DateTime timestamp) =>
    InspectorFormatters.formatTimestamp(timestamp);

/// 根据路由操作类型获取颜色 / Get color by route action type
Color _getActionColor(RouteAction action) {
  switch (action) {
    case RouteAction.push:
    case RouteAction.pushNamed:
      return InspectorColors.routePush;
    case RouteAction.pop:
    case RouteAction.popUntil:
      return InspectorColors.routePop;
    case RouteAction.pushReplacement:
      return InspectorColors.routeReplace;
    default:
      return InspectorColors.textSecondary;
  }
}

/// 详情分段（可复用顶层函数）/ Reusable detail section.
Widget _detailSection(String title, String content, IconData icon, Color color) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: InspectorColors.card,
            borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
            border: Border.all(color: InspectorColors.border, width: 0.5),
          ),
          child: Text(
            content,
            style: TextStyle(
              color: InspectorColors.textPrimary,
              fontSize: 11.5,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}
