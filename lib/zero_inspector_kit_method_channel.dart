import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'zero_inspector_kit_platform_interface.dart';

/// 使用MethodChannel实现的平台接口 / Platform interface implementation using MethodChannel
/// 通过Flutter MethodChannel与原生平台通信 / Communicate with native platform via Flutter MethodChannel
class MethodChannelZeroInspectorKit extends ZeroInspectorKitPlatform {
  /// 用于与原生平台交互的MethodChannel / The method channel used to interact with the native platform
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

  @override
  /// 获取进程级内存信息 / Get process-level memory info
  Future<Map<String, dynamic>?> getProcessMemoryInfo() async {
    try {
      final result = await methodChannel.invokeMethod<Map>(
        'getProcessMemoryInfo',
      );
      if (result == null) return null;
      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (_) {
      return null;
    }
  }
}
