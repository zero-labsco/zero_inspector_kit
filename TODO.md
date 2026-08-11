# TODO / 待办事项

## Memory Inspector / 内存检查器

### 高优先级

- [x] **恢复 Dart VM Heap 内存监控功能 / Restore Dart VM Heap memory monitoring feature** ✅ 已完成 / Done
  - **状态**: 已恢复 / Restored
  - **实现方案 / Implementation**:
    - 通过 HTTP 轮询连接 VM Service（避免 WebSocket 在 Android 真机的 Connection refused 问题）
    - Connect to VM Service via HTTP polling (avoiding WebSocket Connection refused issue on Android real devices)
    - 使用 `ProcessInfo.currentRss` 作为降级方案，VM Service 不可用时仍可显示进程级内存
    - Use `ProcessInfo.currentRss` as fallback, process-level memory is still available when VM Service is unavailable
    - 包含 500ms 初始延迟 + 最多 5 次重试（1 秒间隔）的连接机制
    - Connection mechanism with 500ms initial delay + up to 5 retries (1-second interval)
  - **涉及文件 / Related files**:
    - `lib/src/models/memory_snapshot.dart`（已恢复 / restored）
    - `lib/src/services/memory_inspector_service.dart`（已扩展 / extended）
    - `lib/src/ui/memory_viewer.dart`（已扩展 / extended）
    - `lib/src/ui/memory_trend_chart.dart`（新增 / new）
  - **已实现的功能 / Implemented features**:
    - [x] Dart Heap 内存使用量概览卡片 / Dart Heap memory usage overview card
    - [x] 内存趋势图（折线图，可切换 RSS/Heap/New/Old 指标）/ Memory trend chart (switchable RSS/Heap/New/Old metrics)
    - [x] 新生代/老生代详细内存数据 / New generation / old generation detailed memory data
    - [x] 手动触发 GC 功能 / Manual GC trigger feature
    - [x] 历史快照清理功能 / History snapshot clear feature
  - **优雅降级 / Graceful degradation**:
    - VM Service 不可用时（release 模式或连接失败），UI 显示 N/A 占位说明
    - When VM Service is unavailable (release mode or connection failure), UI shows N/A placeholder
    - 不阻塞其他监控功能（图片缓存、存储统计）
    - Does not block other monitoring features (image cache, storage stats)
    - Trigger GC 按钮在 VM Service 不可用时变灰禁用
    - Trigger GC button is grayed out and disabled when VM Service is unavailable

### 低优先级

- [ ] 研究 iOS 上 VM Service 的连接情况 / Research VM Service connection on iOS
- [x] **添加内存泄漏检测功能 / Add memory leak detection feature** ✅ 已完成 / Done
  - **状态**: 已完成 / Done
  - **实现方案 / Implementation**:
    - 使用 Dart 2.17+ `WeakReference` 弱引用持有对象，不会阻止 GC
      Uses Dart 2.17+ `WeakReference` weak reference to hold objects, will not prevent GC
    - 四状态流转：tracking → verifying → leaked / released
      Four-state transition: tracking → verifying → leaked / released
    - verifying 阶段：超过预期释放时间后自动触发 GC（VM Service 可用时），等待 3 秒再判定
      verifying phase: auto-trigger GC after exceeding expected release time (when VM Service available),
      wait 3 seconds before determination
    - 每 2 秒定时检查追踪对象；追踪记录上限 500 条，超出自动清理最旧的已释放记录
      Check tracked objects every 2 seconds; max 500 tracking records,
      oldest released records auto-cleaned when exceeded
  - **涉及文件 / Related files**:
    - `lib/src/models/leak_record.dart`（新增 / new）: 泄漏记录模型 + LeakStatus 枚举
    - `lib/src/services/memory_inspector_service.dart`（扩展 / extended）:
      - `trackObject()` / `untrackObject()` / `clearLeakRecords()` 三个公开 API
      - `_checkLeakRecords()` 周期性检测逻辑（状态机）
      - `_trimExcessRecords()` 超量清理
    - `lib/src/ui/memory_viewer.dart`（扩展 / extended）:
      - Memory Leak Detection 卡片：Tracking / Leaked / Released 统计 + 泄漏列表 + 追踪列表
      - 使用说明面板（无追踪记录时展示）+ Clear 清空按钮
  - **用户 API / User API**:
    ```dart
    MemoryInspectorService.instance.trackObject(
      myBloc,
      tag: 'HomePage_myBloc',
      expectedReleaseAfter: Duration(seconds: 60),
    );
    ```
- [ ] 添加图片内存详细信息（单张图片大小）/ Add detailed image memory info (per image size)

---

## Performance Monitoring / 性能监控

### 高优先级

- [x] **FPS / 帧率监控 / FPS monitoring** ✅ 已完成 / Done
  - **状态**: 已实现 / Implemented
  - **实现方案 / Implementation**:
    - 使用 `WidgetsBinding.instance.addTimingsCallback` 采集帧数据（零侵入）
    - Collect frame data via `WidgetsBinding.instance.addTimingsCallback` (zero-invasion)
    - 实时 FPS 显示 + 帧耗时分析（>16ms 掉帧预警）
    - Real-time FPS display + frame duration analysis (>16ms jank warning)
    - FPS 数据在 Inspector 面板内查看，通过总开关控制启停
    - FPS data viewed in Inspector panel, controlled by master switch
  - **涉及文件 / Related files**:
    - `lib/src/services/fps_service.dart`（新增 / new）
    - `lib/src/ui/fps_viewer.dart`（新增 / new）
    - `lib/src/ui/inspector_panel.dart`（扩展 / extended，IndexedStack + ValueKey 保持状态）
  - **API / API**:
    - `FpsService.instance.start()` / `stop()` / `clear()`
    - `currentFps` / `jankRate` / `totalFrameCount` / `totalJankyCount` / `fpsHistory` / `frameRecords`

---

## Data Export & Sharing / 数据导出与分享

### 高优先级

- [x] **数据导出功能 / Data export feature** ✅ 已完成 / Done
  - **状态**: 已实现 / Implemented
  - **实现方案 / Implementation**:
    - 导出网络请求列表为 JSON（便于 Bug 复现和团队协作）
    - Export network request list as JSON (for bug reproduction and team collaboration)
    - 导出日志为纯文本 / JSON
    - Export logs as plain text / JSON
    - 通过剪贴板复制（无需额外依赖）
    - Copy to clipboard (no extra dependencies)
    - 在日志查看器和网络查看器工具栏添加导出按钮
    - Export buttons added in log viewer and network viewer toolbars
  - **涉及文件 / Related files**:
    - `lib/src/services/export_service.dart`（新增 / new）
    - `lib/src/ui/network_viewer.dart`（扩展 / extended）
    - `lib/src/ui/log_viewer.dart`（扩展 / extended）
    - `lib/src/models/log_entry.dart`（添加 toJson / added toJson）
    - `lib/src/models/network_request.dart`（添加 toJson / added toJson）
  - **API 简化 / API simplified**:
    - `logsToJson()` / `logsToText()` / `netToJson()` 导出方法
    - `copyLogs({json: true})` / `copyNet()` / `copy(String)` 复制方法
    - `_lvl()` 替代 `_getLevelPrefix()`

### 低优先级

- [ ] **文件导出 + 系统分享 / File export & system share**
  - **状态**: 待实现 / To be implemented
  - **实现方案 / Implementation**:
    - 将数据写入临时文件（如 `_inspector_export_*.json`）
    - Write data to temp file (e.g. `_inspector_export_*.json`)
    - 通过 `share_plus` 调用系统分享面板（微信/邮件/Drive 等）
    - Use `share_plus` to invoke system share panel (WeChat/Email/Drive etc.)
    - 用户可选「复制到剪贴板」或「保存/分享为文件」
    - User can choose "copy to clipboard" or "save/share as file"
    - 需要额外依赖 `share_plus`（约 4KB，Android/iOS 原生实现）
    - Requires extra dependency `share_plus` (~4KB, native Android/iOS implementation)
  - **涉及文件 / Related files**:
    - `lib/src/services/export_service.dart`（扩展 / extended）
    - `lib/src/ui/log_viewer.dart`（扩展 / extended）
    - `lib/src/ui/network_viewer.dart`（扩展 / extended）
    - `pubspec.yaml`（新增依赖 / add dependency）

---

## Memory Viewer Optimizations / 内存查看器优化

### 中优先级

- [ ] **趋势图触摸交互 / Trend chart touch interaction**
  - **状态**: 待实现 / To be implemented
  - **实现方案 / Implementation**:
    - 触摸折线图显示指示器（Tooltip 显示精确数值和时间）
    - Touch on chart shows tooltip with exact value and timestamp
    - 支持手指滑动查看历史数据点
    - Support finger drag to browse historical data points
    - Y 轴标签动态自适应当前最大值
    - Y-axis labels auto-adapt to current max value
  - **涉及文件 / Related files**:
    - `lib/src/ui/memory_trend_chart.dart`（扩展 / extended）

- [ ] **内存历史窗口可配置 / Configurable memory history window**
  - **状态**: 待实现 / To be implemented
  - **实现方案 / Implementation**:
    - 提供 30s / 1min / 5min / 自定义选项
    - Provide 30s / 1min / 5min / custom options
    - 通过 Inspector 面板内设置项调整
    - Adjust via in-panel settings
  - **涉及文件 / Related files**:
    - `lib/src/services/memory_inspector_service.dart`（扩展 / extended）
    - `lib/src/ui/memory_viewer.dart`（扩展 / extended）

---

## Network Viewer Optimizations / 网络查看器优化

### 中优先级

- [ ] **网络请求 Timeline / 瀑布图 / Network request timeline view**
  - **状态**: 待实现 / To be implemented
  - **实现方案 / Implementation**:
    - 按时间轴展示所有请求的并行关系
    - Show parallel request relationships along a time axis
    - 每个请求的耗时分解（发送/等待/接收）
    - Per-request duration breakdown (send/wait/receive)
    - 慢请求预警（>3s 标红）
    - Slow request warning (>3s highlighted in red)
  - **涉及文件 / Related files**:
    - `lib/src/ui/network_timeline.dart`（新增 / new）
    - `lib/src/ui/network_viewer.dart`（扩展 / extended）

- [ ] **网络请求更多筛选维度 / More network request filters**
  - **状态**: 待实现 / To be implemented
  - **实现方案 / Implementation**:
    - 按 HTTP Method 筛选（GET/POST/PUT/DELETE...）
    - Filter by HTTP Method (GET/POST/PUT/DELETE...)
    - 按状态码筛选（2xx/3xx/4xx/5xx）
    - Filter by status code (2xx/3xx/4xx/5xx)
    - 按拦截状态筛选（已修改/未修改）
    - Filter by interception status (modified/not modified)
  - **涉及文件 / Related files**:
    - `lib/src/ui/network_viewer.dart`（扩展 / extended）

- [ ] **拦截规则增强 / Interceptor rule enhancements**
  - **状态**: 待实现 / To be implemented
  - **实现方案 / Implementation**:
    - 支持请求延迟（模拟慢网络）
    - Support request delay (simulate slow network)
    - 支持响应 Mock（直接返回模拟数据）
    - Support response mock (return simulated data directly)
    - 支持基于请求次数的触发规则
    - Support trigger rules based on request count
  - **涉及文件 / Related files**:
    - `lib/src/models/interceptor_rule.dart`（扩展 / extended）
    - `lib/src/services/inspector_service.dart`（扩展 / extended）
    - `lib/src/ui/network_viewer.dart`（扩展 / extended）

---

## Log Viewer Optimizations / 日志查看器优化

### 中优先级

- [ ] **日志查看器增强 / Log viewer enhancements**
  - **状态**: 待实现 / To be implemented
  - **实现方案 / Implementation**:
    - 自动滚动到最新（可暂停）
    - Auto-scroll to latest (with pause option)
    - 支持正则搜索
    - Support regex search
    - 按 tag 分组/过滤
    - Group/filter by tag
    - 一键复制单条日志
    - One-click copy single log entry
  - **涉及文件 / Related files**:
    - `lib/src/ui/log_viewer.dart`（扩展 / extended）

---

## Data Persistence / 数据持久化

### 中优先级

- [ ] **SharedPreferences / UserDefaults 查看器 / SharedPreferences viewer**
  - **状态**: 待实现 / To be implemented
  - **实现方案 / Implementation**:
    - 列出所有 SharedPreferences 文件
    - List all SharedPreferences files
    - 查看 key-value 数据（支持 String/int/bool 等类型）
    - View key-value data (supports String/int/bool types)
    - 支持搜索和导出
    - Support search and export
    - 通过 `getSharedPreferences` 读取
    - Read via `getSharedPreferences`
  - **涉及文件 / Related files**:
    - `lib/src/services/shared_prefs_service.dart`（新增 / new）
    - `lib/src/ui/shared_prefs_viewer.dart`（新增 / new）

---

## UX & DevEx Improvements / 用户体验与开发体验改进

### 低优先级

- [ ] **悬浮按钮位置持久化 / Floating button position persistence**
  - **状态**: 待实现 / To be implemented
  - **实现方案 / Implementation**:
    - 保存用户上次拖动位置到 SharedPreferences
    - Save last drag position to SharedPreferences
    - 重启 App 后恢复到上次位置
    - Restore position on app restart
  - **涉及文件 / Related files**:
    - `lib/src/ui/floating_button.dart`（扩展 / extended）

- [ ] **Widget 检查器 / Widget inspector**
  - **状态**: 待实现 / To be implemented
  - **实现方案 / Implementation**:
    - 类似 Flutter Inspector 的 Widget 树查看功能
    - Widget tree inspection similar to Flutter Inspector
    - 重量级功能，可作为后续独立版本
    - Heavy feature, can be a standalone future version
  - **涉及文件 / Related files**:
    - `lib/src/ui/widget_inspector.dart`（新增 / new）

---

## HarmonyOS (OpenHarmony) 适配调研 / HarmonyOS (OpenHarmony) Adaptation Research

> 分支：`feat/ohos-support`（基于 `main`）。调研时间：2026-08-12。
> Branch: `feat/ohos-support` (based on `main`). Research date: 2026-08-12.

### 可行性结论 / Feasibility verdict

- ✅ **可行 / Feasible**，但属于中等偏大的工程，不是开关式支持。
  Feasible, but a medium-to-large effort — not a toggle.
- 鸿蒙用的是 **OpenHarmony SIG 的 Flutter 定制分支**（非官方稳定版），你的官方 Flutter 3.41.7（安卓/iOS）**完全不受影响**，两者物理隔离在不同目录。
  HarmonyOS uses OpenHarmony SIG's custom Flutter fork (not official stable). Your official Flutter 3.41.7 (Android/iOS) is **unaffected**; the two are physically isolated in separate directories.
- 已在本机装好鸿蒙 Flutter：`D:\Flutter\fvm\versions\custom_3.35.8-ohos-1.0.1`（Dart 3.9.2），通过 fvm 管理；OpenHarmony SDK 在 `D:\OpenHarmony\Sdk`（API 20）。
  HarmonyOS Flutter installed locally: `D:\Flutter\fvm\versions\custom_3.35.8-ohos-1.0.1` (Dart 3.9.2), managed via fvm; OpenHarmony SDK at `D:\OpenHarmony\Sdk` (API 20).

### 平台分流方案（保安卓/iOS 稳定性）/ Platform branching (keep Android/iOS stable)

- Dart 侧用 `defaultTargetPlatform == TargetPlatform.ohos` 做 `if`/`switch` 分流（鸿蒙分支给 `TargetPlatform` 加了 `ohos` 枚举值）。
  Use `defaultTargetPlatform == TargetPlatform.ohos` for `if`/`switch` branching (the OHOS fork adds an `ohos` enum value to `TargetPlatform`).
- 插件层利用现有 `plugin_platform_interface`：注册 `ZeroInspectorKitOhos`（新写）与 `ZeroInspectorKitMethodChannel`（安卓/iOS 原样不动）并存。
  Leverage the existing `plugin_platform_interface`: register a new `ZeroInspectorKitOhos` alongside the untouched `ZeroInspectorKitMethodChannel` (Android/iOS unchanged).
- 原生代码放新目录 `ohos/`（ArkTS `.ets`），`android/` 与 `ios/` 目录互不干扰；普通 `flutter build apk/ios` 不会编译 `ohos/`。
  Native code lives in a new `ohos/` dir (ArkTS `.ets`); `android/` and `ios/` are untouched; normal `flutter build apk/ios` won't compile `ohos/`.

### 两个核心风险点调研结果 / Two core risk findings

#### 风险 1：`HttpOverrides` 网络拦截在鸿蒙 Engine 是否生效？ ✅ 生效

- 调研结论（来源：CSDN《Flutter 三方库 http_client_interceptor 的鸿蒙化适配指南》2026-03-11）：
  - 鸿蒙端**原生支持** `HttpOverrides` + 注入代理 `HttpClient` 的全局拦截方案，**不需要额外 package**。
  - 能拦截全量 Dart 原生 `HttpClient` 请求，含第三方插件内部直接使用的 `HttpClient`（对业务代码零侵入）。
  - 限制/坑点：
    1. 必须在**首个 `main()` 的 `runZoned` 内启动 `runApp`**，覆盖不全则部分请求绕过拦截；
    2. 需正确传递 `SecurityContext` 以免 HTTPS 证书校验失败；
    3. 响应流需"包装流非破坏嗅探"，避免过早关闭 Body 流导致业务代码拿不到数据。
- 对本插件影响：网络日志拦截（`HttpOverrides` + `inspector_http_client`）**核心机制在鸿蒙可用**，但需在 `runAppWithInspector` 入口确保 `HttpOverrides.runZoned` 覆盖完整，并在鸿蒙下验证 HTTPS 与流式响应读取。
  Impact: the network-log interception core (`HttpOverrides` + `inspector_http_client`) **is usable on OHOS**, but `runAppWithInspector` must ensure full `runZoned` coverage, and HTTPS/streaming responses must be verified on OHOS.

#### 风险 2：`sqflite` 在鸿蒙是否可用？ ✅ 可用（推荐 2.3.x）

- 调研结论（来源：CSDN《Flutter 三方库 sqflite 的鸿蒙化适配与实战指南》2026-05-13）：
  - `sqflite` 在鸿蒙上兼容性总体不错，**无需替换为其他包**。
  - 推荐版本 `sqflite: ^2.3.0`（原文标注「2.3.x 在鸿蒙上比较稳定」）。
  - 数据库路径用 `sqflite` 自带的 `getDatabasesPath()` + `path` 包 `join()`，**不依赖 `path_provider`**（本插件已用 `sqflite` + `path_provider`，鸿蒙下 `path_provider` 需替换为 `path_provider_harmonyos` 或用 `getDatabasesPath()` 直接替代）。
  - 踩坑：路径拼接必须用 `path` 包 `join`，禁止字符串 `+ '/'`。
- 对本插件影响：数据库查看器（基于 `sqflite`）**可在鸿蒙复用**，但 `pubspec.yaml` 依赖需处理：
  - `path_provider` → 鸿蒙下用 `path_provider_harmonyos`（或条件依赖 / `dependency_overrides`）；
  - `sqflite` 当前 `^2.4.0`（调研推荐 2.3.x 稳定；2.4.0 在鸿蒙应可用，需在真机/模拟器实测确认）。
  Impact: the database viewer (based on `sqflite`) **can be reused on OHOS**, but `pubspec.yaml` deps need handling: `path_provider` → `path_provider_harmonyos` on OHOS (or conditional dep / `dependency_overrides`). Current `sqflite: ^2.4.0` likely works on OHOS — verify on device/simulator.

### 需要补齐的清单 / Checklist of what to add

#### 高优先级 / High priority

- [ ] **新增 `ohos/` 原生目录与 ArkTS 插件实现 / Add `ohos/` native dir + ArkTS plugin**
  - 参考：`ohos/` 下实现 `ZeroInspectorKitPlugin.ets`，`implements FlutterPlugin, MethodCallHandler`，注册 MethodChannel `zero_inspector_kit`。
  - 安卓 `ZeroInspectorKitPlugin.kt` / iOS `ZeroInspectorKitPlugin.swift` 不动。
- [ ] **新增 `ZeroInspectorKitOhos` 平台实现类 / Add `ZeroInspectorKitOhos` platform impl**
  - 在 `lib/zero_inspector_kit_platform_interface.dart` 注册；barrel 按 `TargetPlatform.ohos` 分流。
- [ ] **`pubspec.yaml` 约束对齐 / Align `pubspec.yaml` constraints**
  - `environment: dart` 当前 `>=3.11.0`，但鸿蒙 Dart 是 3.9.2 → **不满足**。需改为条件约束或 `>=3.9.2 <4.0.0`（注意：改低会放宽官方约束，需评估；或用 `dependency_overrides` 临时解决）。
  - `flutter: ">=3.3.0"` 满足（鸿蒙 3.35.8 ≥ 3.3.0）。
  - `path_provider` 增加鸿蒙条件依赖 `path_provider_harmonyos`。
- [ ] **验证 `runAppWithInspector` 在鸿蒙的 `HttpOverrides.runZoned` 覆盖 / Verify `HttpOverrides.runZoned` coverage on OHOS**
  - 确保入口 Zone 覆盖完整，HTTPS + 流式响应在鸿蒙实测通过。

#### 中优先级 / Medium priority

- [ ] **Memory / FPS 监控在鸿蒙的可用性 / Memory & FPS monitoring on OHOS**
  - `addTimingsCallback`（FPS）与 VM Service（内存）在鸿蒙 Engine 是否保留需实测（FPS 大概率可用；VM Service 取决于鸿蒙 Debug 模式支持）。
- [ ] **`docs/Installation.md` 增加鸿蒙段落 / Add OHOS section to `docs/Installation.md`**
  - 说明需使用 fvm 的鸿蒙 Flutter 分支编译 `.hap`，不走 pub.dev。
- [ ] **CI 与发布策略 / CI & publish strategy**
  - 鸿蒙包不走 pub.dev（走华为/OpenHarmony 私仓或单独发布），CI 需排除 `ohos/` 对官方 `flutter analyze` 的干扰（或加 `if (ohos)` 隔离）。

#### 低优先级 / Low priority

- [ ] **`release` 模式的 tree-shake 剔除在鸿蒙是否生效 / Verify release tree-shake on OHOS**
  - 确认 `kReleaseMode` 在鸿蒙下表现，保证 Inspector 在 release 构建被剔除。

### 下一步 / Next steps

- 当前仅完成调研与清单沉淀，**未改动任何业务代码**（安卓/iOS 保持稳定）。
  Only research and this checklist so far — **no business code changed** (Android/iOS stay stable).
- 建议先在一个最小 demo 验证「MethodChannel + HttpOverrides 在鸿蒙跑通」，再回头铺开本插件全功能。
  Recommend validating a minimal demo ("MethodChannel + HttpOverrides on OHOS") before fully porting this plugin.
