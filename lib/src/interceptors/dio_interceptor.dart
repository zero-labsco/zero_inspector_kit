import 'dart:math';

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

  /// 加密随机源 / Cryptographic random source
  ///
  /// 用 [Random.secure] 而非基于 [DateTime.now] 的派生值，
  /// 避免同一微秒内的并发请求生成相同 ID。
  /// Use [Random.secure] instead of [DateTime.now]-derived values to avoid
  /// ID collisions for concurrent requests in the same microsecond.
  static final Random _random = Random.secure();

  /// 进程内单调递增计数器，作为 ID 唯一性的最后一道防线
  /// Process-wide monotonic counter as the last line of defense for ID uniqueness
  static int _idCounter = 0;

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
    // 优先通过 request ID 匹配，避免并发同 URL 请求错乱
    // Prefer matching by request ID to avoid wrong association for concurrent same-URL requests
    final requestId = _extractRequestId(response['requestOptions']);
    final requestUrl = response['requestOptions']?['uri']?.toString() ?? '';
    final request = _findRequestByIdOrUrl(requestId, requestUrl);
    InspectorService.instance.updateNetworkRequest(
      request.id,
      responseBody: response['data'],
      statusCode: response['statusCode'] as int?,
    );
  }

  @override
  void onError(Map<String, dynamic> error) {
    // 优先通过 request ID 匹配，避免并发同 URL 请求错乱
    // Prefer matching by request ID to avoid wrong association for concurrent same-URL requests
    final requestId = _extractRequestId(error['requestOptions']);
    final requestUrl = error['requestOptions']?['uri']?.toString() ?? '';
    final request = _findRequestByIdOrUrl(requestId, requestUrl);
    InspectorService.instance.updateNetworkRequest(
      request.id,
      responseBody: error['response']?['data'] ?? error['message'],
      statusCode: error['response']?['statusCode'] as int?,
    );
  }

  /// 从 requestOptions 中提取 request ID / Extract request ID from requestOptions
  String? _extractRequestId(dynamic requestOptions) {
    if (requestOptions is Map) {
      final headers = requestOptions['headers'];
      if (headers is Map) {
        return headers[_requestIdHeader] as String?;
      }
    }
    return null;
  }

  /// 通过 request ID 或 URL 查找匹配的请求 / Find matching request by ID or URL
  ///
  /// 优先按 ID 匹配（精确），回退按 URL + 未响应匹配（模糊，兼容旧行为）
  /// Prefer matching by ID (exact), fall back to URL + no responseTime (fuzzy, backward compatible)
  NetworkRequest _findRequestByIdOrUrl(String? requestId, String url) {
    // 1. 精确匹配：通过 request ID / Exact match: by request ID
    if (requestId != null) {
      final requests = InspectorService.instance.networkRequests;
      final byId = requests.where((r) => r.id == requestId);
      if (byId.isNotEmpty) return byId.first;
    }

    // 2. 模糊匹配：通过 URL + 未响应（兼容旧逻辑）/ Fuzzy: URL + no responseTime
    final request = InspectorService.instance.networkRequests.firstWhere(
      (r) => r.url == url && r.responseTime == null,
      orElse: () => NetworkRequest(
        id: requestId ?? _generateId(),
        method: 'GET',
        url: url,
        requestTime: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    return request;
  }

  /// 生成唯一请求ID / Generate unique request ID
  ///
  /// 格式：req_<微秒时间戳>_<8位随机>_<自增计数器>
  /// Format: req_<microsecond-timestamp>_<8-char-random>_<monotonic-counter>
  ///
  /// 计数器确保即使随机源在同一 tick 内重复，ID 也仍然唯一
  /// The counter ensures uniqueness even if the random source repeats within
  /// the same tick.
  String _generateId() {
    final n = ++_idCounter;
    return 'req_${DateTime.now().microsecondsSinceEpoch}_${_randomString(8)}_$n';
  }

  /// 生成指定长度的随机字符串 / Generate random string of specified length
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }

  /// 转换headers为 `Map<String, String>` 格式 / Convert headers to `Map<String, String>` format
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
