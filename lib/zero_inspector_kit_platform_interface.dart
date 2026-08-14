import 'package:flutter/foundation.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zero_inspector_kit_method_channel.dart';
import 'zero_inspector_kit_ohos.dart';

/// ZeroInspectorKit平台接口基类 / ZeroInspectorKit platform interface base class
/// 定义平台相关的抽象方法，各平台实现需继承此类 / Define platform-related abstract methods, platform implementations must extend this class
abstract class ZeroInspectorKitPlatform extends PlatformInterface {
  /// 构造ZeroInspectorKitPlatform实例 / Constructs a ZeroInspectorKitPlatform
  ZeroInspectorKitPlatform() : super(token: _token);

  /// 接口标识Token，用于验证平台实现的合法性 / Interface token for verifying platform implementation validity
  static final Object _token = Object();

  /// 默认的平台实例，使用MethodChannel实现 / Default platform instance using MethodChannel implementation
  static ZeroInspectorKitPlatform _instance = MethodChannelZeroInspectorKit();

  /// 获取默认的平台实例 / Get the default instance of [ZeroInspectorKitPlatform]
  /// 默认使用 [MethodChannelZeroInspectorKit] / Defaults to [MethodChannelZeroInspectorKit]
  static ZeroInspectorKitPlatform get instance => _instance;

  /// 设置平台实例，各平台实现应在注册时设置自己的实现类 / Set platform instance, platform-specific implementations should set their own class when registering
  static set instance(ZeroInspectorKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 当前是否运行在 OpenHarmony (HarmonyOS) 平台 / Whether currently running on OpenHarmony (HarmonyOS)
  ///
  /// 鸿蒙定制 Flutter 分支给 [TargetPlatform] 新增了 `ohos` 枚举值，但官方
  /// Flutter 没有该枚举。为避免在官方 Flutter 下编译报错，这里不直接引用
  /// `TargetPlatform.ohos`，而是运行时按字符串判断（鸿蒙分支的枚举 toString
  /// 会包含 "ohos"）。官方 Flutter 下该判断恒为 false，不影响安卓/iOS。
  /// The OHOS custom Flutter fork adds an `ohos` value to [TargetPlatform], which the
  /// official Flutter lacks. To avoid a compile error on official Flutter, this does
  /// not reference `TargetPlatform.ohos` directly; instead it checks the runtime
  /// string (the OHOS fork's enum toString contains "ohos"). On official Flutter this
  /// is always false, leaving Android/iOS unaffected.
  static bool get isOhos =>
      defaultTargetPlatform.toString().toLowerCase().contains('ohos');

  /// 按当前运行平台注册默认实现 / Register the default implementation for the current platform
  ///
  /// 在 `ZeroInspectorKit.init()` 早期调用，确保 ohos 走 [ZeroInspectorKitOhos]、
  /// 其余平台（安卓/iOS/桌面/Web）走 [MethodChannelZeroInspectorKit]。
  /// 仅当尚未显式设置过实例（仍是默认 MethodChannel 实现）时才生效，
  /// 避免覆盖测试或宿主自定义的实例。
  /// Called early in `ZeroInspectorKit.init()` so ohos uses [ZeroInspectorKitOhos]
  /// while Android/iOS/desktop/Web keep [MethodChannelZeroInspectorKit]. Only applies
  /// when no instance has been explicitly set (still the default MethodChannel impl),
  /// leaving tests/host overrides intact.
  static void ensurePlatformImplementation() {
    // 仅当仍停留在默认实例时才按平台分流，保护测试/宿主的自定义实例
    // Only branch while still on the default instance, protecting custom test/host instances
    if (_instance is MethodChannelZeroInspectorKit && isOhos) {
      _instance = ZeroInspectorKitOhos();
    }
  }

  /// 获取平台版本信息 / Get platform version
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  /// 获取进程级内存信息 / Get process-level memory info
  ///
  /// 通过原生 Platform Channel 调用获取进程级内存数据。
  /// 鸿蒙(OpenHarmony)返回真实的 VmRSS/rss；安卓/iOS 返回对应平台分项。
  /// 平台不支持时返回 null。
  /// Calls the native Platform Channel to get process-level memory data. OHOS
  /// returns the real VmRSS/rss; Android/iOS return their respective breakdown.
  /// Returns null when unsupported.
  Future<Map<String, dynamic>?> getProcessMemoryInfo() {
    throw UnimplementedError('getProcessMemoryInfo() has not been implemented.');
  }
}
