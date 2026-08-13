import 'package:flutter/material.dart';

import '../services/alert_service.dart';
import '../utils/formatters.dart';
import 'theme/inspector_theme.dart';
import 'widgets/widgets.dart';

/// 告警查看器 / Alerts viewer
///
/// 展示命中规则的告警事件列表，并提供清空入口。
/// Shows alert events that hit the rules, with a clear action.
class AlertsViewer extends StatefulWidget {
  const AlertsViewer({super.key});

  @override
  State<AlertsViewer> createState() => _AlertsViewerState();
}

class _AlertsViewerState extends State<AlertsViewer> {
  @override
  void initState() {
    super.initState();
    AlertService.instance.unreadCount.addListener(_onChanged);
  }

  @override
  void dispose() {
    AlertService.instance.unreadCount.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final alerts = AlertService.instance.events;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: InspectorColors.surface,
            border: Border(bottom: BorderSide(color: InspectorColors.border)),
          ),
          child: Row(
            children: [
              InspectorCountBadge('${alerts.length}'),
              const SizedBox(width: 8),
              Text(
                'Alerts',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              InspectorIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Clear',
                onTap: () => AlertService.instance.clearAll(),
              ),
            ],
          ),
        ),
        Expanded(
          child: alerts.isEmpty
              ? const InspectorEmptyState(
                  message: 'No alerts',
                  icon: Icons.notifications_off_rounded,
                )
              : ListView.separated(
                  itemCount: alerts.length,
                  separatorBuilder: (_, _) =>
                      Divider(color: InspectorColors.border, height: 1),
                  itemBuilder: (context, index) {
                    final e = alerts[index];
                    return ListTile(
                      dense: true,
                      leading: Icon(
                        Icons.warning_amber_rounded,
                        color: InspectorColors.error,
                        size: 18,
                      ),
                      title: Text(
                        e.source,
                        style: TextStyle(
                          color: InspectorColors.textPrimary,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        e.message,
                        style: TextStyle(
                          color: InspectorColors.textSecondary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(
                        InspectorFormatters.formatTimestamp(e.time),
                        style: TextStyle(
                          color: InspectorColors.textHint,
                          fontSize: 10,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
