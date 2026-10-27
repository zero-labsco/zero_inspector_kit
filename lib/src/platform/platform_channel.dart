import 'package:flutter/services.dart';

/// 平台通道服务 / Platform channel service
/// 用于与原生代码通信，获取平台相关信息和进程级内存数据 / Used for communication
/// with native code, get platform info and process-level memory data
///
/// 此前还有 `getNativeLogs` / `startNativeLogListener` / `stopNativeLogListener`
/// 三个方法：本文件位于 `lib/src/`，未被 barrel 导出，消费方无法调用，包内也零
/// 调用点 —— 即原生侧的控制台 / logcat 日志能力实际上永远无法被触发（iOS 侧
/// 还是进程级的 stdout / stderr `dup2` 重定向，属于无法关闭的全局副作用）。
/// 这三个方法与对应的 Android / iOS 实现已一并移除。
/// This used to also expose `getNativeLogs` / `startNativeLogListener` /
/// `stopNativeLogListener`: this file lives under `lib/src/` and is not exported
/// by the barrel, so consumers cannot call them and nothing inside the package did
/// either — meaning the native console / logcat log feature could never actually be
/// triggered (on iOS it was a process-wide `dup2` redirection of stdout / stderr, a
/// global side effect with no way to switch it off). Those three methods and their
/// Android / iOS implementations have been removed together.
class PlatformChannel {
  /// 方法通道名称 / Method channel name
  static const MethodChannel _channel = MethodChannel('zero_inspector_kit');

  /// 获取平台版本 / Get platform version
  static Future<String?> getPlatformVersion() async {
    return await _channel.invokeMethod<String>('getPlatformVersion');
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
