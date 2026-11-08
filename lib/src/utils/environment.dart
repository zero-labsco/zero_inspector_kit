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
    // 必须带 const：`String.fromEnvironment` 只在常量上下文里读取 dart-define，
    // 否则运行时返回空字符串，--dart-define=INSPECTOR_ENABLED=... 完全失效。
    // MUST be const: `String.fromEnvironment` only reads a dart-define in a
    // constant context; otherwise it evaluates to '' at runtime and the flag
    // silently does nothing.
    const String raw = String.fromEnvironment('INSPECTOR_ENABLED');
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
    // 同上：没有 const 时这个 getter 恒为 false，宿主显式关闭的开关
    // 在 debug / profile 下从来没真正生效过。
    // Same as above: without const this getter was always false, so the
    // explicit opt-out never actually worked in debug / profile builds.
    const String raw = String.fromEnvironment('INSPECTOR_ENABLED');
    return raw.isNotEmpty && raw.toLowerCase() == 'false';
  }

  /// Compile-time inspector mode. Controlled by `--dart-define=INSPECTOR_MODES`.
  /// - `'debug'` (default): enabled in debug/profile, tree-shaken out of release.
  /// - `'all'`: also bundled and enabled in release (AOT) builds
  ///   (used for QA / internal test builds).
  /// Falls back to `'debug'` when the flag is unset.
  /// 编译期检查器模式，由 `--dart-define=INSPECTOR_MODES` 控制。
  /// - `'debug'`（默认）：debug/profile 启用，release 下被 tree-shake 剔除。
  /// - `'all'`：release（AOT）构建也同样打进并启用（用于 QA / 内部测试）。
  /// 未设置时回退为 `'debug'`。
  static const String inspectorModes = String.fromEnvironment(
    'INSPECTOR_MODES',
    defaultValue: 'debug',
  );

  /// Whether the inspector is allowed to run in a release (AOT) build.
  /// Compile-time constant so the inspector code is tree-shaken out by default
  /// and only included when explicitly opted in via `INSPECTOR_MODES=all`.
  /// 是否允许在 release（AOT）构建中运行检查器。编译期常量，所以默认会被摇树剔除，
  /// 仅当显式 `INSPECTOR_MODES=all` 时才被打进包。
  static bool get isInspectorAllowedInRelease => inspectorModes == 'all';

  /// 当前构建是否必须**完全跳过**检查器（默认 release / AOT 且未开
  /// `INSPECTOR_MODES=all`）。/ Whether the current build must skip the
  /// inspector entirely (default release / AOT without `INSPECTOR_MODES=all`).
  ///
  /// 刻意写成 `const` 而非 getter：AOT 需要把 `init()` / `wrapApp()` /
  /// `runAppWithInspector()` 里的判断折叠成常量，才能摇掉后面不可达的采集代码。
  /// 注意 pubspec 声明的原生插件依赖仍由平台构建链接，因此这里**不承诺**
  /// release 包体积零影响。
  /// Deliberately a `const` (not a getter) so AOT can constant-fold the checks
  /// in `init()` / `wrapApp()` / `runAppWithInspector()` and tree-shake the
  /// unreachable collection code. Native plugin dependencies declared in
  /// `pubspec.yaml` are still linked by the platform build, so this is NOT a
  /// promise of zero binary-size impact.
  static const bool isInspectorDisabledInCurrentBuild =
      kReleaseMode && inspectorModes != 'all';

  /// 是否应跳过**所有**采集写入：编译期 release gate，或宿主显式传入
  /// `--dart-define=INSPECTOR_ENABLED=false`。
  /// Whether **all** collection writes must be skipped: the compile-time
  /// release gate, or an explicit `--dart-define=INSPECTOR_ENABLED=false`.
  ///
  /// 入口层（[ZeroInspectorKit.init]）、UI 层与服务层共用此判断，避免各处
  /// 只检查其中一项而出现「init 被关掉、手动埋点仍能写内存」的缺口。
  /// Shared by the entry points, the UI layer and the service singletons so
  /// no call site can check only one of the two conditions and leave a hole
  /// (e.g. init() disabled but manual instrumentation still writing memory).
  ///
  /// 首项是 `const`：默认 release 下 AOT 会把整个 `||` 折叠为 true 并摇掉
  /// 调用点后续代码，第二项只有在非 release 构建里才有机会求值。
  /// The first operand is `const`, so in a default release build AOT folds
  /// the whole `||` to true and tree-shakes the code behind the caller; the
  /// second operand is only ever evaluated in non-release builds.
  static bool get isCollectionDisabled =>
      isInspectorDisabledInCurrentBuild || isInspectorExplicitlyDisabled;

  /// 是否为调试模式 / Whether in debug mode
  static bool get isDebug => kDebugMode;
}
