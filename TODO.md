# TODO / 待办清单

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

#### 风险 2：`sqflite` 在鸿蒙是否可用？ ✅ 可用

- 调研结论（来源：CSDN《Flutter 三方库 sqflite 的鸿蒙化适配与实战指南》2026-05-13）：
  - `sqflite` 在鸿蒙上兼容性总体不错，**无需替换为其他包**。
  - 推荐版本 `sqflite: ^2.3.0`（原文标注「2.3.x 在鸿蒙上比较稳定」）；本插件当前 `^2.4.0` 应在鸿蒙可用，真机实测确认。
  - 数据库路径用 `sqflite` 自带的 `getDatabasesPath()` + `path` 包 `join()`，**不依赖 `path_provider`**。
  - 踩坑：路径拼接必须用 `path` 包 `join`，禁止字符串 `+ '/'`。
- 对本插件影响：数据库查看器（基于 `sqflite`）**可在鸿蒙复用**，但 `pubspec.yaml` 依赖需处理：
  - `path_provider` → 鸿蒙下用 `path_provider_harmonyos`（或条件依赖 / `dependency_overrides`）；
  - `sqflite` 当前 `^2.4.0` 在鸿蒙应可用，需实测验证。
  Impact: the database viewer (based on `sqflite`) **can be reused on OHOS**, but `pubspec.yaml` deps need handling: `path_provider` → `path_provider_harmonyos` on OHOS (or conditional dep / `dependency_overrides`). Current `sqflite: ^2.4.0` likely works on OHOS — verify on device/simulator.

### 需要补齐的清单 / Checklist of what to add

#### 高优先级 / High priority

- [x] **新增 `ohos/` 原生目录与 ArkTS 插件实现 / Add `ohos/` native dir + ArkTS plugin** ✅ (2026-08-12)
  - `ohos/src/main/ets/components/plugin/ZeroInspectorKitPlugin.ets`，`implements FlutterPlugin, MethodCallHandler`，注册 MethodChannel `zero_inspector_kit`。
  - `ohos/oh-package.json5` 版本已对齐 `1.3.3`，`ohos/` 下 `module.json5` deviceTypes 精简为 `["default"]`。
  - 安卓 `ZeroInspectorKitPlugin.kt` / iOS `ZeroInspectorKitPlugin.swift` 不动。
  - 示例 `flutter build hap` 已跑通，产物 `example/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`（unsigned，待签名装真机）。
- [x] **新增 `ZeroInspectorKitOhos` 平台实现类 / Add `ZeroInspectorKitOhos` platform impl** ✅ (2026-08-12)
  - 新增 `lib/zero_inspector_kit_ohos.dart`（`ZeroInspectorKitOhos extends ZeroInspectorKitPlatform`，走 MethodChannel `zero_inspector_kit`）。
  - `lib/zero_inspector_kit_platform_interface.dart` 新增 `isOhos` 判断与 `ensurePlatformImplementation()`，**不引用 `TargetPlatform.ohos` 枚举**（官方 Flutter 无此值，会编译报错），改用 `defaultTargetPlatform.toString().contains('ohos')` 运行时判断；`ZeroInspectorKit.init()` 早期调用。
  - barrel `lib/zero_inspector_kit.dart` 已 export `zero_inspector_kit_ohos.dart`，并 import 平台接口。
  - `flutter analyze` 0 issues，`dart format` 通过。核心能力仍纯 Dart 跨平台共用，鸿蒙专属分支预留在 ohos 实现类内。
- [x] **`pubspec.yaml` 平台声明 / `pubspec.yaml` platform declaration** ✅ (2026-08-12)
  - `flutter.plugin.platforms` 已加 `ohos`（package `zero_inspector_kit`, pluginClass `ZeroInspectorKitPlugin`），插件已被识别并打包进 HAP。
- [x] **`ohos` 原生方法对标安卓/iOS / `ohos` native methods parity with Android/iOS** ✅ (2026-08-12)
  - `ohos/.../ZeroInspectorKitPlugin.ets` 补齐中英双语注释（原仅一行占位），并与 kt/swift 对齐 MethodChannel 契约：实现 `getPlatformVersion` / `getNativeLogs` / `startNativeLogListener` / `stopNativeLogListener` / `getProcessMemoryInfo`。
  - `getProcessMemoryInfo` 返回与 iOS 一致的字段结构（含 `rss`/`totalPss`/`totalMem`/`availMem`/`lowMemory` 等），鸿蒙具体取值暂以 0 填充占位，避免 Dart 侧解析异常。Dart 侧 `PlatformChannel` 早已定义这 4 个方法，此前 `.ets` 缺实现会导致 `notImplemented`/null，现已对齐。
- [x] **`ohos` 接入真实内存与日志取值 / `ohos` real memory & log values** ✅ (2026-08-12, 代码已接入)
  - **内存（真实）**：`getProcessMemoryInfo` 同步读取应用自身 `/proc/self/status`（普通应用可读），正则解析 `VmRSS:`（真实进程常驻内存，字节）填入 `rss`/`totalRss`，`VmSwap:` 填入 `totalSwapPss`；其余安卓分项（PSS 等）OpenHarmony 无等价 API → 填 0 + `notAvailable: true`；设备级 `totalMem`/`availMem` 无公开 API → 0 + `notAvailable: true`。
  - **日志（真实但非全量）**：OpenHarmony **无** logcat 等价读取 API（hilog 仅写、不可读系统日志流），但可通过 `@ohos.hiviewdfx.hiAppEvent` 的 `addWatcher` **真实订阅应用级崩溃/卡死事件**（`hiAppEvent.event.APP_CRASH` / `APP_FREEZE`）。已落地 **B 方案**：`startNativeLogListener` 开启订阅（幂等）、`onReceive` 把事件 JSON 序列化进 `appEvents` 缓存、`getNativeLogs` 回放缓存（截断到 `limit` 条，保持 `List<String>` 契约）、`stopNativeLogListener` 取消订阅并清空。需在 `module.json5` 声明 `ohos.permission.APP_TRACKING_CONSENT` 权限（reason 用 `$string:app_tracking_reason` 引用 `resources/base/element/string.json` 资源，文案已改为英文）。注意：这是"应用级异常事件"而非全量 stdout 日志——与 iOS 用 `dup2` 抓 stdout/stderr 的真实全量日志**能力不同**；iOS 早已真实接好，无需改动。
  - 已对照 `@ohos.file.fs.readTextSync` / `@ohos.hilog` + `%{public}s` / `@ohos.hiviewdfx.hiAppEvent.addWatcher`/`removeWatcher` 公开契约编写；`flutter analyze lib` 无回归。
  - ✅ **已验证**：完整 `flutter build hap` 已在鸿蒙定制 Flutter `custom_3.35.8-ohos-1.0.1`（OpenHarmony SDK `D:\OpenHarmony\Sdk` API 20，DevEco `D:\Program Files\Huawei\DevEco Studio`）下端到端跑通，产出 `example/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`（unsigned，待签名装真机），`.ets` 零 ArkTS 错误，`flutter analyze lib` 通过。工具链 PATH 需含 ohpm/node/hvigor 与 `OHOS_SDK_HOME`/`HVIGOR_HOME`。
- [x] **`pubspec.yaml` 依赖约束对齐 / Align `pubspec.yaml` dependency constraints** ✅ (2026-08-12)
  - `environment: dart` 已放宽为 `>=3.9.2 <4.0.0`（满足鸿蒙 Dart 3.9.2，且仍兼容官方 Flutter 3.3+ 的 Dart）。`flutter: ">=3.3.0"` 满足（鸿蒙 3.35.8 ≥ 3.3.0）。
  - `path_provider_harmonyos: ^0.0.1` 已加入依赖，作为 `path_provider` 的鸿蒙联邦实现层（`lib/src/services/` 下 sqlite_provider / memory_inspector_service / export_service 三处 `import 'package:path_provider/path_provider.dart'` 在鸿蒙下由它提供平台后端）。
- [ ] **验证 `runAppWithInspector` 在鸿蒙的 `HttpOverrides.runZoned` 覆盖 / Verify `HttpOverrides.runZoned` coverage on OHOS**
  - 确保入口 Zone 覆盖完整，HTTPS + 流式响应在鸿蒙实测通过（待真机验证）。

#### 中优先级 / Medium priority

- [x] **文件导出 + 系统分享 / File export & system share** ✅ 已完成 / Done
  - **状态**: 已实现 / Implemented
  - **实现方案 / Implementation**:
    - 新增 `share_plus: ^13.2.0` 依赖（`pubspec.yaml`）
    - Added `share_plus: ^13.2.0` dependency (`pubspec.yaml`)
    - 数据写入应用临时文件（`getTemporaryDirectory` 下的 `zero_inspector_logs.*` / `zero_inspector_net.*`）
    - Write data to app temp file (`zero_inspector_logs.*` / `zero_inspector_net.*` under `getTemporaryDirectory`)
    - 通过 `SharePlus.instance.share(ShareParams(files: [...]))` 唤起系统分享面板（微信/邮件/Drive 等）
    - Invoke system share sheet via `SharePlus.instance.share(...)` (WeChat/Email/Drive etc.)
    - 用户可选「复制到剪贴板」或「保存/分享为文件」
    - User can choose "copy to clipboard" or "save/share as file"
    - 导出格式覆盖 JSON / 纯文本 / CSV / HAR / cURL（HAR 可直接导入 Chrome DevTools / Charles）
    - Export formats: JSON / plain text / CSV / HAR / cURL (HAR importable into Chrome DevTools / Charles)
    - 导出时对敏感头（Authorization/Cookie 等）支持遮蔽（`maskSensitive`）
    - Sensitive headers (Authorization/Cookie etc.) are masked on export (`maskSensitive`)
  - **涉及文件 / Related files**:
    - `lib/src/services/export_service.dart`（扩展：`writeToFile` / `exportLogsToFile` / `exportNetToFile` / `shareFile` / `exportLogsAndShare` / `exportNetAndShare` 等）
    - `lib/src/ui/log_viewer.dart`（扩展 / extended）
    - `lib/src/ui/network_viewer.dart`（扩展 / extended）
    - `pubspec.yaml`（新增 `share_plus` 依赖 / add `share_plus` dependency）

- [ ] **Memory / FPS 监控在鸿蒙的可用性 / Memory & FPS monitoring on OHOS**
  - `addTimingsCallback`（FPS）与 VM Service（内存）在鸿蒙 Engine 是否保留需实测（FPS 大概率可用；VM Service 取决于鸿蒙 Debug 模式支持）。
- [ ] **`docs/Installation.md` 增加鸿蒙段落 / Add OHOS section to `docs/Installation.md`**
  - 说明：安卓/iOS 用户照常 `flutter pub add zero_inspector_kit` 即用；**鸿蒙用户也直接从 pub.dev 拉同一包**，但需用定制 Flutter 分支（如 fvm 的 `custom_3.35.8-ohos-1.0.1`）编译 `.hap`，`ohos/` 原生代码随包分发、无需额外配置。
- [ ] **CI 与发布策略 / CI & publish strategy**
  - **继续发 pub.dev**（方案 A）：`ohos/` 原生代码随包分发，安卓/iOS/鸿蒙用户均 `flutter pub add` 一行接入。需解决 CI 干扰——官方 `flutter analyze`/`pana` 跑在官方稳定 Flutter 上，不识别 `TargetPlatform.ohos` 也不编译 `ohos/`，故要确保官方 analyze 不因 `ohos:` 平台声明或 `ohos/` 目录报错（必要时在 analyze 步骤加平台限制或路径忽略）。鸿蒙侧真机验证需在定制 Flutter 环境单独跑，不进官方 CI。

#### 低优先级 / Low priority

- [ ] **`release` 模式的 tree-shake 剔除在鸿蒙是否生效 / Verify release tree-shake on OHOS**
  - 确认 `kReleaseMode` 在鸿蒙下表现，保证 Inspector 在 release 构建被剔除。

### 下一步 / Next steps

- 已完成：调研 + `ohos/` 原生骨架 + `pubspec.yaml` 平台声明 + 示例 `flutter build hap` 跑通（unsigned HAP）+ `flutter analyze`/`dart format` 通过。安卓/iOS 业务代码保持未动。
  Done: research + `ohos/` native skeleton + `pubspec.yaml` platform declaration + example `flutter build hap` (unsigned HAP) + `flutter analyze`/`dart format` green. Android/iOS business code untouched.
- 待办（剩余）：鸿蒙真机实测 `runAppWithInspector` 的 `HttpOverrides.runZoned` 覆盖（HTTPS + 流式响应）；Memory/FPS 监控在鸿蒙 Engine 的可用性；`release` 模式 tree-shake 在鸿蒙是否生效；`docs/Installation.md` 鸿蒙段落；CI 官方 analyze 对 `ohos:` 平台声明的隔离处理。
  Todo (remaining): verify `runAppWithInspector`'s `HttpOverrides.runZoned` coverage on OHOS (HTTPS + streaming); Memory/FPS availability on OHOS Engine; release tree-shake on OHOS; `docs/Installation.md` OHOS section; CI official-analyze isolation for the `ohos:` platform declaration.

- [x] **趋势图触摸交互 / Trend chart touch interaction** ✅ 已完成 / Done
  - **状态**: 已实现 / Implemented
  - **实现方案 / Implementation**:
    - 触摸折线图显示十字准线 + 高亮最近数据点，并浮出 Tooltip 显示精确数值与相对时间（如 `-1m 23s`）
    - Touch on chart shows crosshair + highlighted nearest point, popping a tooltip with exact value and relative time (e.g. `-1m 23s`)
    - 支持手指拖动实时跟手浏览历史数据点（onPanDown/onPanUpdate 定位最近索引，onPanEnd 复位图例）
    - Support finger drag to browse historical data points in real time (onPanDown/onPanUpdate locate nearest index, onPanEnd resets to legend)
    - 未触摸时仍显示 Current / Peak / Min 图例；交互状态由 `StatefulWidget` 本地维护，不改变采样逻辑
    - Legend (Current / Peak / Min) shown when untouched; interaction state is local to a `StatefulWidget`, no change to sampling
    - Y 轴标签动态自适应当前最大值（max / 中值 / min 三档）
    - Y-axis labels auto-adapt to current max value (max / mid / min)
  - **涉及文件 / Related files**:
    - `lib/src/ui/memory_trend_chart.dart`（扩展：`MemoryTrendChart` 改为 `StatefulWidget`，`_LineChartPainter` 新增 `highlightIndex` 十字准线绘制 / extended）

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

- [x] **网络请求 Timeline / 瀑布图 / Network request timeline view** ✅ 已完成 / Done
  - **状态**: 已实现 / Implemented
  - **实现方案 / Implementation**:
    - 以统一时间窗（最早请求 → 最晚响应，两端各留 5% 余量）展示所有请求的并行关系
    - Show parallel request relationships along a shared time axis (earliest start → latest finish, 5% safe margin on both ends)
    - 每个请求分解为「等待段」（accent 色条）与「响应段」（success 色圆点），点击行可下钻详情
    - Per-request breakdown into a "wait" segment (accent bar) and "response" marker (success dot); tap a row to drill into detail
    - 左侧方法徽标（按 GET/POST/... 着色）+ URL 摘要，右侧轨道按比例映射；列表自身 `ListView` 滚动，固定行高，无无限高度溢出风险
    - Left method badge (colored by GET/POST/...) + URL summary, right track scaled to ratio; list scrolls via its own `ListView` with fixed row height (no unbounded-height overflow)
    - 顶部图例 + 请求总数；暂无请求时显示空状态
    - Legend + total count on top; empty state when no requests
  - **涉及文件 / Related files**:
    - `lib/src/ui/network_timeline.dart`（新增 / new）：`NetworkTimeline` + `_TimelineRow`
    - `lib/src/ui/network_viewer.dart`（扩展：在查看器中集成 Timeline 视图 / extended）
    - `lib/zero_inspector_kit.dart`（注册导出 / registered for export）
    - `lib/src/services/inspector_service.dart`（引用 / referenced）

- [x] **网络请求更多筛选维度 / More network request filters**
  - **状态**: 已实现（v1.4.0）/ Implemented (v1.4.0)
  - **实现方案 / Implementation**:
    - 按 HTTP Method 筛选（GET/POST/PUT/DELETE...）
    - Filter by HTTP Method (GET/POST/PUT/DELETE...)
    - 按状态码筛选（2xx/3xx/4xx/5xx）
    - Filter by status code (2xx/3xx/4xx/5xx)
    - 按拦截状态筛选（已修改/未修改）
    - Filter by interception status (modified/not modified)
  - **涉及文件 / Related files**:
    - `lib/src/ui/network_viewer.dart`（扩展：新增漏斗图标 + 可展开筛选面板，含 Method / 状态码 / 拦截状态三维筛选 / extended）
    - `lib/src/models/network_request.dart`（新增 `isModifiedByInterceptor` 字段 / new field）
    - `lib/src/services/inspector_service.dart`（`updateNetworkRequest` 增加 `modified` 参数 / new `modified` param）
    - `lib/src/interceptors/inspector_http_client.dart`、`lib/src/interceptors/inspector_response_proxy.dart`（命中规则时回写 `modified` / write back on rule match）

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

- [x] **SharedPreferences 查看器 / SharedPreferences viewer** ✅ 已完成 / Done
  - **状态**: 已实现（并入 Database 体系）/ Implemented (merged into Database)
  - **实现方案 / Implementation**:
    - 作为「自定义数据库源」并入 Database：SP 键值对被呈现为单库单表 `preferences`（`key` / `type` / `value` 三列），复用 `DatabaseViewer` 的浏览、搜索、导出流程
    - Merged into Database as a "custom DB source": SP key-values are exposed as a single DB / table `preferences` (`key`/`type`/`value`), reusing `DatabaseViewer`'s browse, search & export flow
    - 通过抽象契约 `SharedPrefsLike`（仅声明查看所需方法）适配，**插件自身不依赖 `shared_preferences`**，用户传入自己持有的实例即可兼容任意版本
    - Adapted via abstract `SharedPrefsLike` contract; the plugin does NOT depend on `shared_preferences` — callers pass their own instance for any version compatibility
    - 一行注册：`ZeroInspectorKit.registerSharedPrefs(SharedPreferencesAdapter(prefs))`
    - One-line registration: `ZeroInspectorKit.registerSharedPrefs(SharedPreferencesAdapter(prefs))`
    - 支持按 key 关键字搜索、按类型识别（bool/int/double/String/List<String>）
    - Supports key-keyword search and type detection (bool/int/double/String/List<String>)
  - **涉及文件 / Related files**:
    - `lib/src/services/shared_prefs_provider.dart`（新增：`SharedPrefsLike` / `SharedPreferencesAdapter` / `SharedPrefsProvider`）
    - `lib/zero_inspector_kit.dart`（新增 `registerSharedPrefs()` 公开 API + 导出）
    - `lib/src/ui/database_viewer.dart`（复用，无单独 SP 查看器页面 / reused, no separate SP viewer page）

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

- [x] **Widget 检查器 / Widget inspector** ✅ 已完成 / Done
  - **状态**: 已实现 / Implemented
  - **实现方案 / Implementation**:
    - 对当前渲染树拍一次快照（构建后回调），以**面包屑导航**方式浏览（类似文件管理器）：主列表只显示当前层，点击含子节点的项即下钻到下一层，顶部分层面包屑可一键跳回任意祖先层；叶子节点点击弹出底部抽屉看详情
    - Snapshot the current widget tree (post-frame callback) and browse it via **breadcrumb navigation** (file-manager style): main list shows only the current level, tap an item with children to drill into its children, breadcrumb bar jumps back to any ancestor, tapping a leaf opens a bottom-sheet detail
    - 浏览交互历经「内联可折叠树 + 横向滑动整棵树」打磨为面包屑导航，彻底消除深层节点的 `RenderFlex` 横向溢出与反直觉横滑
    - Browsing evolved from "inline collapsible tree with whole-tree horizontal scroll" into breadcrumb navigation, removing the `RenderFlex` horizontal overflow and unintuitive panning on deep trees
    - 非实时（one-shot snapshot），点击工具栏刷新或开关重建以重新快照
    - Not live (one-shot snapshot); tap toolbar Refresh or toggle the switch to re-snapshot
  - **涉及文件 / Related files**:
    - `lib/src/models/widget_tree_node.dart`（新增 / new）
    - `lib/src/services/widget_tree_service.dart`（新增 / new）
    - `lib/src/ui/widget_tree_viewer.dart`（新增 / new）
  - **用户 API / User API**:
    - 通过 `ZeroInspectorKit` 总开关开启；无需额外 API 调用
    - Enabled via the `ZeroInspectorKit` master switch; no extra API call needed

- [ ] **路由追踪穿透包装 Widget / Route tracking through wrapper widgets**
  - **状态**: 待实现 / To be implemented
  - **背景 / Context**:
    - 当前 `runAppWithInspector` 仅在 `app is MaterialApp` 时才注入 `InspectorRouteObserver`；若用户传 `StatelessWidget` / `Container` 等中间层包着 `MaterialApp`，observer 不会被注册，路由栏永远显示 `0 routes`
    - Currently `_wrapAppWithRouteObserver` only injects `InspectorRouteObserver` when `app is MaterialApp`; if the user passes a `StatelessWidget`/`Container` wrapping a `MaterialApp`, the observer is never registered and Routes shows `0 routes` forever
  - **实现方案（路线 C，推荐）/ Implementation (Approach C, recommended)**:
    - 在包装期模拟 build，穿过中间层（StatelessWidget/StatefulWidget/Container/Builder 等无 Navigator 的壳），找到真正的 `MaterialApp` 子树后再注入 `navigatorObservers`
    - During wrapping, simulate a build pass to drill through intermediate shells (StatelessWidget/StatefulWidget/Container/Builder etc. that hold no Navigator) and inject `navigatorObservers` once the real `MaterialApp` subtree is found
    - 向后兼容，不改动公共 API；仅修改 `lib/zero_inspector_kit.dart` 的 `_wrapAppWithRouteObserver`
    - Backward compatible, no public API change; only touch `_wrapAppWithRouteObserver` in `lib/zero_inspector_kit.dart`
  - **为何不选其他路线 / Why not other approaches**:
    - 路线 A（事后遍历 Element 树注入 observer）：`RouteObserver` 依赖 Navigator 主动回调，事后注入无法补救，不可行
    - Approach A (inject observer by traversing the Element tree after the fact): `RouteObserver` relies on Navigator callbacks, post-hoc injection can't work — infeasible
    - 路线 B（再包一层 Navigator）：会破坏路由栈语义（push/pop 作用于内层 Navigator），代价过大
    - Approach B (wrap another Navigator): breaks route-stack semantics (push/pop hit the inner Navigator) — too costly
  - **涉及文件 / Related files**:
    - `lib/zero_inspector_kit.dart`（扩展 / extended）
    - 建议补充单元测试 / Add unit tests recommended
