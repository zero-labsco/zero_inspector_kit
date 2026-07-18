import '../models/network_request.dart';
import '../services/inspector_service.dart';

/// Dio拦截器基类 / Dio interceptor base class
/// 定义Dio拦截器的三个生命周期方法 / Define three lifecycle methods for Dio interceptor
abstract class InspectorDioInterceptorBase {
  /// 请求发送前回调 / Callback before request is sent
  /// [options] 请求配置选项 / Request configuration options
  void onRequest(Map<String, dynamic> options);

  /// 请求成功响应回调 / Callback when request succeeds
  /// [response] 响应数据 / Response data
  void onResponse(Map<String, dynamic> response);

  /// 请求失败回调 / Callback when request fails
  /// [error] 错误信息 / Error information
  void onError(Map<String, dynamic> error);
}

/// Dio拦截器实现 / Dio interceptor implementation
/// 捕获Dio网络请求并记录到检查器服务 / Capture Dio network requests and record to inspector service
///
/// 使用方式 / Usage:
/// ```dart
/// import 'package:dio/dio.dart';
/// import 'package:zero_inspector_kit/zero_inspector_kit_dio.dart';
///
/// final dio = Dio();
/// dio.interceptors.add(
///   InterceptorWrapper(
///     onRequest: (options, handler) {
///       InspectorDioInterceptor().onRequest(options.toMap());
///       handler.next(options);
///     },
///     onResponse: (response, handler) {
///       InspectorDioInterceptor().onResponse(response.toMap());
///       handler.next(response);
///     },
///     onError: (error, handler) {
///       InspectorDioInterceptor().onError(error.toMap());
///       handler.next(error);
///     },
///   ),
/// );
/// ```
class InspectorDioInterceptor extends InspectorDioInterceptorBase {
  static const String _requestIdHeader = 'x-inspector-request-id';

  @override
  void onRequest(Map<String, dynamic> options) {
    String? requestId;
    if (options['headers'] is Map) {
      requestId = options['headers'][_requestIdHeader] as String?;
    }
    if (requestId == null) {
      requestId = _generateId();
      if (options['headers'] is Map) {
        options['headers'][_requestIdHeader] = requestId;
      }
    }
    final request = NetworkRequest(
      id: requestId,
      method: options['method'] as String? ?? 'GET',
      url: options['url'] as String? ?? '',
      headers: _convertHeaders(options['headers']),
      body: options['data'],
      requestTime: DateTime.now().millisecondsSinceEpoch,
    );
    InspectorService.instance.addNetworkRequest(request);
  }

  @override
  void onResponse(Map<String, dynamic> response) {
    final requestUrl = response['requestOptions']?['uri']?.toString() ?? '';
    final request = InspectorService.instance.networkRequests.firstWhere(
      (r) => r.url == requestUrl && r.responseTime == null,
      orElse: () => NetworkRequest(
        id: _generateId(),
        method: response['requestOptions']?['method'] as String? ?? 'GET',
        url: requestUrl,
        requestTime: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    InspectorService.instance.updateNetworkRequest(
      request.id,
      responseBody: response['data'],
      statusCode: response['statusCode'] as int?,
    );
  }

  @override
  void onError(Map<String, dynamic> error) {
    final requestUrl = error['requestOptions']?['uri']?.toString() ?? '';
    final request = InspectorService.instance.networkRequests.firstWhere(
      (r) => r.url == requestUrl && r.responseTime == null,
      orElse: () => NetworkRequest(
        id: _generateId(),
        method: error['requestOptions']?['method'] as String? ?? 'GET',
        url: requestUrl,
        requestTime: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    InspectorService.instance.updateNetworkRequest(
      request.id,
      responseBody: error['response']?['data'] ?? error['message'],
      statusCode: error['response']?['statusCode'] as int?,
    );
  }

  /// 生成唯一请求ID / Generate unique request ID
  String _generateId() {
    return 'req_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  /// 生成指定长度的随机字符串 / Generate random string of specified length
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (_) => chars[_randomInt(chars.length)]).join();
  }

  /// 生成指定范围内的随机整数 / Generate random integer within specified range
  int _randomInt(int max) {
    return DateTime.now().microsecond % max;
  }

  /// 转换headers为Map<String, String>格式 / Convert headers to Map<String, String> format
  /// Dio的headers可能包含非String类型的值（如content-length是int），需要转换 / Dio headers may contain non-String values (e.g., content-length is int), need conversion
  Map<String, String>? _convertHeaders(dynamic headers) {
    if (headers == null) return null;
    if (headers is Map<String, String>) return headers;
    if (headers is Map) {
      return headers.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    }
    return null;
  }
}
