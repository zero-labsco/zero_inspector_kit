import 'package:flutter/material.dart';

import '../theme/inspector_theme.dart';

/// 单个检查器 Tab 的错误边界 / Per-tab error boundary
///
/// 子组件在构建期抛出异常时，仅该 Tab 显示局部错误卡片（而非红色全屏），
/// 且不会拖垮整个面板（其余 Tab、头部、标签栏均正常）。
/// When a child throws during build, only that tab shows a contained error card
/// (instead of a red full-screen error), and the rest of the panel keeps working.
///
/// 实现说明：Flutter 每个 Element 会在自身 performRebuild 中把“构建异常”吞掉并
/// 替换成默认红色 ErrorWidget，因此父级无法用 try/catch 捕获子组件的构建异常。
/// 唯一能拦截的钩子是全局的 [ErrorWidget.builder]。这里在边界自己的 performRebuild
/// 期间临时替换 [ErrorWidget.builder]（finally 中还原），让子树内的构建异常被
/// 渲染成该边界的错误卡片，而不影响边界外的错误展示。
/// Implementation note: every Flutter Element swallows its own build error and
/// replaces it with the default red ErrorWidget inside performRebuild, so a parent
/// can't catch a child's build error via try/catch. The only hook is the global
/// [ErrorWidget.builder]. We temporarily swap it for the duration of this boundary's
/// own rebuild (restored in `finally`), so build errors inside the subtree render as
/// this boundary's card without affecting errors elsewhere.
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
  @override
  Widget build(BuildContext context) => widget.child;

  /// 局部错误卡片：提示出错并可重试 / Contained error card: shows the failure and offers a retry
  Widget _buildErrorCard(Object? error) {
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
              error?.toString() ?? '',
              style: TextStyle(
                color: InspectorColors.textSecondary,
                fontSize: 11,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() {}),
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

/// 覆写 [performRebuild]：在边界自身重建期间临时接管 [ErrorWidget.builder] 与
/// [FlutterError.onError]，把子树内的构建异常渲染成该边界的错误卡片，并“吞掉”
/// 对应上报（真正兜底，而非只是换张红色 ErrorWidget 仍抛错）。finally 中还原原函数。
/// Overrides [performRebuild]: while this boundary rebuilds, temporarily take over
/// [ErrorWidget.builder] and [FlutterError.onError] so build errors inside the
/// subtree render as this boundary's card AND the error report is swallowed
/// (truly contained, instead of just swapping the red ErrorWidget while still
/// throwing). Both hooks are restored in `finally`.
///
/// 构建是自顶向下、同步深度的，因此用静态栈记录“当前正在构建的边界”，
/// 子组件抛错时栈顶即出错点所在的最内层边界（其子树的错误卡片）。
/// Builds are synchronous and depth-first, so a static stack tracks the boundary
/// currently being rebuilt; when a child throws, the top of the stack is the
/// innermost boundary (whose card should be shown).
class InspectorErrorBoundaryElement extends StatefulElement {
  InspectorErrorBoundaryElement(InspectorErrorBoundary super.widget);

  /// 当前正在构建的边界栈（同一 UI 线程、同步构建，无需加锁）。
  /// Stack of boundaries currently being rebuilt (single UI thread, sync builds).
  static final List<InspectorErrorBoundaryElement> _active = [];

  @override
  void performRebuild() {
    final previousBuilder = ErrorWidget.builder;
    final previousOnError = FlutterError.onError;
    _active.add(this);
    ErrorWidget.builder = (details) {
      if (_active.isNotEmpty) {
        // 用最内层（栈顶）边界渲染卡片 / Use the innermost active boundary's card.
        final state = _active.last.state as _InspectorErrorBoundaryState;
        return state._buildErrorCard(details.exception);
      }
      // 边界外的错误走原 builder（可能是应用自定义的 ErrorWidget.builder）。
      // Errors outside any boundary fall back to the original builder.
      return previousBuilder(details);
    };
    // 边界内的构建异常已被卡片兜底，不再上报，避免控制台/测试噪音。
    // Build errors inside a boundary are contained by the card; don't report them.
    FlutterError.onError = (details) {
      if (_active.isNotEmpty) return;
      previousOnError?.call(details);
    };
    try {
      super.performRebuild();
    } finally {
      _active.removeLast();
      ErrorWidget.builder = previousBuilder;
      FlutterError.onError = previousOnError;
    }
  }
}
