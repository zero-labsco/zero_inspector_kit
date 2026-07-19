import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'theme/inspector_theme.dart';
import 'inspector_panel.dart';

/// 悬浮检查器按钮 / Floating inspector button
/// 隐藏在屏幕边缘，可拖动，点击展开检查器面板 / Hidden at screen edge, draggable, click to expand inspector panel
///
/// 在生产环境（release模式）下，此组件会返回空容器，不会打包检查器代码 / In production environment (release mode), this widget returns an empty container, inspector code won't be bundled
class FloatingInspectorButton extends StatefulWidget {
  /// 是否启用检查器按钮 / Whether to enable inspector button
  /// 默认根据环境自动判断：debug模式启用，release模式禁用 / Auto-detect by environment by default: enabled in debug mode, disabled in release mode
  final bool enabled;

  const FloatingInspectorButton({super.key, this.enabled = true});

  @override
  State<FloatingInspectorButton> createState() =>
      _FloatingInspectorButtonState();
}

class _FloatingInspectorButtonState extends State<FloatingInspectorButton>
    with SingleTickerProviderStateMixin {
  /// 按钮X坐标 / Button X coordinate
  double _x = 0;

  /// 按钮Y坐标 / Button Y coordinate
  double _y = 200;

  /// 是否展开检查器面板 / Whether inspector panel is expanded
  bool _isExpanded = false;

  /// 按钮是否可见 / Whether button is visible
  bool _isVisible = false;

  /// 是否正在拖动按钮 / Whether button is being dragged
  bool _isDragging = false;

  /// 拖动开始位置 / Drag start position
  Offset? _dragStart;

  /// 拖动开始时的X坐标 / X coordinate at drag start
  double? _startX;

  /// 拖动开始时的Y坐标 / Y coordinate at drag start
  double? _startY;

  /// 呼吸动画控制器 / Breathing animation controller
  late final AnimationController _breathController;

  /// 呼吸动画 / Breathing animation
  late final Animation<double> _breathAnimation;

  /// 按钮尺寸 / Button size
  final double _buttonSize = InspectorDimensions.floatingButtonSize;

  @override
  void initState() {
    super.initState();
    _breathController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    if (widget.enabled) {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() => _isVisible = true);
        }
      });
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();
    if (!widget.enabled || !_isVisible) return const SizedBox.shrink();

    return Stack(
      children: [
        if (_isExpanded) _buildExpandedPanel(),
        _buildDraggableButton(),
      ],
    );
  }

  /// 构建可拖动的悬浮按钮 / Build draggable floating button
  Widget _buildDraggableButton() {
    return Positioned(
      left: _isExpanded ? -_buttonSize : _x,
      top: _y,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _isExpanded ? 0 : 1,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: _isExpanded ? 0.5 : 1,
          child: GestureDetector(
            onTap: _toggleExpanded,
            onPanStart: (details) {
              _isDragging = true;
              _dragStart = details.globalPosition;
              _startX = _x;
              _startY = _y;
            },
            onPanUpdate: (details) {
              if (!_isDragging || _dragStart == null) return;
              final deltaX = details.globalPosition.dx - _dragStart!.dx;
              final deltaY = details.globalPosition.dy - _dragStart!.dy;

              setState(() {
                _x = (_startX! + deltaX).clamp(
                  0.0,
                  MediaQuery.of(context).size.width - _buttonSize,
                );
                _y = (_startY! + deltaY).clamp(
                  0.0,
                  MediaQuery.of(context).size.height - _buttonSize,
                );
              });
            },
            onPanEnd: (_) {
              _isDragging = false;
              if (_x > MediaQuery.of(context).size.width / 2) {
                setState(
                  () => _x = MediaQuery.of(context).size.width - _buttonSize,
                );
              } else {
                setState(() => _x = 0);
              }
            },
            child: ScaleTransition(
              scale: _breathAnimation,
              child: Container(
                width: _buttonSize,
                height: _buttonSize,
                decoration: BoxDecoration(
                  gradient: InspectorGradients.primary,
                  borderRadius: BorderRadius.circular(_buttonSize / 2),
                  boxShadow: [
                    BoxShadow(
                      color: InspectorColors.primary.withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    Icons.bug_report_rounded,
                    color: InspectorColors.textPrimary,
                    size: InspectorDimensions.floatingButtonIconSize,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建展开的检查器面板 / Build expanded inspector panel
  Widget _buildExpandedPanel() {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: () {
          setState(() => _isExpanded = false);
        },
        child: Container(
          // 全透明遮罩，不阻挡背景显示 / Fully transparent overlay, doesn't block background
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: InspectorPanel(
                onClose: () {
                  setState(() => _isExpanded = false);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 切换检查器面板展开状态 / Toggle inspector panel expansion state
  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }
}
