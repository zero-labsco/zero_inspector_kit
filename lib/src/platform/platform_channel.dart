import 'package:flutter/services.dart';

/// 平台通道服务 / Platform channel service
/// 用于与原生代码通信，获取平台相关信息和原生日志 / Used for communication with native code, get platform info and native logs
class PlatformChannel {
  /// 方法通道名称 / Method channel name
  static const MethodChannel _channel = MethodChannel('zero_inspector_kit');

  /// 获取平台版本 / Get platform version
  static Future<String?> getPlatformVersion() async {
    return await _channel.invokeMethod<String>('getPlatformVersion');
  }

  /// 获取原生日志 / Get native logs
  /// [limit] 返回日志条数限制，默认100 / Return log count limit, default 100
  static Future<List<String>?> getNativeLogs({int limit = 100}) async {
    try {
      return await _channel.invokeMethod<List<String>>('getNativeLogs', {
        'limit': limit,
      });
    } catch (_) {
      return null;
    }
  }

  /// 开始监听原生日志 / Start native log listener
  static Future<void> startNativeLogListener() async {
    try {
      await _channel.invokeMethod<void>('startNativeLogListener');
    } catch (_) {}
  }

  /// 停止监听原生日志 / Stop native log listener
  static Future<void> stopNativeLogListener() async {
    try {
      await _channel.invokeMethod<void>('stopNativeLogListener');
    } catch (_) {}
  }

  /// 获取进程级内存信息 / Get process-level memory info
  ///
  /// 通过原生 Platform Channel 调用 Android 的 Debug.MemoryInfo 或 iOS 的 mach task_info，
  /// 获取进程级内存数据（不依赖 VM Service，在真机上 100% 可用）。
  /// Calls Android's Debug.MemoryInfo or iOS's mach task_info via native Platform Channel,
  /// gets process-level memory data (doesn't depend on VM Service, 100% available on real devices).
  ///
  /// 返回 Map 包含以下字段（单位：字节）/ Returns Map with following fields (in bytes):
  /// - rss:                   进程 RSS（Android: Process.myRss(), iOS: resident_size）
  /// - totalPss:              总 PSS（仅 Android / Android only）
  /// - dalvikPss:             Dalvik/ART PSS（仅 Android / Android only）
  /// - nativePss:             Native PSS（仅 Android / Android only）
  /// - totalPrivateDirty:     总私有脏页（仅 Android / Android only）
  /// - nativePrivateDirty:    Native 私有脏页（仅 Android / Android only）
  /// - totalRss:              总 RSS 分项（仅 Android API 23+ / Android API 23+ only）
  /// - physicalFootprint:    物理内存占用（仅 iOS / iOS only，最准确的内存指标）
  /// - internalCompressed:   已压缩内存（仅 iOS / iOS only）
  /// - internalSize:         内部内存总量（仅 iOS / iOS only）
  /// - totalMem:              设备物理内存总量
  /// - availMem:              设备可用物理内存
  /// - lowMemory:            是否处于低内存状态
  static Future<Map<String, dynamic>?> getProcessMemoryInfo() async {
    try {
      final result = await _channel.invokeMethod<Map>('getProcessMemoryInfo');
      if (result == null) return null;
      // 将 Map<dynamic, dynamic> 转为 Map<String, dynamic>
      // Convert Map<dynamic, dynamic> to Map<String, dynamic>
      return result.map((key, value) => MapEntry(key.toString(), value));
    } catch (e) {
      // 平台不支持时返回 null / Return null when platform not supported
      return null;
    }
  }
}
