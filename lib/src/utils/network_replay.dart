import 'package:http/http.dart' as http;

import '../models/network_request.dart';

/// 根据已捕获的 [NetworkRequest] 重建一个可发送的 [http.Request]，
/// 用于「重放 / 重试」功能（在 App 内重新发出同一请求）。
/// Rebuild a sendable [http.Request] from a captured [NetworkRequest] for replay/retry.
http.Request buildReplayRequest(NetworkRequest r) {
  final req = http.Request(r.method.toUpperCase(), Uri.parse(r.url));
  if (r.headers != null) req.headers.addAll(r.headers!);
  if (r.body != null) {
    if (r.body is List<int>) {
      req.bodyBytes = r.body as List<int>;
    } else {
      req.body = r.body.toString();
    }
  }
  return req;
}
