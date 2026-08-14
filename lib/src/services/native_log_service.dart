import 'dart:async';
import 'dart:convert';

import '../interceptors/log_interceptor.dart';
import '../models/log_entry.dart';
import '../platform/platform_channel.dart';

/// 鸿蒙(OpenHarmony)原生日志桥接服务 / OpenHarmony native log bridge service
///
/// 鸿蒙无 logcat 等价接口，无法抓全量系统日志；但 hiAppEvent 能真实上报本应用
/// 的崩溃/卡死(app crash/freeze)事件。该服务在鸿蒙平台订阅 hiAppEvent，并周期性
/// 把真实应用级异常事件拉取、格式化后汇入日志查看器。
/// OHOS has no logcat-equivalent, so full system logs are unavailable; however
/// hiAppEvent genuinely reports the app's crash/freeze events. This service
/// subscribes to hiAppEvent on OHOS and periodically pulls those real app-level
/// exception events, formats them, and feeds them into the Log viewer.
class NativeLogService {
  NativeLogService._();

  /// 单例实例 / Singleton instance
  static final NativeLogService instance = NativeLogService._();

  /// 拉取间隔（毫秒）/ Poll interval (ms)
  static const int _pollIntervalMs = 5000;

  /// 单次拉取条数上限 / Max events pulled per cycle
  static const int _pollLimit = 50;

  Timer? _timer;

  /// 是否已启动 / Whether the bridge is running
  bool get isRunning => _timer != null;

  /// 启动鸿蒙原生日志桥接 / Start the OHOS native log bridge
  ///
  /// 仅在鸿蒙平台生效且幂等；非鸿蒙平台为 no-op。
  /// No-op off OHOS; idempotent on OHOS.
  void start() {
    if (!PlatformChannel.isOhos) return;
    if (_timer != null) return;

    // 开启 hiAppEvent 崩溃/卡死订阅（原生侧幂等）。
    // Start hiAppEvent crash/freeze subscription (idempotent natively).
    PlatformChannel.startNativeLogListener();
    _timer = Timer.periodic(
      const Duration(milliseconds: _pollIntervalMs),
      (_) => _poll(),
    );
    // 立即拉取一次 / Poll once immediately
    _poll();
  }

  /// 停止桥接 / Stop the bridge
  void stop() {
    _timer?.cancel();
    _timer = null;
    if (PlatformChannel.isOhos) {
      PlatformChannel.stopNativeLogListener();
    }
  }

  Future<void> _poll() async {
    final logs = await PlatformChannel.getNativeLogs(limit: _pollLimit);
    if (logs == null || logs.isEmpty) return;
    for (final raw in logs) {
      InspectorLogInterceptor.instance.captureLog(
        _format(raw),
        LogLevel.error,
        tag: 'OHOS',
      );
    }
  }

  /// 将 hiAppEvent 事件 JSON 字符串格式化为可读文本 / Format a hiAppEvent JSON string
  ///
  /// hiAppEvent 返回形如 `{"domain":"app","eventGroup":"...","event":{...}}` 的 JSON 字符串。
  /// 提取事件名与分组，无法解析时退回原始文本。
  /// hiAppEvent returns a JSON string like `{"domain":"app","eventGroup":"...","event":{...}}`.
  /// Extracts the event name and group; falls back to the raw text if unparseable.
  String _format(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final event = decoded['event'];
        final group = decoded['eventGroup']?.toString() ?? '';
        final name = event is Map ? (event['name']?.toString() ?? '') : '';
        final buffer = StringBuffer();
        if (group.isNotEmpty) buffer.write('[$group] ');
        if (name.isNotEmpty) buffer.write('$name ');
        buffer.write(raw);
        return buffer.toString().trim();
      }
    } catch (_) {
      // 解析失败时退回原始文本 / Fall back to raw text on parse failure
    }
    return raw;
  }
}
