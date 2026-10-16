import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// ErrorService `onErrorReported` 上报钩子测试 / onErrorReported hook tests
///
/// 覆盖 v1.16.0 新增的自定义异常上报回调：聚合时触发、重复命中累加、
/// 历史回放不触发、宿主回调抛错不影响聚合管线、关闭抓取后不触发。
/// Covers the v1.16.0 custom error-reporting callback: fires on
/// aggregation, counts repeat hits, skips historical restore, survives a
/// throwing host callback, and stays silent when capture is disabled.
void main() {
  late ErrorService service;
  late List<ErrorRecord> reported;

  setUp(() {
    service = ErrorService.instance;
    service.clear();
    service.onErrorReported = null;
    reported = <ErrorRecord>[];
  });

  tearDown(() {
    service.onErrorReported = null;
    service.clear();
  });

  group('onErrorReported hook / 上报钩子', () {
    test('fires with the aggregated record on report / '
        'report() 时以聚合记录触发回调', () {
      service.onErrorReported = reported.add;

      service.report(StateError('boom'), StackTrace.current, 'test');

      expect(reported, hasLength(1));
      expect(reported.single.type, 'StateError');
      expect(reported.single.message, 'Bad state: boom');
      expect(reported.single.count, 1);
      expect(service.errorCount, 1);
    });

    test('fires again with an incremented count on repeat hits / '
        '同一崩溃重复命中时再次触发且计数累加', () {
      service.onErrorReported = reported.add;
      final stack = StackTrace.current;

      service.report(StateError('boom'), stack, 'test');
      service.report(StateError('boom'), stack, 'test');

      expect(reported, hasLength(2));
      expect(reported.last.count, 2);
      expect(service.errorCount, 1);
    });

    test('does not fire on restore() of persisted records / '
        'restore() 回放历史记录不触发回调', () {
      service.report(StateError('boom'), StackTrace.current, 'test');
      final persisted = service.errors.first;

      // 挂上钩子后再回放：历史记录不得触发上报 / Hook up only before the
      // restore so any fired callback would be a false positive.
      service.onErrorReported = reported.add;
      service.clear();
      service.restore([persisted]);

      expect(service.errorCount, 1);
      expect(reported, isEmpty);
    });

    test('a throwing host callback does not break aggregation / '
        '宿主回调抛错不影响聚合管线', () {
      service.onErrorReported = (record) => throw StateError('hook failed');

      expect(
        () => service.report(StateError('boom'), StackTrace.current, 'test'),
        returnsNormally,
      );
      expect(service.errorCount, 1);
      expect(service.errors.single.count, 1);
    });

    test('does not fire while capture is disabled / '
        '关闭抓取后不触发回调', () {
      service.isEnabled = false;
      service.onErrorReported = reported.add;

      service.report(StateError('boom'), StackTrace.current, 'test');

      expect(reported, isEmpty);
      expect(service.errorCount, 0);
    });
  });
}
