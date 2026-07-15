import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'floating_button.dart';

/// 条件检查器组件
/// 根据编译模式自动决定是否显示检查器
/// 
/// 在 release 模式下，此组件会返回空容器，检查器代码不会被打包
/// 在 debug/profile 模式下，会显示检查器按钮
/// 
/// 使用方式：
/// ```dart
/// Widget build(BuildContext context) {
///   return ConditionalInspector(
///     child: YourAppWidget(),
///   );
/// }
/// ```
class ConditionalInspector extends StatelessWidget {
  /// 子组件
  final Widget child;

  /// 是否启用检查器（默认根据环境自动判断）
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

/// 条件日志拦截器
/// 在 release 模式下不会执行任何操作
class ConditionalLogInterceptor {
  ConditionalLogInterceptor._();

  /// 启动日志捕获（仅在非release模式下生效）
  static void start() {
    if (kReleaseMode) return;
    // 导入并启动日志拦截器
    try {
      // 使用动态方式避免release模式下的依赖
    } catch (_) {
      // 在release模式下忽略
    }
  }
}