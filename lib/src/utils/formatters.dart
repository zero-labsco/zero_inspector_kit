import 'dart:convert';

/// 格式化工具集 / Shared formatting helpers
///
/// 集中所有 viewer 中重复出现的格式化逻辑（字节、时长、时间戳、JSON），
/// 避免在各 UI 文件里各自实现、行为不一致。
/// Centralizes formatting logic duplicated across viewers to keep behavior consistent.
class InspectorFormatters {
  InspectorFormatters._();

  /// 人类可读的字节数 / Human-readable byte size
  ///
  /// [bytes] 字节数，可能为 null（未知）。/ Byte count, possibly null (unknown).
  static String formatBytes(int? bytes) {
    if (bytes == null) return '—';
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  /// 毫秒时长 / Duration in milliseconds
  ///
  /// [ms] 毫秒，可能为 null。返回形如 `123 ms` 或 `1.23 s`。
  /// [ms] milliseconds, possibly null. Returns e.g. `123 ms` or `1.23 s`.
  static String formatDuration(int? ms) {
    if (ms == null) return '—';
    if (ms < 1000) return '$ms ms';
    return '${(ms / 1000).toStringAsFixed(2)} s';
  }

  /// 时间戳（时:分:秒.毫秒）/ Timestamp (HH:MM:SS.mmm)
  static String formatTimestamp(DateTime timestamp) {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  /// 时间戳（时:分:秒，来自微秒）/ Timestamp (HH:MM:SS) from microseconds
  static String formatTimeFromMicros(int micros) {
    final dt = DateTime.fromMicrosecondsSinceEpoch(micros);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// JSON 格式化 / Pretty-print JSON
  ///
  /// 失败时回退到 [toString]，绝不抛异常。/ Falls back to [toString] on failure.
  static String formatJson(dynamic data) {
    if (data == null) return 'null';
    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return data.toString();
    }
  }
}
