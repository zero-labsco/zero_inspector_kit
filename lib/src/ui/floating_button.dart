import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
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

class _FloatingInspectorButtonState extends State<FloatingInspectorButton> {
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

  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      Future.delayed(const Duration(seconds: 1), () {
        setState(() => _isVisible = true);
      });
    }
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
      left: _isExpanded ? -50 : _x,
      top: _y,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
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
                MediaQuery.of(context).size.width - 50,
              );
              _y = (_startY! + deltaY).clamp(
                0.0,
                MediaQuery.of(context).size.height - 50,
              );
            });
          },
          onPanEnd: (_) {
            _isDragging = false;
            if (_x > MediaQuery.of(context).size.width / 2) {
              setState(() => _x = MediaQuery.of(context).size.width - 50);
            } else {
              setState(() => _x = 0);
            }
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                _isExpanded ? Icons.close : Icons.bug_report,
                color: Colors.white,
                size: 24,
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