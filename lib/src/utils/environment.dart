import 'package:flutter/foundation.dart';

/// 环境工具类
/// 提供编译时配置和环境判断功能
class InspectorEnvironment {
  InspectorEnvironment._();

  /// 是否为生产环境
  /// 通过编译参数 --dart-define=INSPECTOR_ENABLED=false 控制
  static bool get isInspectorEnabled {
    final enabled = bool.fromEnvironment('INSPECTOR_ENABLED');
    if (enabled) return true;
    if (!kDebugMode) return false;
    return true;
  }

  /// 是否为调试模式
  static bool get isDebug => kDebugMode;
}
