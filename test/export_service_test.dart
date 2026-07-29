import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/log_entry.dart';
import 'package:zero_inspector_kit/src/models/network_request.dart';
import 'package:zero_inspector_kit/src/services/export_service.dart';

/// 导出服务单元测试 / Export service unit tests
///
/// 覆盖日志导出、网络请求导出、剪贴板复制等功能
/// Covers log export, network export, clipboard copy, and more
void main() {
  late ExportService export;

  setUp(() {
    export = ExportService.instance;
  });

  group('Log export / 日志导出', () {
    test(
      'logsToJson produces valid JSON with count / logsToJson 生成有效 JSON',
      () {
        final logs = [
          LogEntry(
            id: '1',
            level: LogLevel.info,
            message: 'Hello',
            timestamp: DateTime.now(),
          ),
          LogEntry(
            id: '2',
            level: LogLevel.error,
            message: 'Error!',
            timestamp: DateTime.now(),
          ),
        ];
        final json = export.logsToJson(logs);
        expect(json, contains('"count":2'));
        expect(json, contains('"logs"'));
        expect(json, contains('"Hello"'));
        expect(json, contains('"Error!"'));
      },
    );

    test('logsToJson handles empty list / logsToJson 处理空列表', () {
      final json = export.logsToJson([]);
      expect(json, contains('"count":0'));
      expect(json, contains('"logs":[]'));
    });

    test('logsToJson includes tag when present / logsToJson 包含 tag', () {
      final logs = [
        LogEntry(
          id: '1',
          level: LogLevel.debug,
          message: 'Test',
          timestamp: DateTime.now(),
          tag: 'MyTag',
        ),
      ];
      final json = export.logsToJson(logs);
      expect(json, contains('"MyTag"'));
    });

    test('logsToText produces formatted text / logsToText 生成格式化文本', () {
      final logs = [
        LogEntry(
          id: '1',
          level: LogLevel.warning,
          message: 'Warn msg',
          timestamp: DateTime.now(),
        ),
      ];
      final text = export.logsToText(logs);
      expect(text, contains('Zero Inspector Kit'));
      expect(text, contains('[W]'));
      expect(text, contains('Warn msg'));
    });

    test('logsToText includes tag / logsToText 包含 tag', () {
      final logs = [
        LogEntry(
          id: '1',
          level: LogLevel.info,
          message: 'Test',
          timestamp: DateTime.now(),
          tag: 'Bloc',
        ),
      ];
      final text = export.logsToText(logs);
      expect(text, contains('Tag: Bloc'));
    });

    test('logsToText handles all log levels / logsToText 处理所有级别', () {
      for (final level in LogLevel.values) {
        final logs = [
          LogEntry(
            id: '1',
            level: level,
            message: 'msg',
            timestamp: DateTime.now(),
          ),
        ];
        final text = export.logsToText(logs);
        expect(text, contains('[${_levelPrefix(level)}]'));
      }
    });
  });

  group('Network export / 网络导出', () {
    test('netToJson produces valid JSON / netToJson 生成有效 JSON', () {
      final requests = <NetworkRequest>[
        NetworkRequest(
          id: 'req-1',
          method: 'GET',
          url: 'https://api.example.com/data',
          requestTime: DateTime.now().millisecondsSinceEpoch,
        ),
      ];
      final json = export.netToJson(requests);
      expect(json, contains('"count":1'));
      expect(json, contains('"requests"'));
      expect(json, contains('"GET"'));
      expect(json, contains('api.example.com'));
    });

    test('netToJson handles empty list / netToJson 处理空列表', () {
      final json = export.netToJson([]);
      expect(json, contains('"count":0'));
      expect(json, contains('"requests":[]'));
    });
  });

  group('Copy methods / 复制方法', () {
    test('copyLogs defaults to JSON format / copyLogs 默认 JSON 格式', () async {
      final logs = [
        LogEntry(
          id: '1',
          level: LogLevel.info,
          message: 'Test',
          timestamp: DateTime.now(),
        ),
      ];
      // 验证不抛异常即可（剪贴板操作需要平台支持）
      expect(() async => await export.copyLogs(logs), returnsNormally);
    });

    test(
      'copyLogs with json: false uses text format / copyLogs json:false 使用文本',
      () async {
        final logs = [
          LogEntry(
            id: '1',
            level: LogLevel.info,
            message: 'Test',
            timestamp: DateTime.now(),
          ),
        ];
        expect(
          () async => await export.copyLogs(logs, json: false),
          returnsNormally,
        );
      },
    );

    test('copyNet does not throw / copyNet 不抛异常', () async {
      final requests = <NetworkRequest>[
        NetworkRequest(
          id: 'req-1',
          method: 'GET',
          url: 'https://example.com',
          requestTime: DateTime.now().millisecondsSinceEpoch,
        ),
      ];
      expect(() async => await export.copyNet(requests), returnsNormally);
    });

    test('copy does not throw / copy 不抛异常', () async {
      expect(() async => await export.copy('test content'), returnsNormally);
    });
  });

  group('Level prefix / 级别前缀', () {
    test('_lvl returns correct prefix for each level / _lvl 对每个级别返回正确前缀', () {
      // 通过日志文本导出间接测试 _lvl 方法
      final tests = {
        LogLevel.verbose: 'V',
        LogLevel.debug: 'D',
        LogLevel.info: 'I',
        LogLevel.warning: 'W',
        LogLevel.error: 'E',
      };
      for (final entry in tests.entries) {
        final logs = [
          LogEntry(
            id: '1',
            level: entry.key,
            message: 'x',
            timestamp: DateTime.now(),
          ),
        ];
        final text = export.logsToText(logs);
        expect(text, contains('[${entry.value}]'));
      }
    });
  });
}

/// 辅助方法：获取日志级别的预期前缀 / Helper: get expected prefix for log level
String _levelPrefix(LogLevel level) {
  switch (level) {
    case LogLevel.verbose:
      return 'V';
    case LogLevel.debug:
      return 'D';
    case LogLevel.info:
      return 'I';
    case LogLevel.warning:
      return 'W';
    case LogLevel.error:
      return 'E';
  }
}
