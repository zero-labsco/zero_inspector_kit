// ignore_for_file: avoid_print

import 'dart:io';

/// 发版前版本一致性自检 / Pre-release version consistency self-check
///
/// 用法 / Usage:
/// ```bash
/// dart run tool/check_release.dart
/// ```
///
/// 发版最容易出错的地方不是代码，而是"版本号忘了改全一处":
/// `pubspec.yaml`、`ios/zero_inspector_kit.podspec`、
/// `lib/src/utils/inspector_version.dart`、两个 README 的安装片段与升级提示、
/// 以及 `CHANGELOG.md` 顶部。漏掉任何一处都会让 pub.dev 上的包与文档
/// 相互矛盾（HAR 导出里的 creator.version 就曾长期停在旧版本）。
/// The most common release mistake is not code but a version string left
/// stale in one place: `pubspec.yaml`, `ios/zero_inspector_kit.podspec`,
/// `lib/src/utils/inspector_version.dart`, the install snippets and upgrade
/// callouts in both READMEs, and the top of `CHANGELOG.md`. Missing any of
/// them leaves the published package contradicting its own docs (the HAR
/// `creator.version` used to sit on an old release for a long time).
///
/// 本脚本以 `pubspec.yaml` 的 `version` 为唯一真值，逐处核对，
/// 任何一处不一致即以非零退出码失败（供 CI 拦截）。
/// `pubspec.yaml`'s `version` is the single source of truth; every other
/// place is checked against it and any mismatch fails with a non-zero exit
/// code so CI can block the release.
void main() {
  final version = _readPubspecVersion();
  if (version == null) {
    _fail('pubspec.yaml: cannot parse the top-level `version:` field.');
    exit(1);
  }
  print('Release version (from pubspec.yaml): $version');

  final problems = <String>[
    ..._checkPodspec(version),
    ..._checkInspectorVersion(version),
    ..._checkReadme('README.md', version),
    ..._checkReadme('README_zh.md', version),
    ..._checkChangelog(version),
  ];

  if (problems.isNotEmpty) {
    print('');
    print('${problems.length} version problem(s) found:');
    for (final p in problems) {
      print('  ✗ $p');
    }
    print('');
    print(
      'Bump every occurrence to $version (see AGENTS.md release checklist).',
    );
    exit(1);
  }
  print('✅ All version references are consistent with $version.');
}

/// 版本串正则（X.Y.Z）/ Version string pattern (X.Y.Z)
final RegExp _anyVersion = RegExp(r'\d+\.\d+\.\d+');

/// 读取 pubspec.yaml 顶层的 version / Read the top-level version from pubspec.yaml
String? _readPubspecVersion() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) return null;
  // 只取文件头部（避免命中 dependency 里的 version 约束）。
  // Only scan the header so dependency constraints are not mistaken for it.
  final head = file.readAsStringSync().split('\n').take(40).join('\n');
  final match = RegExp(
    r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$',
    multiLine: true,
  ).firstMatch(head);
  return match?.group(1);
}

/// 读取文件内容，缺失时报错 / Read a file's content, report when missing
String? _read(String path, List<String> problems) {
  final file = File(path);
  if (!file.existsSync()) {
    problems.add('$path: file not found.');
    return null;
  }
  return file.readAsStringSync();
}

/// 校验 iOS podspec 版本 / Check the iOS podspec version
List<String> _checkPodspec(String version) {
  const path = 'ios/zero_inspector_kit.podspec';
  final problems = <String>[];
  final content = _read(path, problems);
  if (content == null) return problems;
  final match = RegExp(r"s\.version\s*=\s*'([^']+)'").firstMatch(content);
  if (match == null) {
    problems.add('$path: no `s.version` found.');
  } else if (match.group(1) != version) {
    problems.add('$path: s.version is ${match.group(1)}, expected $version.');
  }
  return problems;
}

/// 校验 lib/src/utils/inspector_version.dart / Check inspector_version.dart
List<String> _checkInspectorVersion(String version) {
  const path = 'lib/src/utils/inspector_version.dart';
  final problems = <String>[];
  final content = _read(path, problems);
  if (content == null) return problems;
  final match = RegExp(
    r"static const String value = '([^']+)'",
  ).firstMatch(content);
  if (match == null) {
    problems.add('$path: no `InspectorVersion.value` found.');
  } else if (match.group(1) != version) {
    problems.add(
      '$path: InspectorVersion.value is ${match.group(1)}, expected $version.',
    );
  }
  return problems;
}

/// 校验 README 里的安装片段与升级提示 / Check README install snippets & callouts
///
/// 只核对"版本敏感行"（含 `zero_inspector_kit:` 依赖声明或 `release/v` 归档
/// 分支引用的行），历史性叙述（如 "since v1.9.0"）不参与校验，避免误报。
/// Only "version-sensitive" lines are checked (those declaring the
/// `zero_inspector_kit:` dependency or referencing a `release/v` archive
/// branch); historical prose such as "since v1.9.0" is intentionally ignored.
List<String> _checkReadme(String path, String version) {
  final problems = <String>[];
  final content = _read(path, problems);
  if (content == null) return problems;

  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    final isSensitive =
        line.contains('zero_inspector_kit:') ||
        line.contains('release/v') ||
        line.contains('^$version') ||
        line.contains(RegExp(r'\^\d+\.\d+\.\d+'));
    if (!isSensitive) continue;
    for (final match in _anyVersion.allMatches(line)) {
      final found = match.group(0)!;
      if (found != version) {
        problems.add('$path:${i + 1}: found $found, expected $version.');
      }
    }
  }

  // 硬性要求：两个安装片段必须存在，否则说明文档结构变了/被误删。
  // Hard requirement: both install snippets must exist, otherwise the doc
  // structure changed (or the snippet was deleted by accident).
  if (!content.contains('zero_inspector_kit: ^$version')) {
    problems.add('$path: missing the `zero_inspector_kit: ^$version` snippet.');
  }
  if (!content.contains('release/v$version')) {
    problems.add('$path: missing the `ref: release/v$version` git snippet.');
  }
  return problems;
}

/// 校验 CHANGELOG 顶部版本 / Check the CHANGELOG top version
List<String> _checkChangelog(String version) {
  const path = 'CHANGELOG.md';
  final problems = <String>[];
  final content = _read(path, problems);
  if (content == null) return problems;
  final match = RegExp(
    r'^##\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$',
    multiLine: true,
  ).firstMatch(content);
  if (match == null) {
    problems.add('$path: no `## X.Y.Z` section found at the top.');
  } else if (match.group(1) != version) {
    problems.add(
      '$path: top section is ${match.group(1)}, expected $version '
      '(add a `## $version` entry before releasing).',
    );
  }
  return problems;
}

/// 打印一条致命错误 / Print a fatal error
void _fail(String message) => print('✗ $message');
