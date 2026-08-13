import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/network_request.dart';
import 'theme/inspector_theme.dart';
import 'widgets/inspector_state_views.dart';

/// 网络请求瀑布图 / Network request waterfall (timeline).
///
/// 以时间轴的形式展示每个请求的发起、等待与响应过程，便于发现并发、长阻塞。
/// 视图本身使用 [ListView] 滚动，行高固定，不会出现无限高度导致 UI 溢出的问题。
/// Presents each request's start, wait and response over a shared time axis so
/// concurrency and slow requests are easy to spot. The list scrolls via its own
/// [ListView] with a fixed row height, so there is no unbounded-height risk.
class NetworkTimeline extends StatelessWidget {
  /// 要展示的请求列表（已按调用方过滤）/ Requests to display (already filtered)
  final List<NetworkRequest> requests;

  /// 导出时是否遮蔽敏感头 / Mask sensitive headers on export
  final bool maskSensitive;

  /// 点击某行的回调 / Tap callback for a row
  final void Function(NetworkRequest)? onTap;

  const NetworkTimeline({
    super.key,
    required this.requests,
    this.maskSensitive = false,
    this.onTap,
  });

  /// 固定的单行高度 / Fixed row height
  static const double _rowHeight = 34.0;

  /// 轴标签列（左侧方法 + URL 摘要）宽度 / Axis label column width (left side)
  static const double _labelWidth = 190.0;

  /// 时间轴两侧留白 / Horizontal padding of the track
  static const double _trackPadding = 8.0;

  @override
  Widget build(BuildContext context) {
    if (requests.isEmpty) {
      return const InspectorEmptyState(message: 'No requests to display');
    }

    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall;

    // 统一的时间窗：从最早请求开始，到最晚响应结束。
    // Single shared window: from the earliest start to the latest finish.
    int minStart = requests.first.requestTime;
    int maxEnd = minStart;
    for (final r in requests) {
      minStart = math.min(minStart, r.requestTime);
      final end = r.responseTime ?? r.requestTime;
      maxEnd = math.max(maxEnd, end);
    }
    // 至少 1ms 跨度，避免除零 / at least 1ms span to avoid divide-by-zero
    final span = math.max(1, maxEnd - minStart);
    // 两端各留 5% 余量，避免首尾贴边 / 5% safe margin on both ends
    final safeSpan = (span * 1.1).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 图例 / Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _LegendDot(color: InspectorColors.accent, label: 'Wait'),
              const SizedBox(width: 14),
              _LegendDot(color: InspectorColors.success, label: 'Response'),
              const Spacer(),
              Text(
                '${requests.length} requests',
                style: textStyle?.copyWith(
                  color: InspectorColors.textHint,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        // 使用 ListView 自身滚动，避免无限高度 / Let ListView scroll itself
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.only(bottom: 12),
            itemCount: requests.length,
            separatorBuilder: (_, _) => const SizedBox(height: 2),
            itemBuilder: (context, index) {
              final r = requests[index];
              return LayoutBuilder(
                builder: (context, constraints) {
                  final trackWidth = math.max(
                    0.0,
                    constraints.maxWidth - _labelWidth - _trackPadding * 2,
                  );
                  return _TimelineRow(
                    request: r,
                    minStart: minStart,
                    safeSpan: safeSpan,
                    trackWidth: trackWidth,
                    height: _rowHeight,
                    labelWidth: _labelWidth,
                    trackPadding: _trackPadding,
                    onTap: onTap,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: InspectorColors.textHint,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.request,
    required this.minStart,
    required this.safeSpan,
    required this.trackWidth,
    required this.height,
    required this.labelWidth,
    required this.trackPadding,
    required this.onTap,
  });

  final NetworkRequest request;
  final int minStart;
  final int safeSpan;
  final double trackWidth;
  final double height;
  final double labelWidth;
  final double trackPadding;
  final void Function(NetworkRequest)? onTap;

  @override
  Widget build(BuildContext context) {
    final start = (request.requestTime - minStart);
    final responseTime = request.responseTime ?? request.requestTime;
    final end = (responseTime - minStart);

    // 与时间窗同比例映射到轨道宽度
    // Map into the track width using the same ratio as the shared window
    final waitLeft = _clamp01(start / safeSpan) * trackWidth;
    final waitRight = _clamp01(end / safeSpan) * trackWidth;

    // 等待段 + 响应段（响应没有独立时长时回退为小圆点）
    // Wait segment + response segment (fallback to a dot when no response duration)
    final hasResponse = request.responseTime != null && safeSpan > 0;
    final waitWidth = math.max(2.0, waitRight - waitLeft);
    final respWidth = hasResponse ? math.max(2.0, trackWidth * 0.04) : 0.0;

    return SizedBox(
      height: height,
      child: InkWell(
        onTap: onTap == null ? null : () => onTap!(request),
        child: Row(
          children: [
            // 左：方法 + URL 摘要（省略溢出）/ Left: method + url summary (ellipsis)
            SizedBox(
              width: labelWidth,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _methodColor(
                          request.method,
                        ).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        request.method,
                        style: TextStyle(
                          color: _methodColor(request.method),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _shortUrl(request.url),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: InspectorColors.textPrimary,
                          fontSize: 11,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 右：轨道 / Right: track
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: trackPadding),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // 背景轨道 / background track
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: InspectorColors.card,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // 等待段 / wait segment
                    Positioned(
                      left: waitLeft,
                      top: height / 2 - 4,
                      width: waitWidth,
                      height: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: InspectorColors.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    // 响应段（圆点）/ response marker
                    if (respWidth > 0)
                      Positioned(
                        left: waitRight,
                        top: height / 2 - 5,
                        width: respWidth,
                        height: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: InspectorColors.success,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _clamp01(double v) => v.clamp(0.0, 1.0);

  Color _methodColor(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return InspectorColors.methodGet;
      case 'POST':
        return InspectorColors.methodPost;
      case 'PUT':
        return InspectorColors.methodPut;
      case 'DELETE':
        return InspectorColors.methodDelete;
      case 'PATCH':
        return InspectorColors.methodPatch;
      default:
        return InspectorColors.textSecondary;
    }
  }

  String _shortUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.path.isEmpty ? '/' : uri.path;
      final q = uri.query.isNotEmpty ? '?${uri.query}' : '';
      return '${uri.host}$path$q';
    } catch (_) {
      return url;
    }
  }
}
