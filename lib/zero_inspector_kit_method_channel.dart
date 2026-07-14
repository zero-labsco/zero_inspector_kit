import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'zero_inspector_kit_platform_interface.dart';

/// An implementation of [ZeroInspectorKitPlatform] that uses method channels.
class MethodChannelZeroInspectorKit extends ZeroInspectorKitPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('zero_inspector_kit');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }
}
