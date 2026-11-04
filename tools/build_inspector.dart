// Zero Inspector Kit — build helper (run from the HOST APP, not the plugin).
//
// Reads the `zero_inspector_kit.inspector_modes` key from the host app's own
// `pubspec.yaml` and forwards every argument to `flutter`, injecting the
// matching `--dart-define=INSPECTOR_MODES=...` so the inspector can be bundled
// into release (AOT) builds when configured.
//
// This script lives in the plugin repo's `tools/`. In a real host app, copy it
// into your app's `tool/` (or just pass the flag directly):
//   flutter build apk --release --dart-define=INSPECTOR_MODES=all
//
// Usage (from your app's directory):
//   dart tools/build_inspector.dart build apk --release
//   dart tools/build_inspector.dart run --release

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  const defaultMode = 'debug';
  var mode = defaultMode;

  try {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'inspector_modes:\s*([A-Za-z]+)').firstMatch(pubspec);
    if (match != null) {
      final value = match.group(1)!;
      // Only forward values we recognize; keep `debug` as the safe default.
      if (value == 'all' || value == 'release' || value == 'debug') {
        mode = value;
      }
    }
  } catch (_) {
    // Ignore — fall back to the default mode.
  }

  final result = Process.runSync(
    'flutter',
    [...args, '--dart-define=INSPECTOR_MODES=$mode'],
    runInShell: true,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );

  stdout.write(result.stdout);
  stderr.write(result.stderr);
  exit(result.exitCode);
}
