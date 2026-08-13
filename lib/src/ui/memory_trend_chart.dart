import 'package:flutter/material.dart';

import '../models/memory_snapshot.dart';
import 'theme/inspector_theme.dart';

/// 内存趋势图组件 / Memory trend chart widget
///
/// 使用 [CustomPaint] 自绘折线图，展示内存历史数据。
/// Uses [CustomPaint] to draw a custom line chart showing memory history data.
///
/// 支持触摸交互：点击或拖动折线图区域，会显示十字准线、高亮最近的数据点，
/// 并在顶部浮出 tooltip 显示该时刻的数值与时间。
/// Supports touch interaction: tapping or dragging on the chart shows a crosshair,
/// highlights the nearest data point, and pops a tooltip with the value and time.
///
/// 支持的指标 / Supported metrics:
/// - [MemoryMetric.processRss] 进程 RSS（始终可用）/ Process RSS (always available)
/// - [MemoryMetric.heapUsage] Dart Heap 已使用（VM Service 可用时可用）
///   Dart Heap used (available when VM Service is available)
/// - [MemoryMetric.newSpaceUsage] 新生代已使用 / New space used
/// - [MemoryMetric.oldSpaceUsage] 老生代已使用 / Old space used
///
/// 当选中指标对应数据不可用时，会显示 N/A 占位说明
/// When the data for the selected metric is unavailable, an N/A placeholder is shown
class MemoryTrendChart extends StatefulWidget {
  /// 内存历史快照列表 / Memory historical snapshot list
  final List<MemorySnapshot> snapshots;

  /// 当前选中的指标 / Currently selected metric
  final MemoryMetric metric;

  /// 指标切换回调 / Metric switch callback
  final ValueChanged<MemoryMetric>? onMetricChanged;

  /// VM Service 是否可用（决定 Heap 指标是否可选）/ Whether VM Service is available
  final bool vmServiceAvailable;

  /// 构造函数 / Constructor
  const MemoryTrendChart({
    super.key,
    required this.snapshots,
    required this.metric,
    this.onMetricChanged,
    this.vmServiceAvailable = false,
  });

  @override
  State<MemoryTrendChart> createState() => _MemoryTrendChartState();
}

class _MemoryTrendChartState extends State<MemoryTrendChart> {
  /// 当前触摸高亮的数据点索引 / Currently highlighted data point index
  ///
  /// 为 null 时表示未触摸，显示图例（Current / Peak / Min）
  /// null means not touched; the legend (Current / Peak / Min) is shown instead
  int? _touchedIndex;

  /// 根据触摸位置（相对绘图区的局部 x）定位最近的数据点索引
  /// Locate the nearest data point index from a touch x offset (local to chart)
  int? _indexFromLocalX(double localX, double chartWidth, int pointCount) {
    if (pointCount < 2 || chartWidth <= 0) return null;
    final padding = _LineChartPainter.padding;
    final usableWidth = chartWidth - padding * 2;
    final ratio = ((localX - padding) / usableWidth).clamp(0.0, 1.0);
    final index = (ratio * (pointCount - 1)).round();
    return index.clamp(0, pointCount - 1);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildMetricSelector(),
          const SizedBox(height: 12),
          _buildChartArea(),
        ],
      ),
    );
  }

  /// 构建头部 / Build header
  Widget _buildHeader() {
    return Row(
      children: [
        Icon(
          Icons.show_chart_rounded,
          size: 16,
          color: InspectorColors.textSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          'Memory Trend',
          style: TextStyle(
            color: InspectorColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          '${widget.snapshots.length}/${240}',
          style: TextStyle(
            color: InspectorColors.textHint,
            fontSize: 11,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// 构建指标选择器 / Build metric selector
  Widget _buildMetricSelector() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: MemoryMetric.values.map((m) {
        final enabled = _isMetricEnabled(m);
        final selected = m == widget.metric;
        return _buildMetricChip(
          label: m.label,
          selected: selected,
          enabled: enabled,
          color: m.color,
          onTap: enabled && widget.onMetricChanged != null
              ? () => widget.onMetricChanged!(m)
              : null,
        );
      }).toList(),
    );
  }

  /// 检查指标是否可用 / Check if metric is enabled
  bool _isMetricEnabled(MemoryMetric m) {
    if (m == MemoryMetric.processRss) return true;
    return widget.vmServiceAvailable;
  }

  /// 构建指标 Chip / Build metric chip
  Widget _buildMetricChip({
    required String label,
    required bool selected,
    required bool enabled,
    required Color color,
    VoidCallback? onTap,
  }) {
    final opacity = enabled ? (selected ? 1.0 : 0.6) : 0.3;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : InspectorColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: opacity),
            fontSize: 10,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }

  /// 构建图表区域 / Build chart area
  Widget _buildChartArea() {
    // 指标数据不可用时显示 N/A
    // Show N/A when metric data is unavailable
    if (!_isMetricEnabled(widget.metric)) {
      return _buildUnavailableChart();
    }

    // 没有数据时显示空状态
    // Show empty state when no data
    if (widget.snapshots.isEmpty) {
      return _buildEmptyChart();
    }

    final values = widget.snapshots.map((s) => _getValue(s)).toList();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final currentValue = values.last;

    // 避免 maxValue 为 0 导致除零
    // Avoid division by zero when maxValue is 0
    final safeMax = maxValue > 0 ? maxValue : 1;

    // Y 轴刻度值（3 个：最大值、中间值、最小值）/ Y-axis tick values (3: max, mid, min)
    final yLabels = <String>[
      _formatBytes(maxValue),
      _formatBytes(((maxValue + minValue) / 2).round()),
      _formatBytes(minValue),
    ];

    // X 轴时间标签（3 个：2分钟前、1分钟前、现在）/ X-axis time labels (3: 2min ago, 1min ago, Now)
    final xLabels = <String>['-2m', '-1m', 'Now'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 触摸高亮时的浮动 tooltip / Floating tooltip when touched
        if (_touchedIndex != null)
          _buildTooltip(_touchedIndex!, values)
        else
          // 无触摸时显示图例：Current / Peak / Min
          // Legend: Current / Peak / Min when not touched
          _buildLegend(currentValue, maxValue, minValue),
        const SizedBox(height: 10),
        // 图表主体：左侧 Y 轴标签 + 中间折线图 / Chart body: left Y-axis labels + center line chart
        // 注意：不要使用 IntrinsicHeight 包裹 Expanded/LayoutBuilder，否则在父级
        // 高频重建（如开启内存监控时 InspectorPanel 每 500ms setState）时会触发
        // `!_debugDoingThisLayout` 布局断言失败，导致面板渲染树损坏、视图消失。
        // NOTE: do NOT wrap Expanded/LayoutBuilder in IntrinsicHeight here — it
        // triggers a `!_debugDoingThisLayout` layout assertion when the parent
        // rebuilds frequently (e.g. InspectorPanel setState every 500ms while
        // memory monitoring is on), corrupting the panel render tree and making
        // the view disappear.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧 Y 轴标签（固定高度对齐图表主体）/ Left Y-axis labels (fixed height)
            SizedBox(
              width: 52,
              height: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: yLabels
                    .map(
                      (label) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: InspectorColors.textHint,
                            fontSize: 9,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            // 中间折线图 + 底部 X 轴标签 / Center line chart + bottom X-axis labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // LayoutBuilder 仅用于获取折线图实际宽度定位触摸点，
                  // 不再置于 IntrinsicHeight 内，避免布局断言崩溃。
                  // LayoutBuilder only measures the chart width for touch hit
                  // testing; kept out of IntrinsicHeight to avoid layout crash.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final chartWidth = constraints.maxWidth;
                      return GestureDetector(
                        // 点击定位最近数据点 / Tap to locate nearest point
                        onTapDown: (details) {
                          final idx = _indexFromLocalX(
                            details.localPosition.dx,
                            chartWidth,
                            values.length,
                          );
                          if (idx != null) {
                            setState(() => _touchedIndex = idx);
                          }
                        },
                        onTapCancel: () => setState(() => _touchedIndex = null),
                        // 拖动实时跟手 / Drag to follow finger in real time
                        onPanDown: (details) {
                          final idx = _indexFromLocalX(
                            details.localPosition.dx,
                            chartWidth,
                            values.length,
                          );
                          if (idx != null) {
                            setState(() => _touchedIndex = idx);
                          }
                        },
                        onPanUpdate: (details) {
                          final idx = _indexFromLocalX(
                            details.localPosition.dx,
                            chartWidth,
                            values.length,
                          );
                          if (idx != null) {
                            setState(() => _touchedIndex = idx);
                          }
                        },
                        onPanEnd: (_) => setState(() => _touchedIndex = null),
                        child: SizedBox(
                          height: 100,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: _LineChartPainter(
                              values: values,
                              maxValue: safeMax,
                              lineColor: widget.metric.color,
                              fillColor: widget.metric.color.withValues(
                                alpha: 0.2,
                              ),
                              backgroundColor: InspectorColors.surface,
                              gridColor: InspectorColors.divider,
                              highlightIndex: _touchedIndex,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                  // 底部 X 轴标签 / Bottom X-axis labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: xLabels
                        .map(
                          (label) => Text(
                            label,
                            style: TextStyle(
                              color: InspectorColors.textHint,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建触摸 tooltip / Build touch tooltip
  ///
  /// 显示高亮点的数值与时间（相对"现在"的偏移）
  /// Shows the highlighted point's value and time (offset from "now")
  Widget _buildTooltip(int index, List<int> values) {
    final snapshot = widget.snapshots[index];
    final value = values[index];
    final now = widget.snapshots.isNotEmpty
        ? widget.snapshots.last.timestamp
        : DateTime.now();
    final delta = now.difference(snapshot.timestamp);
    final timeLabel = delta.inSeconds <= 0
        ? 'Now'
        : '-${(delta.inSeconds / 60).floor()}m ${delta.inSeconds % 60}s';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: widget.metric.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: widget.metric.color.withValues(alpha: 0.4),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.metric.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _formatBytes(value),
            style: TextStyle(
              color: widget.metric.color,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          Text(
            timeLabel,
            style: TextStyle(
              color: InspectorColors.textHint,
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }

  /// 构建图例项组 / Build legend group
  Widget _buildLegend(int currentValue, int maxValue, int minValue) {
    return Row(
      children: [
        Expanded(
          child: _buildChartLegend(
            'Current',
            _formatBytes(currentValue),
            widget.metric.color,
          ),
        ),
        Expanded(
          child: _buildChartLegend(
            'Peak',
            _formatBytes(maxValue),
            InspectorColors.warning,
          ),
        ),
        Expanded(
          child: _buildChartLegend(
            'Min',
            _formatBytes(minValue),
            InspectorColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// 获取快照对应指标的值 / Get the value of the metric for the snapshot
  int _getValue(MemorySnapshot s) {
    switch (widget.metric) {
      case MemoryMetric.processRss:
        return s.processRss;
      case MemoryMetric.heapUsage:
        return s.heapUsage;
      case MemoryMetric.newSpaceUsage:
        return s.newSpaceUsage;
      case MemoryMetric.oldSpaceUsage:
        return s.oldSpaceUsage;
    }
  }

  /// 构建图例项 / Build legend item
  Widget _buildChartLegend(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: InspectorColors.textHint, fontSize: 10),
            ),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 构建不可用占位 / Build unavailable placeholder
  ///
  /// 当 Heap 相关指标选中但 VM Service 不可用时显示
  /// Shown when Heap-related metric is selected but VM Service is unavailable
  Widget _buildUnavailableChart() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 20,
            color: InspectorColors.textHint,
          ),
          const SizedBox(height: 4),
          Text(
            'N/A',
            style: TextStyle(
              color: InspectorColors.textHint,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'VM Service unavailable\nAvailable in debug/profile mode only',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: InspectorColors.textHint,
              fontSize: 9,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建空状态占位 / Build empty state placeholder
  Widget _buildEmptyChart() {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: InspectorColors.surface,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      alignment: Alignment.center,
      child: Text(
        'Collecting data...',
        style: TextStyle(color: InspectorColors.textHint, fontSize: 11),
      ),
    );
  }

  /// 格式化字节数为可读字符串 / Format bytes to readable string
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// 内存指标枚举 / Memory metric enum
///
/// 用于在趋势图中切换不同指标 / Used to switch between different metrics in the trend chart
enum MemoryMetric {
  /// 进程 RSS（始终可用）/ Process RSS (always available)
  processRss('RSS', Color(0xFF60a5fa)),

  /// Dart Heap 已使用 / Dart Heap used
  heapUsage('Heap', Color(0xFF34d399)),

  /// 新生代已使用 / New space used
  newSpaceUsage('New', Color(0xFFfbbf24)),

  /// 老生代已使用 / Old space used
  oldSpaceUsage('Old', Color(0xFFa78bfa));

  /// 显示标签 / Display label
  final String label;

  /// 指标颜色 / Metric color
  final Color color;

  const MemoryMetric(this.label, this.color);
}

/// 折线图绘制器 / Line chart painter
///
/// 使用 [CustomPainter] 自绘折线图，避免引入额外的图表库
/// Uses [CustomPainter] to draw a custom line chart, avoiding extra chart library dependencies
class _LineChartPainter extends CustomPainter {
  /// 数据点列表 / Data point list
  final List<int> values;

  /// 最大值（用于归一化）/ Maximum value (for normalization)
  final int maxValue;

  /// 折线颜色 / Line color
  final Color lineColor;

  /// 填充颜色（折线下方区域）/ Fill color (area below the line)
  final Color fillColor;

  /// 背景颜色 / Background color
  final Color backgroundColor;

  /// 网格线颜色 / Grid line color
  final Color gridColor;

  /// 高亮数据点的索引；为 null 时不绘制十字准线 / Highlighted point index; null disables crosshair
  final int? highlightIndex;

  /// 内边距（图表距离画布边缘）/ Padding (chart to canvas edge)
  static const double padding = 4.0;

  /// 网格水平线数量 / Number of horizontal grid lines
  static const int _gridLineCount = 4;

  _LineChartPainter({
    required this.values,
    required this.maxValue,
    required this.lineColor,
    required this.fillColor,
    required this.backgroundColor,
    required this.gridColor,
    this.highlightIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. 绘制背景
    // 1. Draw background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(6),
      ),
      bgPaint,
    );

    // 2. 绘制网格线
    // 2. Draw grid lines
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final chartHeight = size.height - padding * 2;
    for (var i = 0; i <= _gridLineCount; i++) {
      final y = padding + (chartHeight / _gridLineCount) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    // 3. 至少需要 2 个数据点才能绘制折线
    // 3. At least 2 data points are needed to draw a line
    if (values.length < 2) {
      // 单点：绘制圆点
      // Single point: draw a dot
      if (values.isNotEmpty) {
        final x = size.width / 2;
        final normalized = maxValue > 0 ? values.first / maxValue : 0.0;
        final y = size.height - padding - (chartHeight * normalized);

        final dotPaint = Paint()..color = lineColor;
        canvas.drawCircle(Offset(x, y), 2, dotPaint);
      }
      return;
    }

    // 4. 计算每个数据点的坐标
    // 4. Calculate coordinates for each data point
    final chartWidth = size.width - padding * 2;
    final stepX = chartWidth / (values.length - 1);

    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = padding + stepX * i;
      final normalized = maxValue > 0 ? values[i] / maxValue : 0.0;
      // 留 5% 顶部空间避免折线贴边
      // Leave 5% top space to avoid line touching the edge
      final y = size.height - padding - (chartHeight * 0.95 * normalized);
      points.add(Offset(x, y));
    }

    // 5. 绘制填充区域（折线下方）
    // 5. Draw fill area (below the line)
    final fillPath = Path()
      ..moveTo(points.first.dx, size.height - padding)
      ..addPoints(points.map((p) => Offset(p.dx, p.dy)).toList())
      ..lineTo(points.last.dx, size.height - padding)
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // 6. 绘制折线
    // 6. Draw the line
    final linePath = Path()..addPoints(points);
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // 7. 绘制当前点（最后一个点）
    // 7. Draw current point (last point)
    final lastPoint = points.last;
    final dotPaint = Paint()..color = lineColor;
    canvas.drawCircle(lastPoint, 3, dotPaint);
    // 外圈高亮 / Outer ring highlight
    final ringPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPoint, 5, ringPaint);

    // 8. 触摸高亮：十字准线 + 选中点圈
    // 8. Touch highlight: crosshair + highlighted point ring
    if (highlightIndex != null &&
        highlightIndex! >= 0 &&
        highlightIndex! < points.length) {
      final hp = points[highlightIndex!];
      // 竖向准线 / Vertical crosshair line
      final crossPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.35)
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(hp.dx, padding),
        Offset(hp.dx, size.height - padding),
        crossPaint,
      );
      // 横向准线 / Horizontal crosshair line
      canvas.drawLine(
        Offset(padding, hp.dy),
        Offset(size.width - padding, hp.dy),
        crossPaint,
      );
      // 选中点：外圈 + 实心点 / Highlighted point: outer ring + solid dot
      final highlightRing = Paint()
        ..color = lineColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(hp, 7, highlightRing);
      final highlightDot = Paint()..color = lineColor;
      canvas.drawCircle(hp, 3.5, highlightDot);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    // 当数据、最大值或颜色变化时重绘
    // Repaint when data, max value, or color changes
    return oldDelegate.values != values ||
        oldDelegate.maxValue != maxValue ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.highlightIndex != highlightIndex;
  }
}

/// Path 扩展方法：批量添加点 / Path extension: batch add points
extension on Path {
  void addPoints(List<Offset> points) {
    if (points.isEmpty) return;
    moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      lineTo(points[i].dx, points[i].dy);
    }
  }
}
