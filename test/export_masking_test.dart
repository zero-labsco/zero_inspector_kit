import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// 导出链路各格式都必须尊重 `maskSensitive` 的回归测试。
/// Regression tests: every export format must honor `maskSensitive`.
void main() {
  final log = LogEntry(
    id: 'l1',
    level: LogLevel.info,
    message: 'Bearer eyJhbGciOi.abcdefgh.ijklmnop',
    timestamp: DateTime.fromMillisecondsSinceEpoch(0),
    tag: 'phone 13800138000',
  );

  final request = NetworkRequest(
    id: 'r1',
    method: 'GET',
    url: 'https://example.com/api?token=abc123',
    requestTime: 0,
  );

  test('log JSON export honors maskSensitive', () {
    final plain = ExportService.instance.logsToJson([log]);
    expect(plain, contains('eyJhbGciOi'));
    expect(plain, contains('13800138000'));

    final masked = ExportService.instance.logsToJson([
      log,
    ], maskSensitive: true);
    expect(masked, isNot(contains('eyJhbGciOi')));
    expect(masked, isNot(contains('13800138000')));
    expect(masked, contains(SensitiveData.placeholder));
  });

  test('log text export honors maskSensitive', () {
    final masked = ExportService.instance.logsToText([
      log,
    ], maskSensitive: true);
    expect(masked, isNot(contains('eyJhbGciOi')));
    expect(masked, isNot(contains('13800138000')));
  });

  test('CSV export honors maskSensitive (previously ignored)', () {
    final plain = ExportService.instance.netToCsv([request]);
    expect(plain, contains('abc123'));

    final masked = ExportService.instance.netToCsv([
      request,
    ], maskSensitive: true);
    expect(masked, isNot(contains('abc123')));
    expect(masked, contains('token='));
  });
}
