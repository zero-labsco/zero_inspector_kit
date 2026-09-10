import 'package:http/http.dart' as http;

import '../models/network_request.dart';

/// 重放时会被剔除的请求头（小写）/ Headers dropped on replay (lowercase)
///
/// 两类 / Two categories:
/// - 检查器自身的关联头 [replayExcludedHeaders]，此前会被原样重放出去。
///   The inspector's own correlation header, which used to be replayed as-is.
/// - 由 `http` 包自行计算管理的逐跳头（重放旧值会导致长度不匹配 / 请求挂起）。
///   Hop-by-hop headers managed by the `http` package itself; replaying stale
///   values causes length mismatches or hangs.
const Set<String> replayExcludedHeaders = {
  'x-inspector-request-id',
  'host',
  'content-length',
};

/// 根据已捕获的 [NetworkRequest] 重建一个可发送的 [http.Request]，
/// 用于「重放 / 重试」功能（在 App 内重新发出同一请求）。
/// Rebuild a sendable [http.Request] from a captured [NetworkRequest] for replay/retry.
///
/// 可选覆盖 / Optional overrides（用于「编辑后重放」）:
/// - [url]：替换目标 URL / replace the target URL
/// - [headers]：合并进请求头（同键覆盖）/ merged into the headers (same key wins)
/// - [body]：替换请求体；传 `null` 表示沿用原 body，
///   传空字符串表示清空 body / replace the body; `null` keeps the original,
///   an empty string clears it
http.Request buildReplayRequest(
  NetworkRequest r, {
  String? url,
  Map<String, String>? headers,
  Object? body,
}) {
  final target = Uri.parse(url ?? r.url);
  final req = http.Request(r.method.toUpperCase(), target);

  if (r.headers != null) {
    for (final entry in r.headers!.entries) {
      if (replayExcludedHeaders.contains(entry.key.toLowerCase())) continue;
      req.headers[entry.key] = entry.value;
    }
  }
  if (headers != null) {
    for (final entry in headers.entries) {
      if (replayExcludedHeaders.contains(entry.key.toLowerCase())) continue;
      req.headers[entry.key] = entry.value;
    }
  }

  final effectiveBody = body ?? r.body;
  if (effectiveBody != null) {
    if (effectiveBody is List<int>) {
      req.bodyBytes = effectiveBody;
    } else {
      final text = effectiveBody.toString();
      if (text.isEmpty) {
        // 显式清空 body（不设置 bodyBytes，避免发出 `Content-Length: 0` 的空壳）。
        // Explicitly clear the body (leave bodyBytes unset rather than sending
        // an empty `Content-Length: 0` shell).
      } else {
        req.body = text;
      }
    }
  }
  return req;
}
