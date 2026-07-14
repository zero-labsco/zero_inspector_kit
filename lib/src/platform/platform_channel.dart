import 'package:flutter/services.dart';

/// 平台通道服务
/// 用于与原生代码通信，获取平台相关信息和原生日志
class PlatformChannel {
  /// 方法通道名称
  static const MethodChannel _channel = MethodChannel('zero_inspector_kit');

  /// 获取平台版本
  static Future<String?> getPlatformVersion() async {
    return await _channel.invokeMethod<String>('getPlatformVersion');
  }

  /// 获取原生日志
  /// [limit] 返回日志条数限制，默认100
  static Future<List<String>?> getNativeLogs({int limit = 100}) async {
    try {
      return await _channel.invokeMethod<List<String>>('getNativeLogs', {
        'limit': limit,
      });
    } catch (_) {
      return null;
    }
  }

  /// 开始监听原生日志
  static Future<void> startNativeLogListener() async {
    try {
      await _channel.invokeMethod<void>('startNativeLogListener');
    } catch (_) {}
  }

  /// 停止监听原生日志
  static Future<void> stopNativeLogListener() async {
    try {
      await _channel.invokeMethod<void>('stopNativeLogListener');
    } catch (_) {}
  }
}