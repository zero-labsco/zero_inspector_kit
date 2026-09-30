import 'package:flutter/foundation.dart';

/// 环境工具类 / Environment utility class
/// 提供编译时配置和环境判断功能 / Provides compile-time configuration and environment judgment
class InspectorEnvironment {
  InspectorEnvironment._();

  /// 是否为生产环境 / Whether in production environment
  /// 通过编译参数 --dart-define=INSPECTOR_ENABLED=false 控制 / Controlled by compile parameter --dart-define=INSPECTOR_ENABLED=false
  ///
  /// 未指定时沿用各模式默认（release/profile 关闭、debug 开启）；显式指定时仅
  /// `false`（任意大小写）关闭，其余视作开启。此前用 [bool.fromEnvironment]，
  /// 无法区分“未设置”与“显式 false”，导致 debug 下 `--dart-define=...=false`
  /// 永远被后续 `return true` 覆盖而失效。
  /// When unspecified, follows the per-mode default (off in release/profile, on in
  /// debug). When explicitly set, only `false` (any case) disables it; anything
  /// else enables. The previous [bool.fromEnvironment] could not tell "unset" from
  /// "explicit false", so `--dart-define=...=false` in debug was always overridden.
  static bool get isInspectorEnabled {
    final raw = String.fromEnvironment('INSPECTOR_ENABLED');
    if (raw.isEmpty) return kDebugMode;
    return raw.toLowerCase() != 'false';
  }

  /// 是否为调试模式 / Whether in debug mode
  static bool get isDebug => kDebugMode;
}
