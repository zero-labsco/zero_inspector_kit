import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/log_entry.dart';
import 'package:zero_inspector_kit/src/models/network_request.dart';
import 'package:zero_inspector_kit/src/services/export_service.dart';

void main() {
  test('buildBugReport includes device, logs and network sections', () {
    final report = ExportService.instance.buildBugReport(
      deviceInfo: '=== Device / Environment ===\nos: android',
      logs: [
        LogEntry(
          id: '1',
          level: LogLevel.info,
          message: 'hello-log',
          timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ],
      requests: [
        NetworkRequest(
          id: 'r1',
          method: 'GET',
          url: 'https://example.com/api',
          requestTime: 0,
        ),
      ],
    );
    expect(report, contains('Zero Inspector Kit — Bug Report'));
    expect(report, contains('=== Device / Environment ==='));
    expect(report, contains('hello-log'));
    expect(report, contains('curl -X GET'));
  });

  test('buildBugReport masks sensitive headers when requested', () {
    final report = ExportService.instance.buildBugReport(
      deviceInfo: 'dev',
      requests: [
        NetworkRequest(
          id: 'r1',
          method: 'GET',
          url: 'https://example.com',
          headers: {'Authorization': 'secret-token'},
          requestTime: 0,
        ),
      ],
      maskSensitive: true,
    );
    expect(report, isNot(contains('secret-token')));
    expect(report, contains('***'));
  });
}
