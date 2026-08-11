import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
} from '@ohos/flutter_ohos';
import fileIo from '@ohos.file.fs';
import hilog from '@ohos.hilog';
import hiAppEvent from '@ohos.hiviewdfx.hiAppEvent';

/// ZeroInspectorKit OpenHarmony (HarmonyOS) 原生插件 / ZeroInspectorKit OpenHarmony (HarmonyOS) native plugin
///
/// 通过 MethodChannel `zero_inspector_kit` 与 Dart 侧通信，契约与安卓（Kotlin）
/// 和 iOS（Swift）保持一致。当前实现对标两端暴露的方法：
/// Communicates with the Dart side over MethodChannel `zero_inspector_kit`, keeping
/// the same contract as the Android (Kotlin) and iOS (Swift) implementations. The
/// methods exposed here mirror those two platforms:
///
/// - `getPlatformVersion`:         返回系统版本 / Returns system version
/// - `getNativeLogs`:              返回原生级应用事件（崩溃/卡死），通过 hiAppEvent 真实订阅
///                                Returns native-level app events (crash/freeze), real subscription via hiAppEvent
/// - `startNativeLogListener`:     开启 hiAppEvent 崩溃/卡死订阅（真实，可拿到应用级异常事件）
///                                Start hiAppEvent crash/freeze subscription (real, app-level exception events)
/// - `stopNativeLogListener`:      停止 hiAppEvent 订阅 / Stop hiAppEvent subscription
/// - `getProcessMemoryInfo`:       返回进程级内存信息（真实解析 /proc/self/status 的 VmRSS）
///                                Returns process-level memory info (real parse of /proc/self/status VmRSS)
///
/// 核心检查器能力（网络拦截、日志、数据库、VM Service 内存/FPS）为纯 Dart 跨平台共用，
/// 原生侧仅承载需要在系统层落地的探针。
/// The core inspector capabilities (network interception, logging, database, VM
/// Service memory/FPS) are pure Dart and shared across platforms; the native side
/// only hosts system-level probes.
export default class ZeroInspectorKitPlugin implements FlutterPlugin, MethodCallHandler {
  private static readonly DOMAIN: number = 0xD0033200;
  private static readonly TAG: string = 'ZeroInspectorKit';
  private channel: MethodChannel | null = null;
  /// 原生日志桥接监听是否已开启 / Whether the native log bridge listener is active
  private nativeLogListenerActive: boolean = false;
  /// 通过 hiAppEvent 真实订阅到的应用级事件缓存（崩溃/卡死），每条为事件 JSON 字符串
  /// Cache of real app-level events (crash/freeze) subscribed via hiAppEvent, each entry a JSON string
  private appEvents: string[] = [];
  /// hiAppEvent 订阅 watcher 名称，用于去重与取消订阅 / Watcher name used to dedupe & unsubscribe
  private static readonly WATCHER_NAME: string = "ZeroInspectorKitWatcher";
  /// 保存 watcher 引用，removeWatcher 需要传回 Watcher 对象（非仅 name）
  /// Keep the watcher reference; removeWatcher requires the Watcher object, not just its name
  private watcher: hiAppEvent.Watcher | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "ZeroInspectorKitPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "zero_inspector_kit");
    this.channel.setMethodCallHandler(this)
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case "getPlatformVersion":
        // 返回 OpenHarmony 系统版本 / Return OpenHarmony system version
        result.success("OpenHarmony")
        break
      case "getNativeLogs":
        // 返回通过 hiAppEvent 真实订阅到的应用级事件（崩溃/卡死）。每条事件序列化为 JSON 字符串，
        // 保持与安卓/iOS 的 `List<String>` 契约一致。OpenHarmony 没有 logcat 等价接口，无法抓全量系统日志，
        // 但 hiAppEvent 能真实上报本应用发生的崩溃/卡死异常事件，属于"真实而非全量"的原生日志。
        // Return real app-level events (crash/freeze) subscribed via hiAppEvent, each serialized to a
        // JSON string to keep the Android/iOS `List<String>` contract. OHOS has no logcat-equivalent,
        // so full system logs are unavailable; hiAppEvent still reports genuine app crash/freeze events.
        // Dart 侧传入 { 'limit': N }（Map 形式，对应 MethodCall.args）
        // Dart passes { 'limit': N } (Map → MethodCall.args). Use call.args safely.
        const rawArgs: Object | null = call.args as Object | null
        const limitArg: number = rawArgs !== null && typeof rawArgs === "object"
          ? Number((rawArgs as Record<string, Object>)["limit"]) || 100
          : 100
        result.success(this.getNativeLogs(limitArg))
        break
      case "startNativeLogListener":
        // 开启 hiAppEvent 崩溃/卡死订阅（真实可跑；非系统日志流）。重复开启为幂等。
        // Start hiAppEvent crash/freeze subscription (real; not a system-log stream). Idempotent.
        this.startNativeLogListener()
        result.success(null)
        break
      case "stopNativeLogListener":
        // 停止 hiAppEvent 订阅并清空事件缓存 / Stop hiAppEvent subscription and clear cache
        this.stopNativeLogListener()
        result.success(null)
        break
      case "getProcessMemoryInfo":
        // 返回进程级内存信息（真实解析 /proc/self/status 的 VmRSS）
        // Returns process-level memory info (real parse of /proc/self/status VmRSS)
        result.success(this.getProcessMemoryInfo())
        break
      default:
        result.notImplemented()
    }
  }

  /// 返回通过 hiAppEvent 真实订阅到的应用级事件（崩溃/卡死），截断到 limit 条
  /// Return real app-level events (crash/freeze) subscribed via hiAppEvent, truncated to `limit`
  private getNativeLogs(limit: number): string[] {
    const n = Math.max(0, Math.floor(limit))
    if (n === 0 || this.appEvents.length === 0) {
      return []
    }
    // 取最近 n 条（缓存按时间正序追加，故从尾部截取）
    // Take the most recent n entries (cache appended in chronological order)
    const start = Math.max(0, this.appEvents.length - n)
    return this.appEvents.slice(start, this.appEvents.length)
  }

  /// 开启 hiAppEvent 崩溃/卡死订阅（幂等）/ Start hiAppEvent crash/freeze subscription (idempotent)
  private startNativeLogListener(): void {
    if (this.nativeLogListenerActive) {
      return
    }
    this.nativeLogListenerActive = true
    try {
      // onReceive 回调签名：(domain: string, appEventGroups: Array<AppEventGroup>) => void
      // 需遍历 appEventGroups -> appEventInfos 取到每条 AppEventInfo（真实崩溃/卡死事件）
      // The onReceive signature is (domain, appEventGroups); iterate groups -> infos to get each event.
      const watcher: hiAppEvent.Watcher = {
        name: ZeroInspectorKitPlugin.WATCHER_NAME,
        // 订阅应用崩溃与卡死事件（事件名，见 hiAppEvent.event）
        // Subscribe to app crash & freeze events (event names from hiAppEvent.event)
        appEventFilters: [
          {
            domain: "app",
            names: [hiAppEvent.event.APP_CRASH, hiAppEvent.event.APP_FREEZE]
          }
        ],
        onReceive: (domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>) => {
          // 将每个事件序列化为 JSON 字符串缓存，保持 List<String> 契约
          // Serialize each event to a JSON string and cache it, keeping the List<String> contract
          for (const group of appEventGroups) {
            for (const info of group.appEventInfos) {
              // 整条 AppEventInfo 直接序列化（含 domain/name/参数），规避索引签名限制
              // Serialize the whole AppEventInfo (domain/name/params) to a string
              const obj: Record<string, Object> = { "domain": domain, "eventGroup": group.name }
              obj["event"] = JSON.parse(JSON.stringify(info))
              this.appEvents.push(JSON.stringify(obj))
            }
          }
          // 控制缓存上限，避免无限增长 / Cap cache to avoid unbounded growth
          if (this.appEvents.length > 1000) {
            this.appEvents = this.appEvents.slice(this.appEvents.length - 1000)
          }
        }
      }
      hiAppEvent.addWatcher(watcher)
      this.watcher = watcher
    } catch (e) {
      hilog.warn(ZeroInspectorKitPlugin.DOMAIN, ZeroInspectorKitPlugin.TAG,
        "Failed to add hiAppEvent watcher: %{public}s", (e as Error).message)
    }
    hilog.info(ZeroInspectorKitPlugin.DOMAIN, ZeroInspectorKitPlugin.TAG,
      "ZeroInspectorKit native log listener (hiAppEvent) started")
  }

  /// 停止 hiAppEvent 订阅并清空事件缓存 / Stop hiAppEvent subscription and clear cache
  private stopNativeLogListener(): void {
    if (!this.nativeLogListenerActive) {
      return
    }
    this.nativeLogListenerActive = false
    try {
      // removeWatcher 需要传回 Watcher 对象（而非仅 name）/ removeWatcher expects the Watcher object
      if (this.watcher != null) {
        hiAppEvent.removeWatcher(this.watcher)
        this.watcher = null
      }
    } catch (e) {
      hilog.warn(ZeroInspectorKitPlugin.DOMAIN, ZeroInspectorKitPlugin.TAG,
        "Failed to remove hiAppEvent watcher: %{public}s", (e as Error).message)
    }
    this.appEvents = []
    hilog.info(ZeroInspectorKitPlugin.DOMAIN, ZeroInspectorKitPlugin.TAG,
      "ZeroInspectorKit native log listener (hiAppEvent) stopped")
  }

  /// 获取进程级内存信息 / Get process-level memory info
  ///
  /// 真实取值来源：应用自身 /proc/self/status（普通应用可读），提取
  /// True source: the app's own /proc/self/status (readable by normal apps), extracting
  /// - `VmRSS`:  进程常驻内存（字节，真实）/ Resident set size in bytes (real)
  /// - `VmSwap`: 交换占用（近似 swap，真实）/ Swap usage in bytes (real approximation)
  ///
  /// 字段映射（与安卓/iOS 对齐，缺失项填 0 + `notAvailable: true`）：
  /// Field mapping (aligned with Android/iOS; missing ones filled with 0 + `notAvailable: true`):
  /// - rss / totalRss:          取自 VmRSS（OpenHarmony 唯一的真实进程内存近似）
  /// - totalSwapPss:            取自 VmSwap
  /// - totalPss/dalvik/native/other* 等安卓分项：OpenHarmony 无等价 / no Android equivalent on OHOS
  /// - totalMem/availMem/lowMemory：OpenHarmony 无公开系统内存 API / no public system-memory API on OHOS
  /// - physicalFootprint/internal*：iOS 指标，其他平台填 0 / iOS-only metrics, 0 on others
  private getProcessMemoryInfo(): Record<string, number | boolean> {
    let rssBytes: number = 0
    let swapBytes: number = 0

    try {
      // 同步读取 /proc/self/status；特殊文件通常体积小，readTextSync 不会阻塞明显
      // Synchronously read /proc/self/status; special file is small, readTextSync is negligible
      const content: string = fileIo.readTextSync("/proc/self/status")
      rssBytes = this.parseKbField(content, "VmRSS:")
      swapBytes = this.parseKbField(content, "VmSwap:")
    } catch (e) {
      // 读取失败（如沙箱限制）时回退为 0，不阻塞调用 / Fallback to 0 on read failure (e.g. sandbox)
      hilog.warn(ZeroInspectorKitPlugin.DOMAIN, ZeroInspectorKitPlugin.TAG,
        "Failed to read /proc/self/status: %{public}s", (e as Error).message)
    }

    const info: Record<string, number | boolean> = {}

    // 1. 进程 RSS（OpenHarmony 真实取值，单位：字节）/ Process RSS (real on OHOS, bytes)
    info["rss"] = rssBytes
    info["totalRss"] = rssBytes

    // 2. iOS 物理内存占用指标（其他平台填 0）/ iOS physical footprint metrics (0 on others)
    info["physicalFootprint"] = 0
    info["internalCompressed"] = 0
    info["internalSize"] = 0

    // 3. 安卓分项字段：OpenHarmony 无等价，填 0 / Android breakdown fields: no OHOS equivalent, 0
    info["dalvikPss"] = 0
    info["nativePss"] = 0
    info["otherPss"] = 0
    info["totalPss"] = 0
    info["dalvikPrivateDirty"] = 0
    info["nativePrivateDirty"] = 0
    info["otherPrivateDirty"] = 0
    info["totalPrivateDirty"] = 0
    info["dalvikRss"] = 0
    info["nativeRss"] = 0
    info["otherRss"] = 0
    info["totalSwapPss"] = swapBytes
    info["graphics"] = 0

    // 4. 设备级内存：OpenHarmony 无公开 API，填 0 + 标记不可用
    // 4. Device-level memory: no public API on OHOS, 0 + notAvailable
    info["totalMem"] = 0
    info["availMem"] = 0
    info["lowMemory"] = false
    info["notAvailable"] = true

    return info
  }

  /// 从 /proc/self/status 文本中解析形如 `VmRSS:  12345 kB` 的字段，返回字节数 / Parse "VmRSS: 12345 kB" → bytes
  private parseKbField(content: string, key: string): number {
    const regex = new RegExp(key + "\\s+(\\d+)\\s*kB", "i")
    const match = content.match(regex)
    if (match && match.length > 1) {
      const kb = Number(match[1])
      if (!isNaN(kb)) {
        return kb * 1024
      }
    }
    return 0
  }
}
