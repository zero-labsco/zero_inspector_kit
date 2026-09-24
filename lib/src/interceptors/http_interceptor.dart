import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/network_request.dart';
import '../models/interceptor_rule.dart';
import '../services/inspector_service.dart';

part 'inspector_http_client.dart';
part 'inspector_response_proxy.dart';

/// 截取"注定能留在预览里"的字节前缀，避免解码整段随后被截断的 body。
/// Trim the byte prefix guaranteed to survive preview truncation, so we never
/// decode the tail that gets thrown away.
///
/// 面板对 body 只保留头部 [maxChars] 个字符（[NetworkRequest.copyWith] 按字符
/// 截断），而缓冲字节最多可达 512 KB —— 直接 `utf8.decode` 整段会把绝大部分
/// 解码成本花在随后被丢弃的尾巴上（512 KB 对 32 K 字符，纯 ASCII 下 16 倍浪费）。
/// The panel keeps only the leading [maxChars] characters of a body
/// ([NetworkRequest.copyWith] truncates by character), while the buffered bytes
/// can reach 512 KB — decoding all of it spends most of the cost on a tail that
/// is discarded right after (16x waste for pure ASCII).
///
/// UTF-8 中一个字符最多占 4 字节，因此 `maxChars * 4 + 3` 字节足以产出满额的
/// [maxChars] 个字符；额外多取 3 字节是为了不把多字节字符切在中间 —— 那会让
/// `utf8.decode` 抛错并被误判成"二进制响应"。
/// One UTF-8 character is at most 4 bytes, so `maxChars * 4 + 3` bytes can
/// always yield a full [maxChars] characters; the extra 3 bytes keep us from
/// cutting a multi-byte character in half, which would make `utf8.decode` throw
/// and get misread as a "binary response".
///
/// [maxChars] <= 0 表示不限制，原样返回（调用方未取到配置时的安全默认）。
/// [maxChars] <= 0 means no limit — returns as-is (safe default when the caller
/// could not read the configured cap).
List<int> _bytesForPreviewDecode(List<int> bytes, int maxChars) {
  if (maxChars <= 0) return bytes;
  final limit = maxChars * 4 + 3;
  if (bytes.length <= limit) return bytes;
  return bytes.sublist(0, limit);
}

/// HTTP 请求拦截器 / HTTP request interceptor
/// 通过 HttpOverrides 机制实现全局 HTTP 请求拦截 / Implement global HTTP request interception via HttpOverrides mechanism
///
/// 使用方式：/ Usage:
/// 1. 调用 start() 方法启用全局拦截 / Call start() to enable global interception
/// 2. 使用 http.get() / http.post() / http.put() / http.delete() / http.patch() / http.head() 等方法发送请求，会自动被捕获
///    / Use http.get() / http.post() / http.put() / http.delete() / http.patch() / http.head() etc., requests will be auto-captured
///
/// 注意：此拦截器工作在 dart:io 的 HttpClient 层，因此可以同时捕获：/ Note: This interceptor works at the dart:io HttpClient level, so it can capture:
/// - http 包发起的所有请求（get/post/put/delete/patch/head）/ - All requests from http package (get/post/put/delete/patch/head)
/// - Dio 发起的所有请求（Dio 默认使用 IOHttpClientAdapter，底层也是 HttpClient）/ - All requests from Dio (Dio uses IOHttpClientAdapter by default)
/// - 任何其他使用 HttpClient 的库发起的请求 / - Any requests from other libraries using HttpClient
class InspectorHttpInterceptor {
  InspectorHttpInterceptor._();

  static final InspectorHttpInterceptor instance = InspectorHttpInterceptor._();

  bool _started = false;
  HttpOverrides? _previousOverrides;

  /// 启动全局 HTTP 请求拦截 / Start global HTTP request interception
  /// 链式包裹宿主已有的 HttpOverrides（若存在），避免静默覆盖代理 / 证书固定等配置。
  /// Chains over any existing HttpOverrides (if present) instead of silently
  /// replacing it, preserving host proxy / cert-pinning configurations.
  void start() {
    if (_started) return;
    _started = true;
    _previousOverrides = HttpOverrides.current;
    HttpOverrides.global = _InspectorHttpOverrides(_previousOverrides);
  }

  /// 停止全局 HTTP 请求拦截 / Stop global HTTP request interception
  /// 恢复被包裹前的 HttpOverrides（而非置 null，避免丢弃宿主配置）。
  /// Restores the previous HttpOverrides (instead of nulling it out, which
  /// would discard host configurations).
  void stop() {
    if (!_started) return;
    _started = false;
    HttpOverrides.global = _previousOverrides;
    _previousOverrides = null;
  }

  /// 是否已启动全局拦截 / Whether global interception has started
  bool get isStarted => _started;
}

/// HTTP 请求覆盖类 / HTTP request override class
/// 通过 HttpOverrides 机制实现全局 HTTP 请求拦截 / Implement global HTTP request interception via HttpOverrides mechanism
class _InspectorHttpOverrides extends HttpOverrides {
  final HttpOverrides? _delegate;
  _InspectorHttpOverrides(this._delegate);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client =
        _delegate?.createHttpClient(context) ?? super.createHttpClient(context);
    return _InspectorHttpClient(client);
  }
}
