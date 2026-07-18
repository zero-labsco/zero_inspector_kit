import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'zero_inspector_kit_method_channel.dart';

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

  /// 获取平台版本信息 / Get platform version
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
