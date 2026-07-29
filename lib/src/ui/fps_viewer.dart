import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/fps_service.dart';
import 'theme/inspector_theme.dart';

/// FPS 查看器（Inspector 面板内详情页）/ FPS viewer (in-panel detail page)
///
/// 包含以下内容 / Contains:
/// - FPS 概览卡片（当前 FPS、掉帧率、总帧数）/ FPS overview card (current FPS, jank rate, total frames)
/// - FPS 趋势折线图 / FPS trend line chart
/// - 掉帧记录列表 / Janky frame record list
class FpsViewer extends StatefulWidget {
  const FpsViewer({super.key});

  @override
  State<FpsViewer> createState() => _FpsViewerState();
}

class _FpsViewerState extends State<FpsViewer> {
  @override
  void initState() {
    super.initState();
    FpsService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    FpsService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final service = FpsService.instance;

    return Container(
      color: InspectorColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 总开关卡片 / Master switch card
            _buildMainSwitchCard(),
            const SizedBox(height: 12),
            if (service.isRunning) ...[
              _buildOverviewCard(),
              const SizedBox(height: 12),
              _buildFpsChartCard(),
              const SizedBox(height: 12),
              _buildJankyListCard(),
            ] else
              _buildDisabledPlaceholder(),
          ],
        ),
      ),
    );
  }

  /// 构建主开关卡片 / Build main switch card
  Widget _buildMainSwitchCard() {
    final service = FpsService.instance;
    final running = service.isRunning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(
          color: running
              ? InspectorColors.success.withValues(alpha: 0.3)
              : InspectorColors.border,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                running ? Icons.speed_rounded : Icons.speed_outlined,
                size: 18,
                color: running
                    ? InspectorColors.success
                    : InspectorColors.textHint,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FPS Monitor',
                      style: TextStyle(
                        color: InspectorColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      running
                          ? 'Running · collecting frame data'
                          : 'Stopped · no data collection',
                      style: TextStyle(
                        color: running
                            ? InspectorColors.success
                            : InspectorColors.textHint,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: running,
                activeThumbColor: InspectorColors.success,
                activeTrackColor: InspectorColors.success.withValues(
                  alpha: 0.3,
                ),
                inactiveThumbColor: InspectorColors.textHint,
                inactiveTrackColor: InspectorColors.border,
                onChanged: (value) {
                  if (value) {
                    service.start();
                  } else {
                    service.stop();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建 FPS 概览卡片 / Build FPS overview card
  Widget _buildOverviewCard() {
    final service = FpsService.instance;
    final fps = service.currentFps;
    final fpsColor = _getFpsColor(fps);

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
          Row(
            children: [
              Icon(Icons.speed_rounded, size: 16, color: fpsColor),
              const SizedBox(width: 6),
              Text(
                'Current FPS',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  FpsService.instance.clear();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: InspectorColors.warning.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: InspectorColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.refresh_rounded,
                        size: 13,
                        color: InspectorColors.warning,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Reset',
                        style: TextStyle(
                          color: InspectorColors.warning,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildFpsStat(
                  'FPS',
                  fps > 0 ? fps.toStringAsFixed(0) : '--',
                  fpsColor,
                  isBig: true,
                ),
              ),
              Expanded(
                child: _buildFpsStat(
                  'Jank Rate',
                  '${service.jankRate.toStringAsFixed(1)}%',
                  service.jankRate > 5
                      ? InspectorColors.error
                      : InspectorColors.success,
                ),
              ),
              Expanded(
                child: _buildFpsStat(
                  'Frames',
                  '${service.totalFrameCount}',
                  InspectorColors.info,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 掉帧进度条 / Jank progress bar
          if (service.totalFrameCount > 0) ...[
            Row(
              children: [
                Text(
                  'Janky: ${service.totalJankyCount} / ${service.totalFrameCount}',
                  style: TextStyle(
                    color: InspectorColors.textHint,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: service.jankRate / 100,
                      backgroundColor: InspectorColors.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        service.jankRate > 5
                            ? InspectorColors.error
                            : InspectorColors.success,
                      ),
                      minHeight: 3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 构建 FPS 统计项 / Build FPS stat item
  Widget _buildFpsStat(
    String label,
    String value,
    Color color, {
    bool isBig = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: InspectorColors.textHint, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: isBig ? 24 : 13,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  /// 构建 FPS 趋势图卡片 / Build FPS trend chart card
  Widget _buildFpsChartCard() {
    final service = FpsService.instance;
    final history = service.fpsHistory;

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
          Row(
            children: [
              Icon(
                Icons.show_chart_rounded,
                size: 16,
                color: InspectorColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'FPS Trend (30s)',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${history.length} points',
                style: TextStyle(color: InspectorColors.textHint, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            width: double.infinity,
            child: CustomPaint(
              painter: _FpsLineChartPainter(
                values: history,
                lineColor: InspectorColors.info,
                gridColor: InspectorColors.divider,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '30s ago',
                style: TextStyle(
                  color: InspectorColors.textHint,
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
              Text(
                'Now',
                style: TextStyle(
                  color: InspectorColors.textHint,
                  fontSize: 9,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建掉帧列表卡片 / Build janky frame list card
  Widget _buildJankyListCard() {
    final service = FpsService.instance;
    final jankyFrames = service.frameRecords.where((f) => f.isJanky).toList();

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
          Row(
            children: [
              Icon(
                Icons.bug_report_rounded,
                size: 16,
                color: jankyFrames.isNotEmpty
                    ? InspectorColors.error
                    : InspectorColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                'Janky Frames',
                style: TextStyle(
                  color: InspectorColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: jankyFrames.isNotEmpty
                      ? InspectorColors.error.withValues(alpha: 0.1)
                      : InspectorColors.textHint.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: jankyFrames.isNotEmpty
                        ? InspectorColors.error.withValues(alpha: 0.3)
                        : InspectorColors.textHint.withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${jankyFrames.length}',
                  style: TextStyle(
                    color: jankyFrames.isNotEmpty
                        ? InspectorColors.error
                        : InspectorColors.textHint,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (jankyFrames.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: InspectorColors.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: InspectorColors.border, width: 0.5),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 32,
                    color: InspectorColors.success,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'No janky frames detected',
                    style: TextStyle(
                      color: InspectorColors.textHint,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 150,
              child: ListView.builder(
                itemCount: jankyFrames.length > 20 ? 20 : jankyFrames.length,
                itemBuilder: (context, index) {
                  final frame = jankyFrames[jankyFrames.length - 1 - index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: InspectorColors.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: InspectorColors.error.withValues(alpha: 0.3),
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: InspectorColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(frame.durationUs / 1000).toStringAsFixed(1)}ms',
                          style: TextStyle(
                            color: InspectorColors.error,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(frame.timestamp),
                          style: TextStyle(
                            color: InspectorColors.textHint,
                            fontSize: 10,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  /// 构建未启用占位 / Build disabled placeholder
  Widget _buildDisabledPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: InspectorColors.card,
        borderRadius: BorderRadius.circular(InspectorDimensions.cardRadius),
        border: Border.all(color: InspectorColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(Icons.speed_outlined, size: 40, color: InspectorColors.textHint),
          const SizedBox(height: 12),
          Text(
            'FPS monitoring is disabled',
            style: TextStyle(
              color: InspectorColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Turn on the switch above to start collecting frame data.\nFPS monitoring helps identify jank and rendering issues.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: InspectorColors.textHint,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// 根据 FPS 值获取颜色 / Get color based on FPS value
  Color _getFpsColor(double fps) {
    if (fps >= 55) return const Color(0xFF34d399);
    if (fps >= 45) return const Color(0xFFfbbf24);
    if (fps > 0) return const Color(0xFFf87171);
    return InspectorColors.textHint;
  }

  /// 格式化时间戳 / Format timestamp
  String _formatTime(int timestamp) {
    final dt = DateTime.fromMicrosecondsSinceEpoch(timestamp);
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}

/// FPS 折线图绘制器 / FPS line chart painter
class _FpsLineChartPainter extends CustomPainter {
  final List<double> values;
  final Color lineColor;
  final Color gridColor;

  _FpsLineChartPainter({
    required this.values,
    required this.lineColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // 绘制网格线 / Draw grid lines
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (values.isEmpty) {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint..color = gridColor,
      );
      return;
    }

    // 动态计算 Y 轴上限，至少 60，支持高刷新率（90/120Hz）设备
    // Dynamic Y-axis max, at least 60, supports high refresh rate (90/120Hz) devices
    final maxFps = values.isEmpty
        ? 60.0
        : math.max(60.0, values.reduce((a, b) => a > b ? a : b));
    final stepX = size.width / (values.length > 1 ? values.length - 1 : 1);

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = i * stepX;
      // clamp y 到 [0, height] 防止超出绘制区域 / clamp y to [0, height] to avoid overflow
      final y = (size.height - (values[i] / maxFps) * size.height).clamp(
        0.0,
        size.height,
      );

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // 闭合填充路径 / Close fill path
    if (values.isNotEmpty) {
      fillPath.lineTo((values.length - 1) * stepX, size.height);
      fillPath.close();
    }

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FpsLineChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}
