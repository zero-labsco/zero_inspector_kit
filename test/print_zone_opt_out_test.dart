import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// `enablePrintZoneCapture: false` 开关的相关测试。
/// Tests for the `enablePrintZoneCapture: false` opt-out switch.
///
/// 注意 / Note:
/// 本测试**不**调用 `runAppWithInspector`。它内部会调用 `runApp`，而在
/// `testWidgets` 里调用 `runApp` 会触发 Flutter 的 "foundation debug variable"
/// 不变量断言直接失败；并且 `TestWidgetsFlutterBinding` 在测试启动前就已经初始化了
/// binding，所以即便调用也会走"降级不套 Zone"分支，Zone 抓取路径在单测里根本无法到达。
/// 因此这里改为直接验证 opt-out 所依赖的契约：检查器启动但**没有**拦截 print 的全局
/// Zone 时，裸 `print()` 不进日志、而 `debugPrint()` 进日志。
/// This test does **not** call `runAppWithInspector` — that calls `runApp`, which
/// trips Flutter's "foundation debug variable" invariant inside `testWidgets`, and
/// the pre-initialized binding means the Zone-capture path is never reached in a
/// unit test anyway. Instead it validates the contract the opt-out relies on:
/// with the inspector active but *no* print-intercepting global Zone, a raw
/// `print()` is not captured while `debugPrint()` is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    InspectorLogInterceptor.instance.stop();
    InspectorService.instance.clearLogs();
  });

  tearDown(() {
    InspectorLogInterceptor.instance.stop();
    InspectorService.instance.clearLogs();
  });

  test(
    'init accepts enablePrintZoneCapture (both values) without throwing',
    () {
      expect(
        () => ZeroInspectorKit.init(enablePrintZoneCapture: true),
        returnsNormally,
      );
      expect(
        () => ZeroInspectorKit.init(enablePrintZoneCapture: false),
        returnsNormally,
      );
    },
  );

  test(
    'without a global Zone, raw print() is not captured but debugPrint() is',
    () {
      // 模拟 opt-out 场景：检查器已启动，但不存在拦截 print 的全局 Zone。
      // Simulate the opt-out scenario: the inspector is active, but no
      // print-intercepting global Zone exists.
      InspectorLogInterceptor.instance.start();

      const captured = '__DEBUGPRINT_CAPTURED__';
      const skipped = '__RAW_PRINT_SKIPPED__';

      debugPrint(captured);
      // ignore: avoid_print
      print(skipped);

      final messages = InspectorService.instance.logEntries
          .map((e) => e.message)
          .toList();
      // debugPrint 走覆写，被捕获；裸 print() 没有 Zone 去拦截，不进日志。
      // debugPrint goes through the override and is captured; a raw print() has
      // no Zone intercepting it and must not enter the log stream.
      expect(messages.any((m) => m.contains(captured)), isTrue);
      expect(messages.any((m) => m.contains(skipped)), isFalse);
    },
  );
}
