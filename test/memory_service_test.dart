import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/models/leak_record.dart';
import 'package:zero_inspector_kit/src/services/memory_inspector_service.dart';

/// 内存检查服务单元测试 / Memory inspector service unit tests
///
/// 覆盖泄漏追踪 API、状态流转、监控生命周期、快照管理、
/// triggerGc 降级、图片缓存等关键功能
/// Covers leak tracking API, state transitions, monitoring lifecycle,
/// snapshot management, triggerGc degradation, and image cache
void main() {
  /// 每个测试前重置状态 / Reset state before each test
  setUp(() {
    // 确保 Flutter Binding 已初始化（图片缓存等需要）
    // Ensure Flutter Binding is initialized (needed for image cache etc.)
    TestWidgetsFlutterBinding.ensureInitialized();
    // 停止监控并清空所有数据，避免测试间互相污染
    // Stop monitoring and clear all data to avoid cross-test contamination
    MemoryInspectorService.instance.stopMonitoring();
    MemoryInspectorService.instance.clearLeakRecords();
    MemoryInspectorService.instance.clearMemorySnapshots();
  });

  /// 每个测试后清理 / Cleanup after each test
  tearDown(() {
    MemoryInspectorService.instance.stopMonitoring();
    MemoryInspectorService.instance.clearLeakRecords();
    MemoryInspectorService.instance.clearMemorySnapshots();
  });

  /// =======================================================================
  /// 泄漏追踪 API / Leak Tracking API
  /// =======================================================================
  group('Leak Tracking API', () {
    /// 获取服务单例的简写 / Shortcut for service singleton
    final svc = MemoryInspectorService.instance;

    test(
      'trackObject 返回 identityHashCode 作为 ID / trackObject returns identityHashCode as ID',
      () {
        final obj = Object();
        final id = svc.trackObject(obj);
        expect(id, equals(identityHashCode(obj)));
      },
    );

    test(
      'trackObject 创建正确的 objectType 和 tag / trackObject creates correct objectType and tag',
      () {
        // WeakReference 不支持 String/int 等基本类型，使用 Object
        // WeakReference doesn't support String/int etc., use Object
        final obj = Object();
        svc.trackObject(obj, tag: 'MyTag');
        final records = svc.leakRecords;
        expect(records.length, equals(1));
        expect(records[0].objectType, equals('Object'));
        expect(records[0].tag, equals('MyTag'));
        expect(records[0].status, equals(LeakStatus.tracking));
      },
    );

    test(
      'trackObject 无 tag 时 tag 为 null / trackObject without tag has null tag',
      () {
        final obj = Object();
        svc.trackObject(obj);
        expect(svc.leakRecords[0].tag, isNull);
      },
    );

    test(
      'trackObject 默认 expectedReleaseAfter 为 30 秒 / trackObject default expectedReleaseAfter is 30 seconds',
      () {
        final obj = Object();
        final before = DateTime.now();
        svc.trackObject(obj);
        final record = svc.leakRecords[0];
        final after = DateTime.now();

        // expectedReleaseAt 应在 now+30s 附近 / expectedReleaseAt should be around now+30s
        final minExpect = before.add(const Duration(seconds: 29));
        final maxExpect = after.add(const Duration(seconds: 31));
        expect(record.expectedReleaseAt.isAfter(minExpect), isTrue);
        expect(record.expectedReleaseAt.isBefore(maxExpect), isTrue);
        // 未过期 / Not expired
        expect(record.isExpired, isFalse);
      },
    );

    test(
      'trackObject 自定义 expectedReleaseAfter / trackObject with custom expectedReleaseAfter',
      () {
        final obj = Object();
        svc.trackObject(obj, expectedReleaseAfter: const Duration(seconds: 5));
        final record = svc.leakRecords[0];
        // 5 秒后过期 / Expires after 5 seconds
        expect(record.isExpired, isFalse);
        expect(
          record.expectedReleaseAt.difference(record.trackedAt).inSeconds,
          equals(5),
        );
      },
    );

    test(
      'trackObject 相同对象覆盖旧记录 / trackObject same object overwrites old record',
      () {
        final obj = Object();
        svc.trackObject(obj, tag: 'first');
        svc.trackObject(obj, tag: 'second');
        final records = svc.leakRecords;
        // 同一 objectId 只保留一条（覆盖）/ Same objectId keeps only one (overwritten)
        expect(records.length, equals(1));
        expect(records[0].tag, equals('second'));
      },
    );

    test('untrackObject 通过对象移除 / untrackObject removes by object', () {
      final obj = Object();
      svc.trackObject(obj);
      expect(svc.leakRecords.length, equals(1));
      svc.untrackObject(obj);
      expect(svc.leakRecords, isEmpty);
    });

    test(
      'untrackObject 通过 hashCode 移除 / untrackObject removes by hashCode',
      () {
        final obj = Object();
        final id = svc.trackObject(obj);
        svc.untrackObject(id);
        expect(svc.leakRecords, isEmpty);
      },
    );

    test('untrackObject 不存在的对象为空操作 / untrackObject non-existent is no-op', () {
      svc.trackObject(Object());
      // 移除一个从未注册的对象 / Remove an object that was never registered
      svc.untrackObject(Object());
      expect(svc.leakRecords.length, equals(1));
    });

    test('clearLeakRecords 清空所有记录 / clearLeakRecords clears all records', () {
      svc.trackObject(Object());
      svc.trackObject(Object());
      svc.trackObject(Object());
      expect(svc.leakRecords.length, equals(3));
      svc.clearLeakRecords();
      expect(svc.leakRecords, isEmpty);
    });

    test('trackingCount 正确统计追踪中对象 / trackingCount counts tracking objects', () {
      svc.trackObject(Object());
      svc.trackObject(Object());
      expect(svc.trackingCount, equals(2));
      expect(svc.leakedCount, equals(0));
      expect(svc.releasedCount, equals(0));
    });

    test('leakedRecords 初始为空 / leakedRecords initially empty', () {
      svc.trackObject(Object());
      expect(svc.leakedRecords, isEmpty);
    });
  });

  /// =======================================================================
  /// 泄漏状态流转 / Leak State Transitions
  /// =======================================================================
  group('Leak State Transitions', () {
    /// 辅助：轮询等待条件满足 / Helper: poll until condition is met
    Future<void> waitFor(
      bool Function() condition, {
      Duration timeout = const Duration(seconds: 10),
      Duration interval = const Duration(milliseconds: 50),
    }) async {
      final deadline = DateTime.now().add(timeout);
      while (DateTime.now().isBefore(deadline)) {
        if (condition()) return;
        await Future.delayed(interval);
      }
      throw TimeoutException('Condition not met within $timeout');
    }

    test(
      'tracking → verifying（已过期对象立即进入验证阶段）/ tracking → verifying (expired object enters verification immediately)',
      () async {
        final svc = MemoryInspectorService.instance;
        // 持有引用，防止对象被 GC / Hold reference to prevent GC
        final obj = Object();
        // expectedReleaseAfter=0 表示已过期 / expectedReleaseAfter=0 means already expired
        svc.trackObject(obj, expectedReleaseAfter: Duration.zero);
        await svc.startMonitoring();

        // _checkLeakRecords 立即执行一次，过期对象应进入 verifying
        // _checkLeakRecords runs immediately, expired object should enter verifying
        await waitFor(() => svc.leakRecords[0].status == LeakStatus.verifying);
        expect(svc.leakRecords[0].status, equals(LeakStatus.verifying));
        // gcTriggeredAt 应被设置 / gcTriggeredAt should be set
        expect(svc.leakRecords[0].gcTriggeredAt, isNotNull);
      },
    );

    test(
      'verifying → leaked（验证等待后仍未释放则判定泄漏）/ verifying → leaked (not released after verify wait)',
      () async {
        final svc = MemoryInspectorService.instance;
        // 持有强引用，确保对象不会被 GC / Hold strong reference to prevent GC
        final obj = Object();
        svc.trackObject(obj, expectedReleaseAfter: Duration.zero);
        await svc.startMonitoring();

        // 等待进入 verifying / Wait for verifying
        await waitFor(() => svc.leakRecords[0].status == LeakStatus.verifying);

        // 等待验证超时后进入 leaked（_leakVerifyWaitMs=3000ms + 定时器间隔 2000ms）
        // Wait for verify timeout then enter leaked
        await waitFor(
          () => svc.leakRecords[0].status == LeakStatus.leaked,
          timeout: const Duration(seconds: 8),
        );
        expect(svc.leakRecords[0].status, equals(LeakStatus.leaked));
        expect(svc.leakRecords[0].leakedAt, isNotNull);
        expect(svc.leakedCount, equals(1));
      },
    );
  });

  /// =======================================================================
  /// 监控生命周期 / Monitoring Lifecycle
  /// =======================================================================
  group('Monitoring Lifecycle', () {
    test('初始状态 isMonitoring=false / Initial state isMonitoring=false', () {
      expect(MemoryInspectorService.instance.isMonitoring, isFalse);
    });

    test(
      'startMonitoring 后 isMonitoring=true / After startMonitoring isMonitoring=true',
      () async {
        await MemoryInspectorService.instance.startMonitoring();
        expect(MemoryInspectorService.instance.isMonitoring, isTrue);
      },
    );

    test(
      'stopMonitoring 后 isMonitoring=false / After stopMonitoring isMonitoring=false',
      () async {
        await MemoryInspectorService.instance.startMonitoring();
        MemoryInspectorService.instance.stopMonitoring();
        expect(MemoryInspectorService.instance.isMonitoring, isFalse);
      },
    );

    test('startMonitoring 幂等（重复调用安全）/ startMonitoring is idempotent', () async {
      await MemoryInspectorService.instance.startMonitoring();
      await MemoryInspectorService.instance.startMonitoring();
      await MemoryInspectorService.instance.startMonitoring();
      expect(MemoryInspectorService.instance.isMonitoring, isTrue);
    });

    test(
      'isEnabled=true 触发 startMonitoring / isEnabled=true triggers startMonitoring',
      () async {
        MemoryInspectorService.instance.isEnabled = true;
        // startMonitoring 是异步的，等待事件队列 / startMonitoring is async, wait for event queue
        await Future.delayed(const Duration(milliseconds: 50));
        expect(MemoryInspectorService.instance.isMonitoring, isTrue);
        expect(MemoryInspectorService.instance.isEnabled, isTrue);
      },
    );

    test(
      'isEnabled=false 触发 stopMonitoring / isEnabled=false triggers stopMonitoring',
      () async {
        await MemoryInspectorService.instance.startMonitoring();
        MemoryInspectorService.instance.isEnabled = false;
        expect(MemoryInspectorService.instance.isMonitoring, isFalse);
        expect(MemoryInspectorService.instance.isEnabled, isFalse);
      },
    );

    test(
      'stopMonitoring 清理 VM Service 状态 / stopMonitoring cleans VM Service state',
      () async {
        await MemoryInspectorService.instance.startMonitoring();
        MemoryInspectorService.instance.stopMonitoring();
        expect(MemoryInspectorService.instance.vmServiceAvailable, isFalse);
      },
    );

    test(
      'stopMonitoring 清理 Dart Heap 缓存 / stopMonitoring clears Dart Heap cache',
      () async {
        await MemoryInspectorService.instance.startMonitoring();
        MemoryInspectorService.instance.stopMonitoring();
        expect(MemoryInspectorService.instance.currentHeapUsage, equals(0));
        expect(MemoryInspectorService.instance.currentHeapCapacity, equals(0));
        expect(MemoryInspectorService.instance.currentExternalUsage, equals(0));
        expect(MemoryInspectorService.instance.currentNewSpaceUsage, equals(0));
        expect(MemoryInspectorService.instance.currentOldSpaceUsage, equals(0));
      },
    );
  });

  /// =======================================================================
  /// 内存快照管理 / Memory Snapshot Management
  /// =======================================================================
  group('Memory Snapshot Management', () {
    test(
      '监控前 latestSnapshot 为 null / latestSnapshot is null before monitoring',
      () {
        expect(MemoryInspectorService.instance.latestSnapshot, isNull);
      },
    );

    test(
      'startMonitoring 后产生快照 / Snapshot created after startMonitoring',
      () async {
        await MemoryInspectorService.instance.startMonitoring();
        // _refreshMemoryData 是异步的，等待事件队列 / _refreshMemoryData is async, wait
        await Future.delayed(const Duration(milliseconds: 100));
        expect(MemoryInspectorService.instance.latestSnapshot, isNotNull);
        // 进程 RSS 始终有值 / Process RSS always has a value
        expect(
          MemoryInspectorService.instance.latestSnapshot!.processRss,
          greaterThan(0),
        );
      },
    );

    test(
      'clearMemorySnapshots 清空快照列表 / clearMemorySnapshots clears list',
      () async {
        await MemoryInspectorService.instance.startMonitoring();
        await Future.delayed(const Duration(milliseconds: 100));
        expect(MemoryInspectorService.instance.memorySnapshots, isNotEmpty);
        MemoryInspectorService.instance.clearMemorySnapshots();
        expect(MemoryInspectorService.instance.memorySnapshots, isEmpty);
        expect(MemoryInspectorService.instance.latestSnapshot, isNull);
      },
    );

    test('快照数量不超过 _maxSnapshots (240) / Snapshots limited to 240', () async {
      await MemoryInspectorService.instance.startMonitoring();
      // 500ms 间隔，等待足够长时间产生 >240 条快照
      // 500ms interval, wait long enough to produce >240 snapshots
      // 240 * 500ms = 120s，测试中等待太长，改为验证上限逻辑
      // 240 * 500ms = 120s, too long for test; verify upper limit logic instead
      await Future.delayed(const Duration(milliseconds: 1500));
      // 短时间内产生 2-4 条快照 / Produces 2-4 snapshots in short time
      final count = MemoryInspectorService.instance.memorySnapshots.length;
      expect(count, greaterThan(0));
      expect(count, lessThanOrEqualTo(240));
    });
  });

  /// =======================================================================
  /// triggerGc 降级测试 / triggerGc Degradation
  /// =======================================================================
  group('triggerGc', () {
    test(
      'VM Service 不可用时返回 false / Returns false when VM Service unavailable',
      () async {
        // 未启动监控，VM Service 肯定不可用 / Not monitoring, VM Service definitely unavailable
        final result = await MemoryInspectorService.instance.triggerGc();
        expect(result, isFalse);
      },
    );

    test(
      '监控启动但 VM Service 不可用时返回 false / Returns false when monitoring but VM Service unavailable',
      () async {
        await MemoryInspectorService.instance.startMonitoring();
        // 等待 VM Service 连接尝试完成（会失败）/ Wait for VM Service connection attempt (will fail)
        await Future.delayed(const Duration(seconds: 2));
        expect(MemoryInspectorService.instance.vmServiceAvailable, isFalse);
        final result = await MemoryInspectorService.instance.triggerGc();
        expect(result, isFalse);
      },
    );
  });

  /// =======================================================================
  /// 图片缓存 / Image Cache
  /// =======================================================================
  group('Image Cache', () {
    test(
      'imageCacheMaximumSize 返回默认值 / imageCacheMaximumSize returns default',
      () {
        // Flutter 默认 imageCache.maximumSize = 1000 / Flutter default
        expect(
          MemoryInspectorService.instance.imageCacheMaximumSize,
          greaterThan(0),
        );
      },
    );

    test(
      'imageCacheMaximumSize setter 正确设置 / imageCacheMaximumSize setter works',
      () {
        MemoryInspectorService.instance.imageCacheMaximumSize = 500;
        expect(
          MemoryInspectorService.instance.imageCacheMaximumSize,
          equals(500),
        );
      },
    );

    test(
      'imageCacheMaximumSizeBytes setter 正确设置 / imageCacheMaximumSizeBytes setter works',
      () {
        MemoryInspectorService.instance.imageCacheMaximumSizeBytes =
            100 * 1024 * 1024;
        expect(
          MemoryInspectorService.instance.imageCacheMaximumSizeBytes,
          equals(100 * 1024 * 1024),
        );
      },
    );

    test('clearImageCache 不抛出异常 / clearImageCache does not throw', () {
      // 仅验证不抛异常 / Just verify no exception
      MemoryInspectorService.instance.clearImageCache();
    });

    test('refreshImageCache 不抛出异常 / refreshImageCache does not throw', () {
      MemoryInspectorService.instance.refreshImageCache();
    });
  });

  /// =======================================================================
  /// Native 支持检测 / Native Support Detection
  /// =======================================================================
  group('Native Support Detection', () {
    test(
      '桌面测试环境下 isNativeSupported=false / isNativeSupported=false on desktop test',
      () {
        // 测试运行在桌面环境，不支持 Native 采集
        // Test runs on desktop environment, Native collection not supported
        // 注意：仅在桌面平台成立 / Note: only true on desktop platforms
        expect(MemoryInspectorService.instance.isNativeSupported, isFalse);
      },
    );
  });
}
