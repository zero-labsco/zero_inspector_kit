import '../services/memory_inspector_service.dart';

/// 内存泄漏追踪简化 API / Simplified memory leak tracking API
///
/// 提供比 `MemoryInspectorService.instance.trackObject()` 更短的调用方式，
/// 降低业务代码的侵入感。
/// Provides shorter call patterns than `MemoryInspectorService.instance.trackObject()`,
/// reducing the intrusion feeling in business code.
///
/// 用法示例 / Usage examples:
/// ```dart
/// // 顶层函数风格 / Top-level function style
/// trackMemoryLeak(myBloc, tag: 'HomePage_myBloc');
///
/// // 扩展方法风格 / Extension method style
/// myBloc.trackMemoryLeak(tag: 'HomePage_myBloc');
/// ```

/// 注册对象进行泄漏追踪 / Register an object for leak tracking
///
/// [object] 要追踪的对象 / Object to track
/// [tag] 可选标签，用于 UI 识别 / Optional tag for UI identification
/// [expectedReleaseAfter] 预期释放时间，默认 30 秒 / Expected release time, default 30 seconds
/// 返回追踪 ID（对象 identityHashCode）/ Returns tracking ID (object identityHashCode)
int trackMemoryLeak(
  Object object, {
  String? tag,
  Duration? expectedReleaseAfter,
}) {
  return MemoryInspectorService.instance.trackObject(
    object,
    tag: tag,
    expectedReleaseAfter: expectedReleaseAfter,
  );
}

/// 取消对象的泄漏追踪 / Cancel leak tracking for an object
///
/// [objectOrId] 可以是对象本身或 trackMemoryLeak 返回的 ID / Can be the object itself or the ID returned by trackMemoryLeak
void untrackMemoryLeak(Object objectOrId) {
  MemoryInspectorService.instance.untrackObject(objectOrId);
}

/// Object 扩展：提供链式/更短的泄漏追踪调用 / Object extension: provide chained/shorter leak tracking calls
extension MemoryLeakTrackingExtension on Object {
  /// 注册当前对象进行泄漏追踪 / Register current object for leak tracking
  ///
  /// [tag] 可选标签，用于 UI 识别 / Optional tag for UI identification
  /// [expectedReleaseAfter] 预期释放时间，默认 30 秒 / Expected release time, default 30 seconds
  /// 返回追踪 ID（对象 identityHashCode）/ Returns tracking ID (object identityHashCode)
  int trackMemoryLeak({String? tag, Duration? expectedReleaseAfter}) {
    return MemoryInspectorService.instance.trackObject(
      this,
      tag: tag,
      expectedReleaseAfter: expectedReleaseAfter,
    );
  }

  /// 取消当前对象的泄漏追踪 / Cancel leak tracking for current object
  void untrackMemoryLeak() {
    MemoryInspectorService.instance.untrackObject(this);
  }
}
