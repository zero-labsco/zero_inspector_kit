import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/network_request.dart';

/// 状态码分组筛选逻辑单测 / Status-group filter logic tests.
///
/// 覆盖「按状态码区间筛选」维度的核心判定 [StatusGroup.contains]，
/// 这是 network_viewer 筛选面板的状态码分组依据。
/// Covers the core [StatusGroup.contains] predicate used by the status-code
/// filter dimension in the network viewer's filter panel.
void main() {
  group('StatusGroup.contains()', () {
    test('2xx 区间命中 200-299 / 2xx matches 200-299', () {
      expect(StatusGroup.s2xx.contains(200), isTrue);
      expect(StatusGroup.s2xx.contains(250), isTrue);
      expect(StatusGroup.s2xx.contains(299), isTrue);
      // 边界外不命中 / out of range
      expect(StatusGroup.s2xx.contains(199), isFalse);
      expect(StatusGroup.s2xx.contains(300), isFalse);
    });

    test('3xx / 4xx / 5xx 各自区间命中 / each range matches', () {
      expect(StatusGroup.s3xx.contains(301), isTrue);
      expect(StatusGroup.s3xx.contains(399), isTrue);
      expect(StatusGroup.s4xx.contains(404), isTrue);
      expect(StatusGroup.s4xx.contains(499), isTrue);
      expect(StatusGroup.s5xx.contains(500), isTrue);
      expect(StatusGroup.s5xx.contains(599), isTrue);
      // 不跨区间 / no cross-range
      expect(StatusGroup.s3xx.contains(404), isFalse);
      expect(StatusGroup.s4xx.contains(500), isFalse);
    });

    test(
      'unknown 命中 200-599 之外的码与 null / unknown matches outside 200-599 and null',
      () {
        expect(StatusGroup.unknown.contains(100), isTrue);
        expect(StatusGroup.unknown.contains(599), isFalse);
        expect(StatusGroup.unknown.contains(600), isTrue);
        expect(StatusGroup.unknown.contains(999), isTrue);
        // 无状态码的请求归入 Other / a request without status belongs to Other
        expect(StatusGroup.unknown.contains(null), isTrue);
        // 其他分组不命中 null / other groups reject null
        expect(StatusGroup.s2xx.contains(null), isFalse);
      },
    );

    test('枚举标签正确 / enum labels are correct', () {
      expect(StatusGroup.s2xx.label, equals('2xx'));
      expect(StatusGroup.s3xx.label, equals('3xx'));
      expect(StatusGroup.s4xx.label, equals('4xx'));
      expect(StatusGroup.s5xx.label, equals('5xx'));
      expect(StatusGroup.unknown.label, equals('Other'));
    });
  });
}
