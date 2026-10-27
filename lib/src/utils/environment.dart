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

  /// 是否被 `--dart-define=INSPECTOR_ENABLED=false` **显式**关闭。
  /// Whether it was **explicitly** disabled via
  /// `--dart-define=INSPECTOR_ENABLED=false`.
  ///
  /// 与 [isInspectorEnabled] 的区别：后者在未设置时按模式返回默认值（release /
  /// profile 关闭、debug 开启），而这里只在"真的写了 false"时为真。需要在
  /// profile 下也保留默认行为、同时又让 dart-define 生效的调用点（例如
  /// [ConditionalInspector]）应使用本 getter。
  /// Differs from [isInspectorEnabled]: that one falls back to the per-mode
  /// default when unset (off in release/profile, on in debug), while this is true
  /// only when `false` was really passed. Call sites that must keep the profile
  /// default yet honor the dart-define (e.g. [ConditionalInspector]) should use
  /// this getter.
  static bool get isInspectorExplicitlyDisabled {
    final raw = String.fromEnvironment('INSPECTOR_ENABLED');
    return raw.isNotEmpty && raw.toLowerCase() == 'false';
  }

  /// 是否为调试模式 / Whether in debug mode
  static bool get isDebug => kDebugMode;
}
