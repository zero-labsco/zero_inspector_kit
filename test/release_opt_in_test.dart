import 'package:flutter_test/flutter_test.dart';
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

/// `--dart-define=INSPECTOR_MODES=all`（QA release 包）的回归测试。
/// Regression test for the QA release opt-in flag.
///
/// 运行方式 / Run with:
/// ```
/// flutter test test/release_opt_in_test.dart \
///   --dart-define=INSPECTOR_MODES=all
/// ```
/// `flutter test` 恒以 debug 运行（kReleaseMode == false），所以这里只能锁定
/// flag 解析与入口未被误关；真正的 AOT 摇树需要在真机 release 包上验证。
/// `flutter test` always runs in debug, so this only locks down flag parsing
/// and that the entry points stay active; real AOT tree-shaking needs a
/// device release build.
void main() {
  final optIn = InspectorEnvironment.inspectorModes == 'all';
  final skip = optIn ? false : 'requires --dart-define=INSPECTOR_MODES=all';

  test(
    'INSPECTOR_MODES=all re-enables the inspector for QA release builds',
    () {
      expect(InspectorEnvironment.inspectorModes, 'all');
      expect(InspectorEnvironment.isInspectorAllowedInRelease, isTrue);
      expect(InspectorEnvironment.isInspectorDisabledInCurrentBuild, isFalse);
      expect(InspectorEnvironment.isCollectionDisabled, isFalse);
    },
    skip: skip,
  );
}
