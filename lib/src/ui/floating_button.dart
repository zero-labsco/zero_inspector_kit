import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/alert_service.dart';
import 'theme/inspector_theme.dart';
import 'inspector_panel.dart';

/// 边缘吸附方向 / Dock side
enum _DockSide { none, left, right }

/// 悬浮检查器按钮 / Floating inspector button
///
/// 可拖动，松手后自动吸附到最近边缘并"收入"边缘（仅露出小部分）。
/// 收入状态点击露出部分会自动平滑拉出到完整可见，再次点击才打开面板。
/// Draggable; auto-docks to nearest edge on release and "tucks into" the edge
/// (only a small portion peeks out). Tapping the peek smoothly pulls it out
/// to fully visible; tap again to open the panel.
///
/// 支持两种使用模式：
/// 1. 回调模式（推荐）：通过 [onPanelToggle] 回调，面板由外部管理
/// 2. 独立模式：不提供 [onPanelToggle]，内部自动管理面板
/// Supports two usage modes:
/// 1. Callback mode (recommended): via [onPanelToggle] callback, panel managed externally
/// 2. Standalone mode: no [onPanelToggle], panel managed internally
///
/// 在生产环境（release模式）下，此组件会返回空容器，不会打包检查器代码 / In production environment (release mode), this widget returns an empty container, inspector code won't be bundled
class FloatingInspectorButton extends StatefulWidget {
  /// 是否启用检查器按钮 / Whether to enable inspector button
  /// 默认根据环境自动判断：debug模式启用，release模式禁用 / Auto-detect by environment by default: enabled in debug mode, disabled in release mode
  final bool enabled;

  /// 面板显示/隐藏回调（可选）/ Panel toggle callback (optional)
  /// 点击按钮时触发，由外部决定如何显示面板 / Triggered when button is clicked, external decides how to show panel
  /// 如果为 null，则内部自动管理面板 / If null, manages panel internally
  final VoidCallback? onPanelToggle;

  const FloatingInspectorButton({
    super.key,
    this.enabled = true,
    this.onPanelToggle,
  });

  @override
  State<FloatingInspectorButton> createState() =>
      _FloatingInspectorButtonState();
}

class _FloatingInspectorButtonState extends State<FloatingInspectorButton>
    with TickerProviderStateMixin {
  /// 按钮X坐标（左上角，可为负或在屏幕外表示收入边缘）/ Button X coordinate (top-left; may be negative/off-screen when docked)
  double _x = 0;

  /// 按钮Y坐标 / Button Y coordinate
  double _y = 200;

  /// 内部模式下面板是否展开 / Whether panel is expanded in standalone mode
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

  /// 边缘吸附动画控制器 / Dock animation controller
  late final AnimationController _dockController;

  /// 当前运行的吸附动画 / Currently running dock animation
  Animation<double>? _dockAnim;

  /// 当前吸附方向 / Current dock side
  _DockSide _dockSide = _DockSide.none;

  /// 收入边缘时露出的像素 / Peek size (px) when tucked into edge
  final double _dockedPeekSize = 24.0;

  /// 按钮尺寸 / Button size
  final double _buttonSize = InspectorDimensions.floatingButtonSize;

  /// 是否已吸附到边缘（不可点击）/ Whether docked at edge (not clickable)
  bool get _isDocked => _dockSide != _DockSide.none;

  /// 是否使用回调模式 / Whether using callback mode
  bool get _usesCallback => widget.onPanelToggle != null;

  @override
  void initState() {
    super.initState();
    AlertService.instance.unreadCount.addListener(_onUnreadChanged);
    _breathController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _breathAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _dockController = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
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
    AlertService.instance.unreadCount.removeListener(_onUnreadChanged);
    _breathController.dispose();
    _dockController.dispose();
    super.dispose();
  }

  /// 未读告警数变化 → 触发重绘红点 / Unread alert change → repaint red dot
  void _onUnreadChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();
    if (!widget.enabled || !_isVisible) return const SizedBox.shrink();

    return Stack(
      children: [
        // 独立模式下的面板 / Panel in standalone mode
        if (!_usesCallback && _isExpanded) _buildExpandedPanel(),
        _buildDraggableButton(),
      ],
    );
  }

  /// 构建可拖动的悬浮按钮 / Build draggable floating button
  Widget _buildDraggableButton() {
    return Positioned(
      left: _x,
      top: _y,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: _usesCallback ? 1 : (_isExpanded ? 0 : 1),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: _usesCallback ? 1 : (_isExpanded ? 0.5 : 1),
          child: GestureDetector(
            onTap: _handleTap,
            behavior: HitTestBehavior.opaque,
            onPanStart: _handlePanStart,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
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
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        _dockSide == _DockSide.left
                            ? Icons.chevron_right_rounded
                            : _dockSide == _DockSide.right
                            ? Icons.chevron_left_rounded
                            : Icons.bug_report_rounded,
                        color: InspectorColors.textPrimary,
                        size: InspectorDimensions.floatingButtonIconSize,
                      ),
                      if (AlertService.instance.unreadCount.value > 0)
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 12,
                              minHeight: 12,
                            ),
                            child: Text(
                              AlertService.instance.unreadCount.value
                                  .clamp(0, 99)
                                  .toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 拖动开始 / Handle drag start
  void _handlePanStart(DragStartDetails details) {
    _isDragging = true;
    _dragStart = details.globalPosition;
    // 取消进行中的吸附动画 / Cancel running dock animation
    _dockController.stop();
    _dockAnim = null;
    // 解除吸附状态，_x 保持当前实际位置 / Undock; keep _x at its actual current position
    setState(() => _dockSide = _DockSide.none);
    _startX = _x;
    _startY = _y;
  }

  /// 拖动更新 / Handle drag update
  void _handlePanUpdate(DragUpdateDetails details) {
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
  }

  /// 拖动结束，吸附到最近边缘并收入 / Handle drag end, dock to nearest edge
  void _handlePanEnd(DragEndDetails _) {
    _isDragging = false;
    final screenWidth = MediaQuery.of(context).size.width;
    final centerX = _x + _buttonSize / 2;

    final _DockSide targetSide;
    final double targetX;
    if (centerX < screenWidth / 2) {
      targetSide = _DockSide.left;
      // 左边收入，露出 peek / Tuck into left, peek out
      targetX = -_buttonSize + _dockedPeekSize;
    } else {
      targetSide = _DockSide.right;
      // 右边收入，露出 peek / Tuck into right, peek out
      targetX = screenWidth - _dockedPeekSize;
    }

    _animateTo(targetX, targetSide);
  }

  /// 执行吸附动画 / Run dock animation
  void _animateTo(double targetX, _DockSide side) {
    final startX = _x;
    if ((startX - targetX).abs() < 0.5) {
      setState(() {
        _x = targetX;
        _dockSide = side;
      });
      return;
    }
    _dockAnim =
        Tween<double>(begin: startX, end: targetX).animate(
          CurvedAnimation(parent: _dockController, curve: Curves.easeOutCubic),
        )..addListener(() {
          setState(() {
            _x = _dockAnim!.value;
            _dockSide = side;
          });
        });
    _dockController.forward(from: 0);
  }

  /// 处理点击事件 / Handle tap event
  ///
  /// 吸附状态：点击露出部分 → 平滑拉出到完整可见（不打开面板，避免误触）
  /// Docked: tap the peek → smoothly pull out to fully visible (panel not opened, avoids accidental open)
  /// 完整状态：点击 → 打开面板
  /// Fully visible: tap → open panel
  void _handleTap() {
    if (_isDocked) {
      _pullOut();
      return;
    }
    if (_usesCallback) {
      widget.onPanelToggle?.call();
    } else {
      _togglePanelInternal();
    }
    // 打开面板即视为已读 / Opening the panel marks alerts as read
    AlertService.instance.clearUnread();
  }

  /// 把小球从吸附状态平滑拉出到完整可见位置
  /// Smoothly pull the button out from docked state to fully visible position
  void _pullOut() {
    final screenWidth = MediaQuery.of(context).size.width;
    // 紧贴当前吸附边的完整可见位置 / Fully visible position against current dock side
    final targetX = _dockSide == _DockSide.left
        ? 0.0
        : screenWidth - _buttonSize;
    _animateTo(targetX, _DockSide.none);
  }

  /// 独立模式下切换面板 / Toggle panel in standalone mode
  void _togglePanelInternal() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  /// 构建展开的检查器面板（独立模式）/ Build expanded inspector panel (standalone mode)
  Widget _buildExpandedPanel() {
    return Positioned(
      left: 0,
      top: 0,
      right: 0,
      bottom: 0,
      child: GestureDetector(
        onTap: _togglePanelInternal,
        child: Container(
          // 全透明遮罩，不阻挡背景显示 / Fully transparent overlay, doesn't block background
          color: Colors.transparent,
          child: Center(
            child: GestureDetector(
              onTap: () {},
              child: InspectorPanel(onClose: _togglePanelInternal),
            ),
          ),
        ),
      ),
    );
  }
}
