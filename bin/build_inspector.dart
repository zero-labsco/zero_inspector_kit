// Zero Inspector Kit — build helper (published as a `bin/` executable).
//
// Reads the `zero_inspector_kit.inspector_modes` key from the host app's own
// `pubspec.yaml` and forwards every argument to `flutter`, injecting the
// matching `--dart-define=INSPECTOR_MODES=...` so the inspector can be bundled
// into release (AOT) builds when configured.
//
// This executable ships with the package, so from the host app's directory you
// can simply run it (no need to copy anything):
//   dart run zero_inspector_kit:build_inspector build apk --release
//   dart run zero_inspector_kit:build_inspector run --release
//
// Or skip the helper and pass the flag directly:
//   flutter build apk --release --dart-define=INSPECTOR_MODES=all

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
      if (value == 'all' || value == 'debug') {
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
