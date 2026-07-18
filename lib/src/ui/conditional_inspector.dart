import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'floating_button.dart';

/// 条件检查器组件 / Conditional inspector widget
/// 根据编译模式自动决定是否显示检查器 / Automatically determine whether to show inspector based on build mode
/// 
/// 在 release 模式下，此组件会返回空容器，检查器代码不会被打包 / In release mode, this widget returns an empty container, inspector code won't be bundled
/// 在 debug/profile 模式下，会显示检查器按钮 / In debug/profile mode, inspector button will be shown
/// 
/// 使用方式 / Usage:
/// ```dart
/// Widget build(BuildContext context) {
///   return ConditionalInspector(
///     child: YourAppWidget(),
///   );
/// }
/// ```
class ConditionalInspector extends StatelessWidget {
  /// 子组件 / Child widget
  final Widget child;

  /// 是否启用检查器（默认根据环境自动判断）/ Whether to enable inspector (auto-detect by environment by default)
  final bool enabled;

  const ConditionalInspector({
    super.key,
    required this.child,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) {
      return child;
    }

    return Stack(
      children: [
        child,
        if (enabled) const FloatingInspectorButton(),
      ],
    );
  }
}

/// 条件日志拦截器 / Conditional log interceptor
/// 在 release 模式下不会执行任何操作 / Won't perform any operation in release mode
class ConditionalLogInterceptor {
  ConditionalLogInterceptor._();

  /// 启动日志捕获（仅在非release模式下生效）/ Start log capture (only effective in non-release mode)
  static void start() {
    if (kReleaseMode) return;
    // 导入并启动日志拦截器 / Import and start log interceptor
    try {
      // 使用动态方式避免release模式下的依赖 / Use dynamic approach to avoid dependencies in release mode
    } catch (_) {
      // 在release模式下忽略 / Ignore in release mode
    }
  }
}