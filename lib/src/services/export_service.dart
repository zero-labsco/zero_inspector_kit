import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/log_entry.dart';
import '../models/network_request.dart';

/// 导出服务 / Export service
///
/// 支持将 Inspector 数据导出为 JSON 或文本并复制到剪贴板
/// Supports exporting Inspector data as JSON or text and copying to clipboard
class ExportService {
  ExportService._();

  /// 单例实例 / Singleton instance
  static final ExportService instance = ExportService._();

  // ==================== 导出方法 / Export methods ====================

  /// 日志 → JSON / Logs to JSON
  String logsToJson(List<LogEntry> logs) => jsonEncode({
        'exportedAt': DateTime.now().toIso8601String(),
        'count': logs.length,
        'logs': logs.map((e) => e.toJson()).toList(),
      });

  /// 日志 → 纯文本 / Logs to text
  String logsToText(List<LogEntry> logs) {
    final buf = StringBuffer()
      ..writeln('=== Zero Inspector Kit - Logs ===')
      ..writeln('Exported: ${DateTime.now().toIso8601String()}')
      ..writeln('Total: ${logs.length}')
      ..writeln('=' * 50);
    for (final log in logs) {
      buf.writeln('${log.timestamp} [${_lvl(log.level)}] ${log.message}');
      if (log.tag != null && log.tag!.isNotEmpty) buf.writeln('  Tag: ${log.tag}');
      buf.writeln('');
    }
    return buf.toString();
  }

  /// 网络请求 → JSON / Network to JSON
  String netToJson(List<NetworkRequest> requests) => jsonEncode({
        'exportedAt': DateTime.now().toIso8601String(),
        'count': requests.length,
        'requests': requests.map((e) => e.toJson()).toList(),
      });

  // ==================== 复制方法 / Copy methods ====================

  /// 复制日志（格式可选）/ Copy logs (format optional)
  Future<void> copyLogs(List<LogEntry> logs, {bool json = true}) async =>
      copy(json ? logsToJson(logs) : logsToText(logs));

  /// 复制网络请求 / Copy network requests
  Future<void> copyNet(List<NetworkRequest> requests) async =>
      copy(netToJson(requests));

  /// 复制任意内容到剪贴板 / Copy any content to clipboard
  Future<void> copy(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
    } catch (e) {
      debugPrint('ExportService.copy error: $e');
    }
  }

  /// 日志级别前缀 / Log level prefix
  String _lvl(LogLevel l) {
    switch (l) {
      case LogLevel.verbose:
        return 'V';
      case LogLevel.debug:
        return 'D';
      case LogLevel.info:
        return 'I';
      case LogLevel.warning:
        return 'W';
      case LogLevel.error:
        return 'E';
    }
  }
}
