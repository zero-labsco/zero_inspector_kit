import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// `--dart-define=INSPECTOR_ENABLED=false` 的回归测试。
/// Regression tests for the explicit opt-out flag.
///
/// 运行方式 / Run with:
/// ```
/// flutter test test/explicit_disable_test.dart \
///   --dart-define=INSPECTOR_ENABLED=false
/// ```
/// 普通 `flutter test` 不带该 flag（这些用例会自行 skip），否则恒为 debug
/// 且无法覆盖编译期常量分支。CI 的 "Test explicit-disable flag" 步骤负责跑它。
/// A plain `flutter test` has no such flag (these cases skip themselves);
/// CI's "Test explicit-disable flag" step runs them for real.
void main() {
  final flagEnabled = InspectorEnvironment.isInspectorExplicitlyDisabled;
  final skip = flagEnabled
      ? false
      : 'requires --dart-define=INSPECTOR_ENABLED=false';

  test('INSPECTOR_ENABLED=false disables collection at every layer', () {
    expect(InspectorEnvironment.isInspectorExplicitlyDisabled, isTrue);
    expect(InspectorEnvironment.isCollectionDisabled, isTrue);

    // wrapApp 必须原样返回宿主 app：不注入 RouteObserver、不挂 Overlay。
    // wrapApp must return the host app untouched (no route observer / overlay).
    final app = const SizedBox.shrink();
    expect(ZeroInspectorKit.wrapApp(app), same(app));
  }, skip: skip);

  test('service singletons refuse writes while explicitly disabled', () {
    final before = InspectorService.instance.logEntries.length;
    InspectorService.instance.addLogEntry(
      LogEntry(
        id: 'disabled-flag-1',
        level: LogLevel.info,
        message: 'must not be recorded',
        timestamp: DateTime.now(),
      ),
    );
    expect(InspectorService.instance.logEntries.length, before);
  }, skip: skip);
}
