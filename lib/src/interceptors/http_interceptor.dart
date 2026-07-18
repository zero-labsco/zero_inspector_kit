import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/network_request.dart';
import '../services/inspector_service.dart';

/// HTTP 请求拦截器
/// 提供两种使用方式：
/// 1. 直接使用实例方法（get/post/put/delete/patch/head）发送请求并自动捕获
/// 2. 调用 start() 方法启用全局拦截（通过 HttpOverrides），自动捕获应用中所有 HTTP 请求
/// 
/// 注意：全局拦截模式需要在应用启动时调用 start()
class InspectorHttpInterceptor {
  InspectorHttpInterceptor._();

  /// 单例实例
  static final InspectorHttpInterceptor instance = InspectorHttpInterceptor._();

  /// 是否已启动全局拦截
  bool _started = false;

  /// 启动全局 HTTP 请求拦截
  /// 通过 HttpOverrides 机制，自动捕获应用中所有使用 http 包发起的网络请求
  void start() {
    if (_started) return;
    _started = true;
    HttpOverrides.global = _InspectorHttpOverrides();
  }

  /// 停止全局 HTTP 请求拦截
  void stop() {
    _started = false;
    HttpOverrides.global = null;
  }

  /// 发送 GET 请求并自动捕获
  /// [url] 请求地址
  /// [headers] 请求头
  /// [capture] 是否捕获此请求（默认 true）
  Future<http.Response> get(
    Uri url, {
    Map<String, String>? headers,
    bool capture = true,
  }) async {
    String? requestId;
    if (capture) {
      requestId = _generateId();
      final request = NetworkRequest(
        id: requestId,
        method: 'GET',
        url: url.toString(),
        headers: headers,
        requestTime: DateTime.now().millisecondsSinceEpoch,
      );
      InspectorService.instance.addNetworkRequest(request);
    }

    final response = await http.get(url, headers: headers);

    if (capture && requestId != null) {
      InspectorService.instance.updateNetworkRequest(
        requestId,
        responseBody: response.body,
        statusCode: response.statusCode,
      );
    }

    return response;
  }

  /// 发送 POST 请求并自动捕获
  /// [url] 请求地址
  /// [headers] 请求头
  /// [body] 请求体
  /// [capture] 是否捕获此请求（默认 true）
  Future<http.Response> post(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool capture = true,
  }) async {
    String? requestId;
    if (capture) {
      requestId = _generateId();
      final request = NetworkRequest(
        id: requestId,
        method: 'POST',
        url: url.toString(),
        headers: headers,
        body: body,
        requestTime: DateTime.now().millisecondsSinceEpoch,
      );
      InspectorService.instance.addNetworkRequest(request);
    }

    final response = await http.post(url, headers: headers, body: body);

    if (capture && requestId != null) {
      InspectorService.instance.updateNetworkRequest(
        requestId,
        responseBody: response.body,
        statusCode: response.statusCode,
      );
    }

    return response;
  }

  /// 发送 PUT 请求并自动捕获
  /// [url] 请求地址
  /// [headers] 请求头
  /// [body] 请求体
  /// [capture] 是否捕获此请求（默认 true）
  Future<http.Response> put(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool capture = true,
  }) async {
    String? requestId;
    if (capture) {
      requestId = _generateId();
      final request = NetworkRequest(
        id: requestId,
        method: 'PUT',
        url: url.toString(),
        headers: headers,
        body: body,
        requestTime: DateTime.now().millisecondsSinceEpoch,
      );
      InspectorService.instance.addNetworkRequest(request);
    }

    final response = await http.put(url, headers: headers, body: body);

    if (capture && requestId != null) {
      InspectorService.instance.updateNetworkRequest(
        requestId,
        responseBody: response.body,
        statusCode: response.statusCode,
      );
    }

    return response;
  }

  /// 发送 DELETE 请求并自动捕获
  /// [url] 请求地址
  /// [headers] 请求头
  /// [body] 请求体
  /// [capture] 是否捕获此请求（默认 true）
  Future<http.Response> delete(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool capture = true,
  }) async {
    String? requestId;
    if (capture) {
      requestId = _generateId();
      final request = NetworkRequest(
        id: requestId,
        method: 'DELETE',
        url: url.toString(),
        headers: headers,
        body: body,
        requestTime: DateTime.now().millisecondsSinceEpoch,
      );
      InspectorService.instance.addNetworkRequest(request);
    }

    final response = await http.delete(url, headers: headers, body: body);

    if (capture && requestId != null) {
      InspectorService.instance.updateNetworkRequest(
        requestId,
        responseBody: response.body,
        statusCode: response.statusCode,
      );
    }

    return response;
  }

  /// 发送 PATCH 请求并自动捕获
  /// [url] 请求地址
  /// [headers] 请求头
  /// [body] 请求体
  /// [capture] 是否捕获此请求（默认 true）
  Future<http.Response> patch(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
    bool capture = true,
  }) async {
    String? requestId;
    if (capture) {
      requestId = _generateId();
      final request = NetworkRequest(
        id: requestId,
        method: 'PATCH',
        url: url.toString(),
        headers: headers,
        body: body,
        requestTime: DateTime.now().millisecondsSinceEpoch,
      );
      InspectorService.instance.addNetworkRequest(request);
    }

    final response = await http.patch(url, headers: headers, body: body);

    if (capture && requestId != null) {
      InspectorService.instance.updateNetworkRequest(
        requestId,
        responseBody: response.body,
        statusCode: response.statusCode,
      );
    }

    return response;
  }

  /// 发送 HEAD 请求并自动捕获
  /// [url] 请求地址
  /// [headers] 请求头
  /// [capture] 是否捕获此请求（默认 true）
  Future<http.Response> head(
    Uri url, {
    Map<String, String>? headers,
    bool capture = true,
  }) async {
    String? requestId;
    if (capture) {
      requestId = _generateId();
      final request = NetworkRequest(
        id: requestId,
        method: 'HEAD',
        url: url.toString(),
        headers: headers,
        requestTime: DateTime.now().millisecondsSinceEpoch,
      );
      InspectorService.instance.addNetworkRequest(request);
    }

    final response = await http.head(url, headers: headers);

    if (capture && requestId != null) {
      InspectorService.instance.updateNetworkRequest(
        requestId,
        responseBody: response.body,
        statusCode: response.statusCode,
      );
    }

    return response;
  }

  /// 发送自定义请求并自动捕获
  /// [request] BaseRequest 对象
  /// [capture] 是否捕获此请求（默认 true）
  Future<http.Response> send(http.BaseRequest request, {bool capture = true}) async {
    String? requestId;
    if (capture) {
      requestId = _generateId();
      final networkRequest = NetworkRequest(
        id: requestId,
        method: request.method,
        url: request.url.toString(),
        headers: request.headers,
        requestTime: DateTime.now().millisecondsSinceEpoch,
      );
      InspectorService.instance.addNetworkRequest(networkRequest);
    }

    final response = await http.Response.fromStream(await request.send());

    if (capture && requestId != null) {
      InspectorService.instance.updateNetworkRequest(
        requestId,
        responseBody: response.body,
        statusCode: response.statusCode,
      );
    }

    return response;
  }

  /// 生成唯一请求ID
  String _generateId() {
    return 'req_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  /// 生成指定长度的随机字符串
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (_) => chars[_randomInt(chars.length)]).join();
  }

  /// 生成指定范围内的随机整数
  int _randomInt(int max) {
    return DateTime.now().microsecond % max;
  }
}

/// HTTP 请求覆盖类
/// 通过 HttpOverrides 机制实现全局 HTTP 请求拦截
class _InspectorHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}
