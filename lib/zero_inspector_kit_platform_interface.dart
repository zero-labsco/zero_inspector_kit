import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zero_inspector_kit_method_channel.dart';

abstract class ZeroInspectorKitPlatform extends PlatformInterface {
  /// Constructs a ZeroInspectorKitPlatform.
  ZeroInspectorKitPlatform() : super(token: _token);

  static final Object _token = Object();

  static ZeroInspectorKitPlatform _instance = MethodChannelZeroInspectorKit();

  /// The default instance of [ZeroInspectorKitPlatform] to use.
  ///
  /// Defaults to [MethodChannelZeroInspectorKit].
  static ZeroInspectorKitPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [ZeroInspectorKitPlatform] when
  /// they register themselves.
  static set instance(ZeroInspectorKitPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
