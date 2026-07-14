import '../models/network_request.dart';
import '../services/inspector_service.dart';

abstract class InspectorDioInterceptorBase {
  void onRequest(Map<String, dynamic> options);
  void onResponse(Map<String, dynamic> response);
  void onError(Map<String, dynamic> error);
}

class InspectorDioInterceptor extends InspectorDioInterceptorBase {
  @override
  void onRequest(Map<String, dynamic> options) {
    final request = NetworkRequest(
      id: _generateId(),
      method: options['method'] as String? ?? 'GET',
      url: options['url'] as String? ?? '',
      headers: options['headers'] as Map<String, String>?,
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

  String _generateId() {
    return 'req_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (_) => chars[_randomInt(chars.length)]).join();
  }

  int _randomInt(int max) {
    return DateTime.now().microsecond % max;
  }
}