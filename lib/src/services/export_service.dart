import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/log_entry.dart';
import '../models/network_request.dart';
import '../utils/inspector_version.dart';
import '../utils/sensitive_data.dart';

/// 导出服务 / Export service
///
/// 支持将 Inspector 数据导出为 JSON 或文本并复制到剪贴板
/// Supports exporting Inspector data as JSON or text and copying to clipboard
class ExportService {
  ExportService._();

  /// 单例实例 / Singleton instance
  static final ExportService instance = ExportService._();

  /// 导出时需遮蔽的敏感请求头（不区分大小写）/ Sensitive headers to mask on export
  ///
  /// 已废弃：仅保留旧的最小集合以维持公共 API 兼容。真正的脱敏统一走
  /// [SensitiveData]，它额外覆盖 URL query 与请求体，并支持变体名与宿主扩展。
  /// Deprecated: kept as the legacy minimal set for public-API compatibility.
  /// Masking now goes through [SensitiveData], which also covers URL query and
  /// bodies, supports name variants and host-side extension.
  @Deprecated('Use SensitiveData.isSensitiveHeader / SensitiveData.maskHeaders')
  static const Set<String> sensitiveHeaders = {
    'authorization',
    'cookie',
    'set-cookie',
    'proxy-authorization',
    'x-auth-token',
    'x-csrf-token',
    'x-xsrf-token',
  };

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
  /// [maskSensitive] 为 true 时遮蔽敏感头。
  String netToJson(
    List<NetworkRequest> requests, {
    bool maskSensitive = false,
  }) => jsonEncode({
    'exportedAt': DateTime.now().toIso8601String(),
    'count': requests.length,
    'requests': requests.map((e) => _maskedJson(e, maskSensitive)).toList(),
  });

  /// 按 [maskSensitive] 决定是否遮蔽敏感数据后再序列化 / Serialize with masking
  ///
  /// 覆盖请求头、URL query 与请求体 —— 此前只遮蔽请求头，`?token=` 与
  /// JSON 里的 `password` 会原样导出。
  /// Covers headers, URL query and body — previously only headers were masked,
  /// so `?token=` and JSON `password` fields were exported verbatim.
  Map<String, dynamic> _maskedJson(NetworkRequest e, bool maskSensitive) {
    final json = e.toJson();
    if (!maskSensitive) return json;
    if (e.headers != null) {
      json['headers'] = SensitiveData.maskHeaders(e.headers!);
    }
    final url = e.url;
    if (url.isNotEmpty) {
      json['url'] = SensitiveData.maskUrl(url);
    }
    if (e.body != null) {
      json['body'] = SensitiveData.maskBodyByContent(e.body.toString());
    }
    if (e.responseBody != null) {
      json['responseBody'] = SensitiveData.maskBodyByContent(
        e.responseBody.toString(),
      );
    }
    return json;
  }

  /// 网络请求 → 复制为 cURL 命令 / Network request → cURL command
  ///
  /// 生成可直接粘贴到终端执行的 curl 命令（含 method、headers、body）。
  /// [maskSensitive] 为 true 时遮蔽敏感头、URL query 与 body。
  /// Produces a ready-to-run curl command. When [maskSensitive] is true,
  /// sensitive headers, URL query params and the body are masked.
  String toCurl(NetworkRequest r, {bool maskSensitive = false}) {
    final buf = StringBuffer()..write('curl -X ${r.method} ');
    // URL（含单引号时转义，并按需遮蔽 query 中的凭据）
    // URL (escape single quotes, and mask credentials in the query as needed)
    final rawUrl = maskSensitive ? SensitiveData.maskUrl(r.url) : r.url;
    // ignore: prefer_single_quotes — 这里需要双引号以便把单引号转义为 %27
    final url = rawUrl.replaceAll("'", "%27");
    buf.writeln("'$url' \\");
    for (final e in (r.headers ?? {}).entries) {
      final masked = maskSensitive && SensitiveData.isSensitiveHeader(e.key);
      final name = _shellQuote(e.key);
      final value = _shellQuote(masked ? SensitiveData.placeholder : e.value);
      buf.writeln('  -H "$name: $value" \\');
    }
    if (r.body != null) {
      final rawBody = r.body.toString();
      final body = _shellQuote(
        maskSensitive ? SensitiveData.maskBodyByContent(rawBody) : rawBody,
      );
      buf.writeln('  -d "$body" \\');
    }
    // 去掉末尾的续行符 / Trim trailing line-continuation
    var out = buf.toString();
    if (out.endsWith(' \\\n')) out = out.substring(0, out.length - 3);
    return out;
  }

  /// 双引号内的 shell 转义 / Shell escaping inside double quotes
  ///
  /// 此前只转义了 `"`，含反引号或 `$(...)` 的 body 粘贴到终端会被执行。
  /// Previously only `"` was escaped, so a body containing backticks or
  /// `$(...)` would be executed when pasted into a terminal.
  static String _shellQuote(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll('"', '\\"')
      .replaceAll('`', '\\`')
      .replaceAll('\$', '\\\$')
      .replaceAll('!', '\\!');

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
  /// [maskSensitive] 为 true 时遮蔽敏感头。
  /// The generated HAR can be imported into Chrome DevTools / Charles. When
  /// [maskSensitive] is true, sensitive headers are masked.
  String netToHar(List<NetworkRequest> requests, {bool maskSensitive = false}) {
    final entries = requests.map((r) {
      final reqHeaders = (r.headers ?? {}).entries
          .map(
            (e) => {
              'name': e.key,
              'value': maskSensitive && SensitiveData.isSensitiveHeader(e.key)
                  ? SensitiveData.placeholder
                  : e.value,
            },
          )
          .toList();
      final url = maskSensitive ? SensitiveData.maskUrl(r.url) : r.url;
      final rawBody = r.body?.toString();
      final bodyText = rawBody == null
          ? null
          : (maskSensitive
                ? SensitiveData.maskBodyByContent(rawBody)
                : rawBody);
      final rawResponse = r.responseBody?.toString();
      final responseText = rawResponse == null
          ? null
          : (maskSensitive
                ? SensitiveData.maskBodyByContent(rawResponse)
                : rawResponse);
      final startedMs = r.requestTime;
      final time = r.duration ?? 0;
      return {
        'startedDateTime': DateTime.fromMillisecondsSinceEpoch(
          startedMs,
        ).toUtc().toIso8601String(),
        'time': time,
        'request': {
          'method': r.method,
          'url': url,
          'headers': reqHeaders,
          'postData': bodyText != null
              ? {'mimeType': _guessMimeType(r.headers), 'text': bodyText}
              : null,
        },
        'response': {
          'status': r.statusCode ?? 0,
          'statusText': '',
          'headers': <Map<String, String>>[],
          'content': {'size': responseText?.length ?? 0, 'text': responseText},
        },
        'timings': {'send': 0, 'wait': time, 'receive': 0},
      };
    }).toList();

    return jsonEncode({
      'log': {
        'version': '1.2',
        'creator': {
          'name': 'Zero Inspector Kit',
          'version': InspectorVersion.value,
        },
        'entries': entries,
      },
    });
  }

  /// 按 Content-Type 推断 HAR `postData.mimeType`
  /// Infer the HAR `postData.mimeType` from Content-Type
  ///
  /// 此前恒为 `application/octet-stream`，导入 DevTools / Charles 后无法正常
  /// 格式化 JSON / 表单请求体。
  /// Previously always `application/octet-stream`, so imported bodies could not
  /// be formatted as JSON / form data in DevTools / Charles.
  static String _guessMimeType(Map<String, String>? headers) {
    if (headers == null) return 'application/octet-stream';
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() != 'content-type') continue;
      final value = entry.value.split(';').first.trim();
      if (value.isNotEmpty) return value;
    }
    return 'application/octet-stream';
  }

  // ==================== 文件导出 / File export ====================

  /// 将内容写入临时文件并返回路径。大数据量导出时优先用文件而非剪贴板（剪贴板会截断/失败）。
  /// Write content to a temp file and return its path. Prefer file over clipboard for large exports.
  ///
  /// 返回的文件位于应用临时目录；可配合平台层分享或直接用文件管理器打开。
  /// The returned file lives in the app temp dir; share or open via a file manager.
  ///
  /// [fileName] 会先消毒（去掉路径分隔符与 `..`，避免越界写文件），
  /// 且当同名文件已存在时自动追加序号，避免并发导出互相覆盖。
  /// [fileName] is sanitized (path separators and `..` are stripped so a
  /// crafted name cannot escape the temp dir), and a numeric suffix is appended
  /// when the name is taken so concurrent exports don't overwrite each other.
  Future<String> writeToFile(String content, String fileName) async {
    final dir = await getTemporaryDirectory();
    final safeName = _sanitizeFileName(fileName);
    var candidate = File('${dir.path}${Platform.pathSeparator}$safeName');
    if (await candidate.exists()) {
      final dot = safeName.lastIndexOf('.');
      final base = dot > 0 ? safeName.substring(0, dot) : safeName;
      final ext = dot > 0 ? safeName.substring(dot) : '';
      var i = 1;
      do {
        candidate = File('${dir.path}${Platform.pathSeparator}${base}_$i$ext');
        i++;
      } while (await candidate.exists() && i < 100);
    }
    await candidate.writeAsString(content);
    return candidate.path;
  }

  /// 文件名消毒：只保留文件名部分，剔除非法字符
  /// Sanitize a file name: keep only the basename, drop illegal characters
  static String _sanitizeFileName(String name) {
    // 先去掉任何目录成分（`../x` 会越界），再剔除控制字符与路径分隔符。
    // Strip any directory component (`../x` would escape), then drop control
    // characters and path separators.
    final cleaned = name
        .replaceAll(RegExp(r'[\\/]'), '_')
        .replaceAll(RegExp(r'[^\w.\-]'), '_')
        .replaceAll(RegExp(r'^\.+'), '');
    if (cleaned.isEmpty) return 'zero_inspector_export.txt';
    return cleaned;
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
    bool maskSensitive = false,
  }) {
    final content = switch (format) {
      'csv' => netToCsv(requests),
      'har' => netToHar(requests, maskSensitive: maskSensitive),
      _ => netToJson(requests, maskSensitive: maskSensitive),
    };
    return writeToFile(content, 'zero_inspector_net.$format');
  }

  // ==================== 系统分享 / System share ====================

  /// 通过系统分享面板分享已导出的文件（调用 share_plus）。
  /// Share an already-exported file via the system share sheet.
  ///
  /// [path] 为 [writeToFile] / [exportLogsToFile] / [exportNetToFile] 返回的路径。
  /// [mimeType] 建议显式指定以便接收方能正确识别（如 json 传 'application/json'）。
  /// [path] is the path returned by the file export methods above.
  Future<void> shareFile(String path, {String? mimeType}) async {
    try {
      final file = XFile(path, mimeType: mimeType);
      await SharePlus.instance.share(ShareParams(files: [file]));
    } catch (e) {
      debugPrint('ExportService.shareFile error: $e');
    }
  }

  /// 导出日志并唤起系统分享 / Export logs then open the share sheet
  Future<void> exportLogsAndShare(
    List<LogEntry> logs, {
    bool json = true,
  }) async {
    final path = await exportLogsToFile(logs, json: json);
    await shareFile(path, mimeType: json ? 'application/json' : 'text/plain');
  }

  /// 导出网络请求并唤起系统分享（支持 json/csv/har）/ Export net then share
  Future<void> exportNetAndShare(
    List<NetworkRequest> requests, {
    String format = 'json',
    bool maskSensitive = false,
  }) async {
    final path = await exportNetToFile(
      requests,
      format: format,
      maskSensitive: maskSensitive,
    );
    final mime = switch (format) {
      'csv' => 'text/csv',
      'har' => 'application/json',
      _ => 'application/json',
    };
    await shareFile(path, mimeType: mime);
  }

  // ==================== 一键 Bug 报告 / One-click bug report ====================

  /// 拼装一份面向 QA 报 bug 的快照报告：设备信息 + 当前内存 + 最近日志 + 最近网络。
  /// Assemble a QA bug-report snapshot: device info + current memory + recent logs + recent network.
  ///
  /// [deviceInfo] 由调用方通过 [DeviceInfoUtil] 等拼装；[memoryInfo] 可选（当前内存快照文本）。
  /// 日志与网络各取最近若干条（避免报告过长），[maskSensitive] 为 true 时遮蔽敏感头。
  /// [deviceInfo] is assembled by the caller (e.g. DeviceInfoUtil); [memoryInfo] is optional
  /// (current memory snapshot text). Logs/network are sliced to the most recent entries;
  /// [maskSensitive] masks sensitive headers.
  String buildBugReport({
    required String deviceInfo,
    String? memoryInfo,
    List<LogEntry>? logs,
    List<NetworkRequest>? requests,
    bool maskSensitive = false,
    int maxLogs = 200,
    int maxRequests = 50,
  }) {
    final buf = StringBuffer()
      ..writeln('# Zero Inspector Kit — Bug Report')
      ..writeln('Generated: ${DateTime.now().toIso8601String()}')
      ..writeln()
      ..writeln(deviceInfo);

    if (memoryInfo != null && memoryInfo.isNotEmpty) {
      buf
        ..writeln()
        ..writeln(memoryInfo);
    }

    if (logs != null && logs.isNotEmpty) {
      final sliced = logs.length > maxLogs
          ? logs.sublist(logs.length - maxLogs)
          : logs;
      buf
        ..writeln()
        ..writeln(logsToText(sliced));
    }

    if (requests != null && requests.isNotEmpty) {
      final sliced = requests.length > maxRequests
          ? requests.sublist(requests.length - maxRequests)
          : requests;
      buf
        ..writeln()
        ..writeln('=== Recent Network (last ${sliced.length}) ===')
        ..writeln(
          sliced
              .map((r) => toCurl(r, maskSensitive: maskSensitive))
              .join('\n\n'),
        );
    }

    return buf.toString();
  }

  /// 拼装并唤起系统分享面板 / Assemble and open the share sheet
  Future<void> exportBugReportAndShare({
    required String deviceInfo,
    String? memoryInfo,
    List<LogEntry>? logs,
    List<NetworkRequest>? requests,
    bool maskSensitive = false,
  }) async {
    final content = buildBugReport(
      deviceInfo: deviceInfo,
      memoryInfo: memoryInfo,
      logs: logs,
      requests: requests,
      maskSensitive: maskSensitive,
    );
    final path = await writeToFile(content, 'zero_inspector_bug_report.txt');
    await shareFile(path, mimeType: 'text/plain');
  }

  // ==================== 复制方法 / Copy methods ====================

  /// 复制日志（格式可选）/ Copy logs (format optional)
  Future<void> copyLogs(List<LogEntry> logs, {bool json = true}) async =>
      copy(json ? logsToJson(logs) : logsToText(logs));

  /// 复制网络请求 / Copy network requests
  /// [maskSensitive] 为 true 时遮蔽敏感头。
  Future<void> copyNet(
    List<NetworkRequest> requests, {
    bool maskSensitive = false,
  }) async => copy(netToJson(requests, maskSensitive: maskSensitive));

  /// 复制任意内容到剪贴板 / Copy any content to clipboard
  Future<void> copy(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
    } catch (e) {
      debugPrint('ExportService.copy error: $e');
    }
  }

  /// 复制单条文本到剪贴板（公开包装，供单条日志复制等使用）
  /// Copy a single text to clipboard (public wrapper).
  Future<void> copyText(String content) => copy(content);

  /// 日志级别前缀 / Log level prefix
  ///
  /// 此前是 [LogEntry.levelText] 之外**第二份**同样的 switch —— 新增日志级别时
  /// 极易只改一处。现在直接复用模型层的单一实现。
  /// This used to be a **second** copy of the same switch alongside
  /// [LogEntry.levelText] — adding a level would likely miss one of them.
  /// It now reuses the single implementation on the model.
  static String _lvl(LogLevel l) => LogLevelText.of(l);

  /// CSV 单元格转义：含逗号/引号/换行时用双引号包裹并转义内部引号。

  /// CSV 单元格转义：含逗号/引号/换行时用双引号包裹并转义内部引号。
  /// CSV cell escaping: wrap in quotes and escape inner quotes when needed.
  String _csvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
