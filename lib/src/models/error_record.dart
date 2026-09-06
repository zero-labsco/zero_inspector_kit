/// 聚合后的异常记录 / Aggregated error record
///
/// 按异常类型 + 堆栈签名去重，累积出现次数、首末次时间，并保存一条完整堆栈样本。
/// Deduped by exception type + stack signature; accumulates count, first/last
/// seen time, and keeps one full stack sample.
class ErrorRecord {
  /// 去重 id（类型 + 堆栈签名）/ Dedup id (type + stack signature)
  final String id;

  /// 异常类型名（如 '_CastError'）/ Exception type name
  final String type;

  /// 异常消息 / Exception message
  final String message;

  /// 用于去重的堆栈签名（前若干帧，已去除行号/地址差异）
  /// Stack signature for dedup (first few frames, line/address noise stripped)
  final String stackSignature;

  /// 累计出现次数 / Total occurrence count
  final int count;

  /// 首次出现时间 / First seen time
  final DateTime firstSeen;

  /// 末次出现时间 / Last seen time
  final DateTime lastSeen;

  /// 一条完整堆栈样本（已截断）/ One full stack sample (truncated)
  final String? sampleStack;

  ErrorRecord({
    required this.id,
    required this.type,
    required this.message,
    required this.stackSignature,
    required this.count,
    required this.firstSeen,
    required this.lastSeen,
    this.sampleStack,
  });

  ErrorRecord copyWith({int? count, DateTime? lastSeen, String? sampleStack}) =>
      ErrorRecord(
        id: id,
        type: type,
        message: message,
        stackSignature: stackSignature,
        count: count ?? this.count,
        firstSeen: firstSeen,
        lastSeen: lastSeen ?? this.lastSeen,
        sampleStack: sampleStack ?? this.sampleStack,
      );

  /// 由异常类型 + 堆栈生成去重签名：取前若干帧并去除行号/地址等噪声，
  /// 使同一处崩溃的不同实例归并到同一条聚合记录。
  /// Build a dedup signature from type + stack: take the first few frames and
  /// strip line-number/address noise so different instances of the same crash
  /// merge into one aggregated record.
  static String signatureOf(String type, String stack) {
    final lines = stack
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(8)
        .map((l) => l.trim())
        .join('\n');
    return '$type\u0000${lines.isEmpty ? stack : lines}';
  }
}
