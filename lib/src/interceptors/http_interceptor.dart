import 'dart:async';
import 'dart:convert';
import 'dart:io';

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

  /// 启动全局 HTTP 请求拦截 / Start global HTTP request interception
  /// 通过 HttpOverrides 机制，自动捕获应用中所有使用 HttpClient 的网络请求
  /// Auto-capture all network requests using HttpClient via HttpOverrides mechanism
  void start() {
    if (_started) return;
    _started = true;
    HttpOverrides.global = _InspectorHttpOverrides();
  }

  /// 停止全局 HTTP 请求拦截 / Stop global HTTP request interception
  void stop() {
    if (!_started) return;
    _started = false;
    HttpOverrides.global = null;
  }

  /// 是否已启动全局拦截 / Whether global interception has started
  bool get isStarted => _started;
}

/// HTTP 请求覆盖类 / HTTP request override class
/// 通过 HttpOverrides 机制实现全局 HTTP 请求拦截 / Implement global HTTP request interception via HttpOverrides mechanism
class _InspectorHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _InspectorHttpClient(super.createHttpClient(context));
  }
}
