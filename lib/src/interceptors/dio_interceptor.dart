import 'dart:async';
import 'dart:convert';
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
      // 记录给面板看的头里也剔除关联 ID，避免它被误当成业务头（导出 / 复制 cURL
      // 时会带走）。The recorded headers drop the correlation ID too, so it is
      // never mistaken for a business header (exported / copied as cURL).
      headers: _convertHeaders(options['headers'], strip: _requestIdHeader),
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
      responseBody: _previewBody(response['data']),
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
    // 无 HTTP 响应（超时 / 网络错误等）：response 为 null，statusCode 用 -1 占位，
    // 否则 updateNetworkRequest 只在 statusCode != null 时才写耗时，请求会永挂“进行中”。
    // No HTTP response (timeout / network error): `response` is null, so use -1 as
    // a placeholder; otherwise a request would hang "in progress" forever.
    final statusCode = error['response']?['statusCode'] as int?;
    InspectorService.instance.updateNetworkRequest(
      request.id,
      responseBody: _previewBody(
        error['response']?['data'] ?? error['message'],
      ),
      statusCode: statusCode ?? -1,
    );
  }

  /// 把 Dio 的 `data` 转成可安全存入 body 的值，规避两类问题：
  /// - `responseType: stream` 时 data 是 ResponseBody（单次可读流）：既不读取也不
  ///   close 会泄漏底层 socket，且 `toString()` 只会变成 "Instance of 'ResponseBody'"。
  ///   这里按 run-time 特征识别（持有 `stream` 成员、且非字符串/Map/List），异步排空
  ///   流以释放底层连接，body 记为 null（面板显示无 body）。本文件刻意不依赖 dio 包，
  ///   故不引用 [ResponseBody] 类型，改用动态特征判断。
  /// - `responseType: bytes` 时 data 是原始字节列表，直接持有会常驻内存且 `toString()`
  ///   巨大；按预览上限截断后存 base64 字符串。
  /// Convert Dio `data` into a value safe to store as the body, avoiding two issues:
  /// a stream ResponseBody (socket leak + useless toString) and unbounded byte lists.
  /// This file deliberately does not depend on the `dio` package, so we detect the
  /// stream case by its runtime shape (a `stream` member that is a Stream) instead of
  /// referencing the `ResponseBody` type.
  dynamic _previewBody(dynamic data) {
    if (data != null && data is! String && data is! Map && data is! List) {
      // 可能是 ResponseBody：尝试读取 .stream 是否为 Stream，是则排空后记为 null。
      // Possibly a ResponseBody: try to read `.stream`; drain it and record null.
      try {
        final s = data.stream;
        if (s is Stream) {
          unawaited(s.listen((_) {}).asFuture().catchError((_) {}));
          return null;
        }
      } catch (_) {
        // 没有 .stream 成员，按普通对象处理。
        // No `.stream` member; treat as a normal object.
      }
    }
    if (data is List<int>) {
      final cap = InspectorService.instance.maxBodyPreviewBytes;
      final bytes = data.length > cap ? data.sublist(0, cap) : data;
      return base64Encode(bytes);
    }
    return data;
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
    // 1. 精确匹配：通过 request ID（正常路径，Dio 会把 onRequest 注入的
    //    x-inspector-request-id 透传到 response / error 的 requestOptions）。
    // Exact match by request ID (the normal path: Dio carries the request ID
    // injected in onRequest through to response / error requestOptions).
    if (requestId != null) {
      final requests = InspectorService.instance.networkRequests;
      final byId = requests.where((r) => r.id == requestId);
      if (byId.isNotEmpty) return byId.first;
    }

    // 2. 模糊匹配（仅当 request ID 缺失时，兼容旧 / 异常集成）：
    //    选 URL 相同且尚未响应、且「挂起最久」的那条，以缓解并发同 URL 轮询的错配
    //    （首条匹配会命中最新插入的请求，反而更易错配）。
    // Fuzzy match (only when request ID is missing, backward-compat): pick the
    // longest-pending same-URL request without a response, reducing mis-association
    // under concurrent same-URL polling (firstWhere would match the newest insert).
    NetworkRequest? fallback;
    var oldestTime = 0x7fffffffffffffff;
    for (final r in InspectorService.instance.networkRequests) {
      if (r.url == url &&
          r.responseTime == null &&
          r.requestTime < oldestTime) {
        oldestTime = r.requestTime;
        fallback = r;
      }
    }
    if (fallback != null) return fallback;
    final created = NetworkRequest(
      id: requestId ?? _generateId(),
      method: 'GET',
      url: url,
      requestTime: DateTime.now().millisecondsSinceEpoch,
    );
    InspectorService.instance.addNetworkRequest(created);
    return created;
  }

  /// 生成唯一请求ID / Generate unique request ID
  ///
  /// 格式：req_<微秒时间戳>_<8位随机>_<自增计数器>
  /// Format: req_&lt;microsecond-timestamp&gt;_&lt;8-char-random&gt;_&lt;monotonic-counter&gt;
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
  ///
  /// [strip] 需要从结果中剔除的头名（大小写不敏感），用于去掉检查器自身的关联头。
  /// [strip] header name to drop from the result (case-insensitive), used to
  /// remove the inspector's own correlation header.
  Map<String, String>? _convertHeaders(dynamic headers, {String? strip}) {
    if (headers == null) return null;
    Map<String, String> converted;
    if (headers is Map<String, String>) {
      converted = headers;
    } else if (headers is Map) {
      converted = headers.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      );
    } else {
      return null;
    }
    if (strip == null) return converted;
    final target = strip.toLowerCase();
    return Map<String, String>.fromEntries(
      converted.entries.where((e) => e.key.toLowerCase() != target),
    );
  }
}
