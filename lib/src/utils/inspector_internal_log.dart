import 'dart:developer' as developer;

/// Severity levels for internal diagnostic logging.
enum InternalLogLevel {
  /// Verbose diagnostic detail. Only visible at fine-grained log levels.
  debug,

  /// Recoverable issue worth surfacing to developers (e.g. a query failed but
  /// the app keeps running). This is the level most internal warnings use.
  warning,

  /// Hard failure that prevents a feature from working (e.g. cannot open the
  /// inspector database).
  error,
}

/// A single internal diagnostic record kept for in-inspector debugging.
class InternalLogEntry {
  const InternalLogEntry({
    required this.time,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final DateTime time;
  final InternalLogLevel level;
  final String tag;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;

  @override
  String toString() {
    final buf = StringBuffer()
      ..write(time.toIso8601String())
      ..write(' [')
      ..write(level.name)
      ..write('] ')
      ..write(tag)
      ..write(': ')
      ..write(message);
    if (error != null) buf.write(' ($error)');
    return buf.toString();
  }
}

/// Ring-buffer of internal diagnostic logs emitted by Zero Inspector Kit.
///
/// These logs never reach end-user-facing output by themselves. They are kept
/// so the in-app console can show *why* something failed (e.g. a database query
/// that was previously swallowed by a silent `catch (_)`), and are also sent to
/// `dart:developer.log` in debug builds for console inspection.
class InspectorInternalLog {
  InspectorInternalLog._();

  static const int _maxEntries = 200;

  static final List<InternalLogEntry> _entries = [];

  /// Read-only view of the most recent diagnostic entries (oldest first).
  static List<InternalLogEntry> get entries =>
      List.unmodifiable(_entries);

  /// Whether any [InternalLogLevel.error] entry has been recorded.
  static bool get hasErrors =>
      _entries.any((e) => e.level == InternalLogLevel.error);

  /// Emit a diagnostic log entry.
  ///
  /// In debug mode the entry is also forwarded to `dart:developer.log` so it
  /// shows up in the IDE console / `flutter logs`. In release builds this is a
  /// no-op for the console but the ring buffer is still retained (tree-shaken
  /// caller sites aside) for the in-inspector view.
  static void log(
    String tag,
    String message, {
    InternalLogLevel level = InternalLogLevel.debug,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _entries.add(
      InternalLogEntry(
        time: DateTime.now(),
        level: level,
        tag: tag,
        message: message,
        error: error,
        stackTrace: stackTrace,
      ),
    );
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }

    if (level == InternalLogLevel.debug) return;
    developer.log(
      message,
      name: 'ZeroInspectorKit.$tag',
      error: error,
      stackTrace: stackTrace,
      level: level == InternalLogLevel.error ? 1000 : 900,
    );
  }

  /// Convenience helpers.
  static void debug(String tag, String message) =>
      log(tag, message, level: InternalLogLevel.debug);
  static void warning(String tag, String message,
          {Object? error, StackTrace? stackTrace}) =>
      log(tag, message,
          level: InternalLogLevel.warning, error: error, stackTrace: stackTrace);
  static void error(String tag, String message,
          {Object? error, StackTrace? stackTrace}) =>
      log(tag, message,
          level: InternalLogLevel.error, error: error, stackTrace: stackTrace);

  /// Clear the buffer (primarily for tests).
  static void clear() => _entries.clear();
}
