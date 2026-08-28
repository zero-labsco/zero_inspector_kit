import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/utils/device_info.dart';

void main() {
  test('collect returns expected keys', () {
    final info = DeviceInfoUtil.collect();
    expect(info['os'], isNotNull);
    expect(info['dartVersion'], isNotNull);
    expect(info.containsKey('locale'), isTrue);
    expect(info.containsKey('processors'), isTrue);
  });

  test('toReportString renders section header and entries', () {
    final report = DeviceInfoUtil.toReportString(DeviceInfoUtil.collect());
    expect(report, contains('=== Device / Environment ==='));
    expect(report, contains('os:'));
  });
}
