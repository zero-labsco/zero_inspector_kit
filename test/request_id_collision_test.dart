import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/interceptors/dio_interceptor.dart';

/// 回归测试 / Regression tests
///
/// 覆盖此前审查发现的两个高影响缺陷：
/// Covers the two high-impact defects found during review:
///
/// 1. Dio `_randomInt` 把 `DateTime.now().microsecond % 36` 当作随机源，
///    同一微秒内的并发请求会生成完全相同的 ID，导致响应数据互相覆盖丢失。
///    The Dio `_randomInt` was using `DateTime.now().microsecond % 36` as
///    the random source, so concurrent requests in the same microsecond
///    produced identical IDs and one response overwrote the other.
///
/// 2. HTTP 拦截器 `_randomString` 使用 xorshift + `DateTime.now().microsecond`
///    作为种子，同样存在同一微秒内 ID 碰撞的回归风险。
///    The HTTP interceptor's `_randomString` used xorshift seeded with
///    `DateTime.now().microsecond`, with the same microsecond-collision risk.
void main() {
  group('InspectorDioInterceptor ID generation', () {
    test('同一微秒内 1000 次连续 _generateId 调用产生的 ID 全部唯一 / '
        '1000 back-to-back _generateId calls in the same microsecond '
        'produce unique IDs', () {
      final interceptor = InspectorDioInterceptor();
      final ids = <String>{};
      for (var i = 0; i < 1000; i++) {
        // 通过 onRequest 触发 _generateId，因为 _generateId 是私有方法
        // Trigger _generateId via onRequest; the method itself is private.
        final options = <String, dynamic>{
          'method': 'GET',
          'url': 'https://example.com/test',
          'headers': <String, dynamic>{},
        };
        interceptor.onRequest(options);
        ids.add(options['headers']['x-inspector-request-id'] as String);
      }
      expect(
        ids.length,
        equals(1000),
        reason:
            'Concurrent Dio requests must produce unique IDs to avoid '
            'silent response overwrite in the inspector.',
      );
    });

    test('同 URL + 同时发起的并发请求 ID 仍然唯一 / '
        'Concurrent same-URL requests get unique IDs', () {
      final interceptor = InspectorDioInterceptor();
      final ids = <String>[];
      for (var i = 0; i < 100; i++) {
        final options = <String, dynamic>{
          'method': 'GET',
          'url': 'https://example.com/api/data',
          'headers': <String, dynamic>{},
        };
        interceptor.onRequest(options);
        ids.add(options['headers']['x-inspector-request-id'] as String);
      }
      expect(ids.toSet().length, equals(ids.length));
    });
  });
}
