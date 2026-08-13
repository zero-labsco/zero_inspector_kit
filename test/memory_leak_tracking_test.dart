import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/services/memory_inspector_service.dart';
import 'package:zero_inspector_kit/src/utils/memory_leak_tracking.dart';

/// 简化内存泄漏追踪 API 单元测试 / Simplified memory leak tracking API unit tests
///
/// 验证顶层函数 trackMemoryLeak / untrackMemoryLeak 和 Object 扩展方法
/// 均能正确委托给 MemoryInspectorService
/// Verifies top-level functions and Object extension methods correctly delegate
/// to MemoryInspectorService
void main() {
  /// 每个测试前重置状态 / Reset state before each test
  setUp(() {
    MemoryInspectorService.instance.clearLeakRecords();
  });

  /// 每个测试后清理 / Cleanup after each test
  tearDown(() {
    MemoryInspectorService.instance.clearLeakRecords();
  });

  /// ========================================================================
  /// 顶层函数 / Top-level functions
  /// ========================================================================
  group('trackMemoryLeak() top-level function', () {
    test(
      'trackMemoryLeak 注册对象并返回 identityHashCode / trackMemoryLeak registers object and returns identityHashCode',
      () {
        final obj = Object();
        final id = trackMemoryLeak(obj, tag: 'TopLevel');
        expect(id, equals(identityHashCode(obj)));
        final records = MemoryInspectorService.instance.leakRecords;
        expect(records.length, equals(1));
        expect(records[0].tag, equals('TopLevel'));
        expect(records[0].status.toString(), contains('tracking'));
      },
    );

    test(
      'trackMemoryLeak 支持 expectedReleaseAfter / trackMemoryLeak supports expectedReleaseAfter',
      () {
        final obj = Object();
        trackMemoryLeak(
          obj,
          tag: 'Short',
          expectedReleaseAfter: const Duration(seconds: 5),
        );
        final record = MemoryInspectorService.instance.leakRecords[0];
        expect(
          record.expectedReleaseAt.difference(record.trackedAt).inSeconds,
          equals(5),
        );
      },
    );

    test('untrackMemoryLeak 通过对象移除 / untrackMemoryLeak removes by object', () {
      final obj = Object();
      trackMemoryLeak(obj);
      expect(MemoryInspectorService.instance.leakRecords.length, equals(1));
      untrackMemoryLeak(obj);
      expect(MemoryInspectorService.instance.leakRecords, isEmpty);
    });

    test('untrackMemoryLeak 通过 ID 移除 / untrackMemoryLeak removes by ID', () {
      final obj = Object();
      final id = trackMemoryLeak(obj);
      untrackMemoryLeak(id);
      expect(MemoryInspectorService.instance.leakRecords, isEmpty);
    });
  });

  /// ========================================================================
  /// Object 扩展方法 / Object extension methods
  /// ========================================================================
  group('Object.trackMemoryLeak() extension', () {
    test(
      '扩展方法注册对象并返回 identityHashCode / Extension registers object and returns identityHashCode',
      () {
        final obj = Object();
        final id = obj.trackMemoryLeak(tag: 'Extension');
        expect(id, equals(identityHashCode(obj)));
        final records = MemoryInspectorService.instance.leakRecords;
        expect(records.length, equals(1));
        expect(records[0].tag, equals('Extension'));
      },
    );

    test(
      '扩展方法支持 expectedReleaseAfter / Extension supports expectedReleaseAfter',
      () {
        final obj = Object();
        obj.trackMemoryLeak(
          tag: 'ExtShort',
          expectedReleaseAfter: const Duration(seconds: 3),
        );
        final record = MemoryInspectorService.instance.leakRecords[0];
        expect(
          record.expectedReleaseAt.difference(record.trackedAt).inSeconds,
          equals(3),
        );
      },
    );

    test(
      '扩展方法 untrackMemoryLeak 移除当前对象 / Extension untrackMemoryLeak removes current object',
      () {
        final obj = Object();
        obj.trackMemoryLeak();
        expect(MemoryInspectorService.instance.leakRecords.length, equals(1));
        obj.untrackMemoryLeak();
        expect(MemoryInspectorService.instance.leakRecords, isEmpty);
      },
    );
  });

  /// ========================================================================
  /// 顶层函数与扩展方法一致性 / Consistency between top-level and extension
  /// ========================================================================
  group('Consistency', () {
    test(
      '同一对象通过顶层函数和扩展方法返回相同 ID / Same object returns same ID via top-level and extension',
      () {
        final obj = Object();
        final id1 = trackMemoryLeak(obj);
        final id2 = obj.trackMemoryLeak();
        expect(id1, equals(id2));
        // 因为同一 objectId 被覆盖，所以只有一条记录 / Same objectId overwritten, only one record
        expect(MemoryInspectorService.instance.leakRecords.length, equals(1));
      },
    );

    test(
      '顶层函数 untrack 后扩展方法查询不到 / Top-level untrack removes record from extension perspective',
      () {
        final obj = Object();
        obj.trackMemoryLeak(tag: 'Mix');
        untrackMemoryLeak(obj);
        expect(MemoryInspectorService.instance.leakRecords, isEmpty);
      },
    );
  });
}
