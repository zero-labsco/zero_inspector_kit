import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../models/error_record.dart';
import 'persistence_service.dart';

/// 异常聚合服务 / Error aggregation service
///
/// 接管 [FlutterError.onError]（保留默认红色报错行为），把每次异常按
/// 类型 + 堆栈签名去重聚合，记录出现次数、首末次时间与一条完整堆栈样本，
/// 形成独立的 Errors Tab，供开发者快速定位"同一处崩溃反复出现"的问题。
/// Hooks [FlutterError.onError] (keeping the default red error behavior),
/// dedups each exception by type + stack signature, and records count,
/// first/last seen time and a full stack sample — powering a dedicated
/// Errors Tab to surface "the same crash happening repeatedly".
///
/// 同时接管 [PlatformDispatcher.onError]：它能捕获 [FlutterError.onError]
/// 漏掉的、发生在框架错误边界之外或平台通道回包中的异常（例如绘制/布局阶段
/// 抛错后再次被框架捕获前的原始错误），避免这类崩溃完全不被聚合。
/// Also hooks [PlatformDispatcher.onError], which catches errors that
/// [FlutterError.onError] misses — those thrown outside the framework error
/// boundary or from platform-channel replies — so they are aggregated too.
class ErrorService extends ChangeNotifier {
  ErrorService._();

  /// 单例实例 / Singleton instance
  static final ErrorService instance = ErrorService._();

  /// 聚合记录上限（环形缓冲）/ Aggregated record cap (ring buffer)
  static const int _maxErrors = 200;

  /// 堆栈样本最大字符数（超出截断，避免单条过大）/ Max stack sample chars
  static const int _maxSampleChars = 8000;

  /// 聚合后的异常记录（最新在前）/ Aggregated error records (newest first)
  final ListQueue<ErrorRecord> _errors = ListQueue();

  /// 原生的 FlutterError 处理回调，用于保留默认行为 / Original handler
  FlutterExceptionHandler? _previousOnError;

  /// 原生的 PlatformDispatcher.onError 回调 / Original platform dispatcher handler
  /// 类型为 `bool Function(Object error, StackTrace stack)?`
  /// (the type of [PlatformDispatcher.onError]).
  bool Function(Object error, StackTrace stack)? _previousPlatformOnError;

  /// 是否已接管 FlutterError.onError / Whether hooked
  bool _installed = false;

  /// 是否启用抓取（用户可在面板开关）/ Whether capture is enabled
  bool _enabled = true;

  /// 获取是否启用 / Get whether enabled
  bool get isEnabled => _enabled;

  /// 聚合记录只读视图 / Read-only aggregated records view
  UnmodifiableListView<ErrorRecord> get errors => UnmodifiableListView(_errors);

  /// 聚合记录数量 / Aggregated record count
  int get errorCount => _errors.length;

  /// 接管 FlutterError.onError 与 PlatformDispatcher.onError（均保留默认行为）
  /// Hook both [FlutterError.onError] and [PlatformDispatcher.onError] (default
  /// behavior preserved for both).
  void install() {
    if (_installed) return;
    _installed = true;
    _previousOnError = FlutterError.onError;
    FlutterError.onError = _onFlutterError;
    try {
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      _previousPlatformOnError = dispatcher.onError;
      dispatcher.onError = _onPlatformError;
    } catch (_) {
      // 绑定未就绪时跳过平台通道接管 / Skip if binding isn't ready
    }
  }

  /// 还原 FlutterError.onError 与 PlatformDispatcher.onError
  /// Restore both [FlutterError.onError] and [PlatformDispatcher.onError]
  void uninstall() {
    if (!_installed) return;
    FlutterError.onError = _previousOnError;
    _previousOnError = null;
    try {
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      dispatcher.onError = _previousPlatformOnError;
    } catch (_) {
      // 绑定未就绪时忽略 / Ignore if binding isn't ready
    }
    _previousPlatformOnError = null;
    _installed = false;
  }

  /// 设置是否启用抓取 / Toggle capture
  set isEnabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  void _onFlutterError(FlutterErrorDetails details) {
    // 保留默认行为（控制台红色报错、错误界面）/ Keep default behavior
    _previousOnError?.call(details);
    if (!_enabled) return;
    _record(
      details.exception,
      details.stack?.toString() ?? '',
      details.library ?? '',
    );
  }

  /// PlatformDispatcher.onError 回调：返回 false 表示"未处理"，让框架继续走
  /// 默认上层兜底逻辑；同时聚合进 Errors Tab。
  /// PlatformDispatcher.onError callback: returning false leaves the error
  /// unhandled so the framework keeps its default top-level fallback, while we
  /// still aggregate it into the Errors Tab.
  bool _onPlatformError(Object error, StackTrace stack) {
    _previousPlatformOnError?.call(error, stack);
    if (_enabled) {
      _record(error, stack.toString(), 'platform-dispatcher');
    }
    return false;
  }

  /// 手动上报一个异常（gRPC/自定义协议或 Zone 捕获）/ Manual report
  void report(Object exception, StackTrace? stack, [String context = '']) {
    if (!_enabled) return;
    _record(exception, stack?.toString() ?? '', context);
  }

  void _record(Object exception, String stack, String context) {
    final type = exception.runtimeType.toString();
    final message = exception.toString();
    final effectiveStack = stack.isNotEmpty ? stack : message;
    final sig = ErrorRecord.signatureOf(type, effectiveStack);
    final now = DateTime.now();

    // ListQueue 不支持索引访问，用线性查找定位重复项（异常本身不频繁）。
    // ListQueue has no index access; linear lookup is fine (errors are rare).
    ErrorRecord? existing;
    for (final e in _errors) {
      if (e.id == sig) {
        existing = e;
        break;
      }
    }
    if (existing != null) {
      _errors.remove(existing);
      _errors.addFirst(
        existing.copyWith(
          count: existing.count + 1,
          lastSeen: now,
          sampleStack: stack.isNotEmpty ? stack : existing.sampleStack,
        ),
      );
    } else {
      final truncated = stack.length > _maxSampleChars
          ? '${stack.substring(0, _maxSampleChars)}\n…(truncated)'
          : stack;
      _errors.addFirst(
        ErrorRecord(
          id: sig,
          type: type,
          message: message,
          stackSignature: sig,
          count: 1,
          firstSeen: now,
          lastSeen: now,
          sampleStack: stack.isNotEmpty ? truncated : null,
        ),
      );
      while (_errors.length > _maxErrors) {
        _errors.removeLast();
      }
    }
    // 异步落盘（磁盘环形缓冲，崩溃后可读回）/ Async persist (disk ring buffer)
    PersistenceService.instance.enqueueError(_errors.first);
    notifyListeners();
  }

  /// 恢复持久化的聚合异常（跨重启不丢）。
  /// Restore persisted aggregated errors (survives restarts).
  ///
  /// 已存在相同去重 id 的记录会被跳过，避免重复计数。
  /// Records whose dedup id already exists are skipped to avoid double counting.
  void restore(Iterable<ErrorRecord> records) {
    for (final r in records) {
      final exists = _errors.any((e) => e.id == r.id);
      if (exists) continue;
      _errors.addLast(r);
    }
    while (_errors.length > _maxErrors) {
      _errors.removeLast();
    }
    notifyListeners();
  }

  /// 清空所有聚合记录 / Clear all aggregated records
  void clear() {
    _errors.clear();
    notifyListeners();
  }
}
