import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/utils/device_info.dart';

void main() {
  test('collect returns expected keys', () async {
    final info = await DeviceInfoUtil.collect();
    expect(info['model'], isNotNull);
    expect(info['os'], isNotNull);
    expect(info['dartVersion'], isNotNull);
    expect(info.containsKey('locale'), isTrue);
    expect(info.containsKey('processors'), isTrue);
  });

  test('toReportString renders section header and entries', () async {
    final report = DeviceInfoUtil.toReportString(
      await DeviceInfoUtil.collect(),
    );
    expect(report, contains('=== Device / Environment ==='));
    expect(report, contains('model:'));
    expect(report, contains('os:'));
  });
}
