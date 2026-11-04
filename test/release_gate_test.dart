import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// release gate 编译期语义的回归测试。
/// Regression tests for the compile-time release gate.
///
/// `flutter test` 恒以 debug 运行（`kReleaseMode == false`），因此无法在此覆盖
/// 「默认 release 完全不采集」的分支；那条分支靠 AOT 常量折叠保证，需要在真机
/// release 包 / `flutter build apk --analyze-size` 上验证。这里锁定常量表达式，
/// 并守住 debug/profile 下入口不被误关掉。
/// `flutter test` always runs in debug (`kReleaseMode == false`), so the
/// "default release skips all collection" branch cannot be exercised here; it
/// is guaranteed by AOT constant folding and needs a real release build to
/// verify. These tests lock the constant expression and keep the entry points
/// active in debug/profile.
void main() {
  test('release gate is a compile-time constant, off in debug builds', () {
    expect(InspectorEnvironment.inspectorModes, 'debug');
    expect(InspectorEnvironment.isInspectorAllowedInRelease, isFalse);
    expect(
      InspectorEnvironment.isInspectorDisabledInCurrentBuild,
      kReleaseMode && InspectorEnvironment.inspectorModes != 'all',
    );
    expect(InspectorEnvironment.isInspectorDisabledInCurrentBuild, isFalse);
  });

  test('wrapApp still wraps the host app outside default release builds', () {
    final app = const SizedBox.shrink();
    expect(ZeroInspectorKit.wrapApp(app), isNot(same(app)));
  });
}
