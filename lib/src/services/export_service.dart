import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
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
      if (log.tag != null && log.tag!.isNotEmpty) {
        buf.writeln('  Tag: ${log.tag}');
      }
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

  /// 网络请求 → CSV / Network to CSV
  /// 列：method,url,statusCode,durationMs,requestTime,hasBody,hasResponse
  String netToCsv(List<NetworkRequest> requests) {
    final buf = StringBuffer()
      ..writeln(
        'method,url,statusCode,durationMs,requestTime,hasBody,hasResponse',
      );
    for (final r in requests) {
      buf.writeln(
        [
          _csvCell(r.method),
          _csvCell(r.url),
          r.statusCode?.toString() ?? '',
          r.duration?.toString() ?? '',
          r.requestTime.toString(),
          r.body != null ? '1' : '0',
          r.responseBody != null ? '1' : '0',
        ].join(','),
      );
    }
    return buf.toString();
  }

  /// 网络请求 → HAR 1.2 / Network to HAR 1.2
  ///
  /// 生成的 HAR 可直接导入 Chrome DevTools / Charles 等工具，极大提升与现有链路的互操作性。
  /// The generated HAR can be imported into Chrome DevTools / Charles, improving interoperability.
  String netToHar(List<NetworkRequest> requests) {
    final entries = requests.map((r) {
      final reqHeaders = (r.headers ?? {}).entries
          .map((e) => {'name': e.key, 'value': e.value})
          .toList();
      final startedMs = r.requestTime;
      final time = r.duration ?? 0;
      return {
        'startedDateTime': DateTime.fromMillisecondsSinceEpoch(
          startedMs,
        ).toUtc().toIso8601String(),
        'time': time,
        'request': {
          'method': r.method,
          'url': r.url,
          'headers': reqHeaders,
          'postData': r.body != null
              ? {
                  'mimeType': 'application/octet-stream',
                  'text': r.body.toString(),
                }
              : null,
        },
        'response': {
          'status': r.statusCode ?? 0,
          'statusText': '',
          'headers': <Map<String, String>>[],
          'content': {
            'size': r.responseBody?.toString().length ?? 0,
            'text': r.responseBody?.toString(),
          },
        },
        'timings': {'send': 0, 'wait': time, 'receive': 0},
      };
    }).toList();

    return jsonEncode({
      'log': {
        'version': '1.2',
        'creator': {'name': 'Zero Inspector Kit', 'version': '1.2'},
        'entries': entries,
      },
    });
  }

  // ==================== 文件导出 / File export ====================

  /// 将内容写入临时文件并返回路径。大数据量导出时优先用文件而非剪贴板（剪贴板会截断/失败）。
  /// Write content to a temp file and return its path. Prefer file over clipboard for large exports.
  ///
  /// 返回的文件位于应用临时目录；可配合平台层分享或直接用文件管理器打开。
  /// The returned file lives in the app temp dir; share or open via a file manager.
  Future<String> writeToFile(String content, String fileName) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content);
    return file.path;
  }

  /// 导出日志到文件 / Export logs to a file
  Future<String> exportLogsToFile(List<LogEntry> logs, {bool json = true}) =>
      writeToFile(
        json ? logsToJson(logs) : logsToText(logs),
        'zero_inspector_logs.${json ? 'json' : 'txt'}',
      );

  /// 导出网络请求到文件（支持 json/csv/har）/ Export network requests to a file
  Future<String> exportNetToFile(
    List<NetworkRequest> requests, {
    String format = 'json',
  }) {
    final content = switch (format) {
      'csv' => netToCsv(requests),
      'har' => netToHar(requests),
      _ => netToJson(requests),
    };
    return writeToFile(content, 'zero_inspector_net.$format');
  }

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

  /// CSV 单元格转义：含逗号/引号/换行时用双引号包裹并转义内部引号。
  /// CSV cell escaping: wrap in quotes and escape inner quotes when needed.
  String _csvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
