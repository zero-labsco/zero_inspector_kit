import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../models/network_request.dart';
import '../models/interceptor_rule.dart';
import '../services/inspector_service.dart';

part 'inspector_http_client.dart';
part 'inspector_response_proxy.dart';

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
