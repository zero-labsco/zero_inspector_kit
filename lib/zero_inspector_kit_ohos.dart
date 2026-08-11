import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'zero_inspector_kit_platform_interface.dart';

/// OpenHarmony (HarmonyOS) 平台接口实现 / OpenHarmony (HarmonyOS) platform implementation
///
/// 通过 MethodChannel 与 `ohos/src/main/ets/.../ZeroInspectorKitPlugin.ets` 通信，
/// channel 名与安卓/iOS 保持一致（`zero_inspector_kit`）。
/// Communicates with `ohos/src/main/ets/.../ZeroInspectorKitPlugin.ets` over the
/// same MethodChannel name as Android/iOS (`zero_inspector_kit`).
///
/// 插件核心能力（网络拦截 `HttpOverrides`、内存/VM Service、FPS `addTimingsCallback`）
/// 为纯 Dart，跨平台共用；本类仅承载需要在原生侧落地的鸿蒙专属方法（如平台版本探测、
/// 未来可能的原生内存/窗口能力）。当前复用 MethodChannel 默认契约，保留扩展点。
/// The plugin's core capabilities (network interception via `HttpOverrides`, memory
/// via VM Service, FPS via `addTimingsCallback`) are pure Dart and shared across
/// platforms; this class only hosts OHOS-specific methods that must land natively
/// (e.g. platform version probing, and future native memory/window hooks). It reuses
/// the default MethodChannel contract and keeps extension points open.
class ZeroInspectorKitOhos extends ZeroInspectorKitPlatform {
  /// 用于与原生平台交互的 MethodChannel / The method channel used to interact with the native side
  @visibleForTesting
  final methodChannel = const MethodChannel('zero_inspector_kit');

  @override
  /// 获取平台版本信息 / Get platform version
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
