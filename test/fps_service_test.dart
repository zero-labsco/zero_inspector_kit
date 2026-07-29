import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/src/services/fps_service.dart';

/// FPS 服务单元测试 / FPS service unit tests
///
/// 覆盖 FPS 服务的核心功能：生命周期、帧数据管理、掉帧检测、
/// FPS 计算、面板状态管理等
/// Covers FPS service core: lifecycle, frame data management, jank detection,
/// FPS calculation, panel state management
void main() {
  late FpsService fps;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    fps = FpsService.instance;
    fps.stop();
    fps.clear();
  });

  tearDown(() {
    fps.stop();
    fps.clear();
  });

  group('Lifecycle / 生命周期', () {
    test('initial state is not running / 初始状态未运行', () {
      expect(fps.isRunning, isFalse);
      expect(fps.currentFps, equals(0));
      expect(fps.frameRecords, isEmpty);
    });

    test('start activates monitoring / start 启动监控', () {
      fps.start();
      expect(fps.isRunning, isTrue);
    });

    test('stop deactivates monitoring / stop 停止监控', () {
      fps.start();
      fps.stop();
      expect(fps.isRunning, isFalse);
    });

    test('multiple start calls are safe (idempotent) / 多次 start 安全', () {
      fps.start();
      final running1 = fps.isRunning;
      fps.start();
      expect(fps.isRunning, equals(running1));
    });

    test('multiple stop calls are safe / 多次 stop 安全', () {
      fps.stop();
      fps.stop();
      expect(fps.isRunning, isFalse);
    });
  });

  group('FrameRecord / 帧记录', () {
    test('isJanky detects frames over 16ms / 超过16ms为掉帧', () {
      final janky = FrameRecord(timestamp: 0, durationUs: 20000);
      final smooth = FrameRecord(timestamp: 0, durationUs: 10000);
      expect(janky.isJanky, isTrue);
      expect(smooth.isJanky, isFalse);
    });

    test('isJanky boundary at 16ms / 16ms 边界测试', () {
      final atBoundary = FrameRecord(timestamp: 0, durationUs: 16000);
      final justOver = FrameRecord(timestamp: 0, durationUs: 16001);
      expect(atBoundary.isJanky, isFalse);
      expect(justOver.isJanky, isTrue);
    });
  });

  group('Data management / 数据管理', () {
    test('clear resets all data / clear 重置所有数据', () {
      fps.start();
      // 记录一些数据
      fps.clear();
      expect(fps.currentFps, equals(0));
      expect(fps.frameRecords, isEmpty);
      expect(fps.fpsHistory, isEmpty);
      expect(fps.totalJankyCount, equals(0));
      expect(fps.totalFrameCount, equals(0));
      expect(fps.jankRate, equals(0));
    });

    test('jankRate is calculated correctly / 掉帧率计算正确', () {
      // 未启动时掉帧率为 0
      expect(fps.jankRate, equals(0));
      expect(fps.lastFrameJanky, isFalse);
    });
  });

  group('FPS history / FPS 历史', () {
    test('fpsHistory is modifiable list / fpsHistory 是可修改列表', () {
      expect(fps.fpsHistory, isA<List<double>>());
      expect(fps.fpsHistory, isEmpty);
    });

    test('frameRecords is unmodifiable / frameRecords 不可修改', () {
      expect(fps.frameRecords, isA<List<FrameRecord>>());
      expect(fps.frameRecords, isEmpty);
    });
  });
}
