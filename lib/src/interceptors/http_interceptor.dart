import 'package:http/http.dart' as http;
import '../models/network_request.dart';
import '../services/inspector_service.dart';

/// HTTP包网络请求拦截器
/// 自动捕获所有通过dart:http包发送的网络请求
/// 
/// 使用前需要在pubspec.yaml中添加http依赖:
/// ```yaml
/// dependencies:
///   http: ^1.0.0
/// ```
class InspectorHttpInterceptor {
  InspectorHttpInterceptor._();

  /// 单例实例
  static final InspectorHttpInterceptor instance = InspectorHttpInterceptor._();

  /// 发起GET请求并自动捕获
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

  /// 发起POST请求并自动捕获
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

  /// 发起PUT请求并自动捕获
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

  /// 发起DELETE请求并自动捕获
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

  /// 发起PATCH请求并自动捕获
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

  /// 发起HEAD请求并自动捕获
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

  /// 发起通用请求并自动捕获
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

  /// 生成随机字符串
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (_) => chars[_randomInt(chars.length)]).join();
  }

  /// 生成随机整数
  int _randomInt(int max) {
    return DateTime.now().microsecond % max;
  }
}