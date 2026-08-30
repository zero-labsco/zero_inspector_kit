import 'package:flutter/material.dart';

import '../theme/inspector_theme.dart';

/// 单个检查器 Tab 的错误边界 / Per-tab error boundary
///
/// 子组件在构建期抛出异常时，仅该 Tab 显示局部错误卡片（而非红色全屏），
/// 且不会拖垮整个面板（其余 Tab、头部、标签栏均正常）。
/// When a child throws during build, only that tab shows a contained error card
/// (instead of a red full-screen error), and the rest of the panel keeps working.
///
/// 实现说明：Flutter 的 build 异常无法用普通 try/catch 捕获，必须通过
/// 覆写 Element 的 [performRebuild] 在框架层拦截。
/// Implementation note: a build-time exception can't be caught by a plain
/// try/catch, so we override [performRebuild] at the Element level to trap it.
class InspectorErrorBoundary extends StatefulWidget {
  /// 被包裹的子组件 / The wrapped child
  final Widget child;

  /// 该边界的标签（用于错误卡片展示，如 Tab 名称）/ Label shown on the error card (e.g. tab name)
  final String label;

  const InspectorErrorBoundary({
    super.key,
    required this.child,
    this.label = 'panel',
  });

  @override
  State<InspectorErrorBoundary> createState() => _InspectorErrorBoundaryState();

  @override
  InspectorErrorBoundaryElement createElement() =>
      InspectorErrorBoundaryElement(this);
}

/// 错误边界的内部状态 / Internal state of the error boundary
class _InspectorErrorBoundaryState extends State<InspectorErrorBoundary> {
  /// 是否已进入错误态 / Whether an error state is active
  bool _hasError = false;

  /// 捕获到的异常 / The captured exception
  Object? _error;

  @override
  Widget build(BuildContext context) {
    if (_hasError) return _buildErrorCard();
    return widget.child;
  }

  /// 局部错误卡片：提示出错并可重试 / Contained error card: shows the failure and offers a retry
  Widget _buildErrorCard() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: InspectorColors.accent,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.label} 出错 / ${widget.label} failed',
              style: TextStyle(
                color: InspectorColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _error?.toString() ?? '',
              style: TextStyle(
                color: InspectorColors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _hasError = false),
              child: Text(
                'Retry',
                style: TextStyle(color: InspectorColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 覆写 [performRebuild] 以在 Element 层捕获子组件构建异常。
/// Overrides [performRebuild] to trap child build exceptions at the Element level.
class InspectorErrorBoundaryElement extends StatefulElement {
  InspectorErrorBoundaryElement(InspectorErrorBoundary super.widget);

  @override
  void performRebuild() {
    final state = this.state as _InspectorErrorBoundaryState;
    if (state._hasError) {
      super.performRebuild();
      return;
    }
    try {
      super.performRebuild();
    } catch (error, _) {
      // 捕获构建期异常，切换为错误卡片，避免整面板崩溃。
      // Trap the build error and switch to the error card instead of crashing.
      state._hasError = true;
      state._error = error;
      super.performRebuild();
    }
  }
}
