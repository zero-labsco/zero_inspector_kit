/// 检查器版本号 / Inspector version
///
/// 此前 HAR 导出把 `creator.version` 硬编码成 `'1.2'`，与 `pubspec.yaml`
/// 完全脱钩，发版时必然忘记更新。这里收敛为单一常量，并由
/// `test/version_consistency_test.dart` 断言它与 `pubspec.yaml` 一致。
/// HAR export used to hardcode `creator.version` as `'1.2'`, fully decoupled
/// from `pubspec.yaml` and therefore always stale at release time. It is now a
/// single constant asserted against `pubspec.yaml` by
/// `test/version_consistency_test.dart`.
class InspectorVersion {
  InspectorVersion._();

  /// 当前版本号，必须与 `pubspec.yaml` 的 `version` 字段一致
  /// Current version; must match the `version` field in `pubspec.yaml`
  static const String value = '1.11.0';
}
