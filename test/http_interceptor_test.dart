import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/network_request.dart';
import 'package:zero_inspector_kit/src/services/inspector_service.dart';

/// HTTP 拦截器单元测试 / HTTP interceptor unit tests
///
/// 覆盖请求体捕获、拦截规则应用、响应体捕获等关键功能
/// Covers request body capture, interceptor rule application, response body capture
void main() {
  group('InspectorService network request tracking', () {
    setUp(() {
      InspectorService.instance.clearNetworkRequests();
    });

    tearDown(() {
      InspectorService.instance.clearNetworkRequests();
    });

    test(
      'updateNetworkRequest should capture empty request body after rule modification',
      () {
        // 这是一个回归测试,修复了一个缺陷:
        // Regression test for a defect fix:
        // 当拦截规则将请求体修改为空字符串时,updateNetworkRequest 应该被调用
        // When interceptor rule modifies request body to empty string,
        // updateNetworkRequest should still be called

        // 1. 添加一个网络请求记录
        final requestId = 'test_req_001';
        InspectorService.instance.addNetworkRequest(
          NetworkRequest(
            id: requestId,
            method: 'POST',
            url: 'https://api.example.com/data',
            requestTime: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        // 2. 更新请求体为空字符串(模拟拦截规则修改)
        InspectorService.instance.updateNetworkRequest(requestId, body: '');

        // 3. 验证请求体被正确更新
        final request = InspectorService.instance.findNetworkRequest(requestId);
        expect(request, isNotNull);
        expect(request!.body, equals(''));
      },
    );

    test('updateNetworkRequest should capture non-empty request body', () {
      // 验证正常的非空请求体更新
      final requestId = 'test_req_002';
      InspectorService.instance.addNetworkRequest(
        NetworkRequest(
          id: requestId,
          method: 'POST',
          url: 'https://api.example.com/data',
          requestTime: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      final requestBody = '{"key": "value"}';
      InspectorService.instance.updateNetworkRequest(
        requestId,
        body: requestBody,
      );

      final request = InspectorService.instance.findNetworkRequest(requestId);
      expect(request, isNotNull);
      expect(request!.body, equals(requestBody));
    });

    test('updateNetworkRequest should update response correctly', () {
      // 验证响应信息的正确更新
      final requestId = 'test_req_003';
      final requestTime = DateTime.now().millisecondsSinceEpoch;

      InspectorService.instance.addNetworkRequest(
        NetworkRequest(
          id: requestId,
          method: 'GET',
          url: 'https://api.example.com/data',
          requestTime: requestTime,
        ),
      );

      // 模拟响应到达
      final responseBody = '{"status": "ok"}';
      InspectorService.instance.updateNetworkRequest(
        requestId,
        responseBody: responseBody,
        statusCode: 200,
      );

      final request = InspectorService.instance.findNetworkRequest(requestId);
      expect(request, isNotNull);
      expect(request!.responseBody, equals(responseBody));
      expect(request.statusCode, equals(200));
      expect(request.responseTime, isNotNull);
      expect(request.duration, isNotNull);
    });

    test(
      'updateNetworkRequest(modified: true) sets isModifiedByInterceptor',
      () {
        // 拦截规则命中并实际修改请求时，应回写拦截标记。
        // When an interceptor rule actually modifies the request, the flag
        // should be written back.
        final requestId = 'test_req_010';
        final requestTime = DateTime.now().millisecondsSinceEpoch;

        InspectorService.instance.addNetworkRequest(
          NetworkRequest(
            id: requestId,
            method: 'POST',
            url: 'https://api.example.com/data',
            requestTime: requestTime,
          ),
        );

        // 请求侧命中规则修改头/体
        InspectorService.instance.updateNetworkRequest(
          requestId,
          body: '{"k":"v"}',
          modified: true,
        );

        final modified = InspectorService.instance.findNetworkRequest(
          requestId,
        );
        expect(modified!.isModifiedByInterceptor, isTrue);

        // 后续仅更新响应（不带 modified）不应把标记清零（sticky）。
        // A later update without [modified] must NOT clear the flag (sticky).
        InspectorService.instance.updateNetworkRequest(
          requestId,
          statusCode: 200,
          responseBody: '{"ok":true}',
        );

        final afterResponse = InspectorService.instance.findNetworkRequest(
          requestId,
        );
        expect(afterResponse!.isModifiedByInterceptor, isTrue);
      },
    );

    test('updateNetworkRequest without modified keeps flag false', () {
      // 普通流程（无拦截修改）不应误置标记。
      // A normal flow (no interceptor modification) must not set the flag.
      final requestId = 'test_req_011';
      final requestTime = DateTime.now().millisecondsSinceEpoch;

      InspectorService.instance.addNetworkRequest(
        NetworkRequest(
          id: requestId,
          method: 'GET',
          url: 'https://api.example.com/data',
          requestTime: requestTime,
        ),
      );

      InspectorService.instance.updateNetworkRequest(
        requestId,
        statusCode: 200,
        responseBody: '{"ok":true}',
      );

      final request = InspectorService.instance.findNetworkRequest(requestId);
      expect(request!.isModifiedByInterceptor, isFalse);
    });
  });
}
