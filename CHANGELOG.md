# Changelog

## 1.4.0

> **🧭 路由追踪穿透 / Route-observer penetration:** `ZeroInspectorKit.runAppWithInspector` 现在能穿透包裹根组件的轻量壳（如 `StatelessWidget` / `Container` / `Builder` / `Padding` / `Center` / `SizedBox` 等），找到内部的 `MaterialApp` 并自动注入 `InspectorRouteObserver`，无需把 `MaterialApp` 直接作为根传入即可启用路由追踪。遇到不可穿透的组件（如 `StatefulWidget` 壳）时安全回退到外层包裹模式。无新增公共 API。
> `ZeroInspectorKit.runAppWithInspector` now penetrates a lightweight shell wrapping the root (e.g. `StatelessWidget` / `Container` / `Builder` / `Padding` / `Center` / `SizedBox`), finds the inner `MaterialApp`, and auto-injects `InspectorRouteObserver` — so route tracking works even when the `MaterialApp` is not passed as the root directly. Falls back safely to an outer wrapper when the shell is impenetrable (e.g. a `StatefulWidget` shell). No new public API.

- 路由 / Route
  - `runAppWithInspector` 现在递归穿透中间壳组件以定位 `MaterialApp` 并注入路由观察者；示例 app 根节点改为 `StatelessWidget` 壳以演示该能力
  - `runAppWithInspector` now recursively penetrates intermediate shell widgets to locate the `MaterialApp` and inject the route observer; the example app's root is now a `StatelessWidget` shell to demonstrate the capability
  - 新增 `test/route_observer_penetration_test.dart` 覆盖穿透成功与回退路径
  - Added `test/route_observer_penetration_test.dart` covering both the penetration-success and fallback paths

- 网络 / Network
  - 网络查看器新增可展开筛选面板（工具栏漏斗图标），支持按 **HTTP Method**（GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS，多选）、**状态码区间**（2xx/3xx/4xx/5xx/Other，多选）、**拦截状态**（全部/已修改/未修改）三维筛选，可与关键词搜索叠加；含一键 Reset
  - The network viewer gains an expandable filter panel (funnel icon in the toolbar) supporting **HTTP Method** (GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS, multi-select), **status code** (2xx/3xx/4xx/5xx/Other, multi-select), and **interception status** (All/Modified/Unmodified) filters, composable with keyword search; includes a Reset action
  - `NetworkRequest` 新增 `isModifiedByInterceptor` 字段，命中拦截规则并实际修改请求/响应体或状态码时由拦截层自动置 `true`；请求卡片对「已修改」请求显示标记图标
  - `NetworkRequest` gains an `isModifiedByInterceptor` field, auto-set to `true` by the interception layer when a rule actually modifies the request/response body or status code; modified requests show a marker icon on the card

## 1.3.6

> **📊 趋势图交互增强 / Trend chart interaction:** 内存趋势图现在支持触摸交互——点击或拖动折线图区域可高亮最近的数据点，显示十字准线与浮动 Tooltip（精确数值 + 相对"现在"的时间偏移）。未触摸时仍显示 Current / Peak / Min 图例。无新增公共 API，组件沿用原构造签名。
> The memory trend chart now supports touch interaction — tap or drag on the chart to highlight the nearest data point, showing a crosshair plus a floating tooltip with the exact value and the time offset from "now". The Current / Peak / Min legend is still shown when not touched. No new public API; the widget keeps its original constructor signature.

- 内存 / Memory
  - 新增趋势图触摸交互：点击 / 拖动定位最近数据点，绘制十字准线并高亮该点（蓝色外圈 + 实心点）
  - Added trend chart touch interaction: tap/drag locates the nearest data point, drawing a crosshair and highlighting it (blue ring + solid dot)
  - 触摸时顶部浮出 Tooltip，显示该时刻的精确数值与相对时间（如 `-1m 23s`）
  - A floating tooltip appears on touch, showing the exact value and relative time (e.g. `-1m 23s`)
  - 未触摸时保持原 Current / Peak / Min 图例展示，交互状态由 `StatefulWidget` 本地维护，不影响采样逻辑
  - Untouched state keeps the original Current / Peak / Min legend; interaction state is local to a `StatefulWidget` and does not affect sampling logic

## 1.3.5

> **🚀 检查器能力扩展 / Inspector capability expansion：** 本版本新增网络 **Timeline 瀑布图**、**系统分享**导出内容（基于 `share_plus`）、**Widget 检查器**（树形展示业务 Widget 树，自动排除检查器自身浮层），并将 **Database 查看器**扩展到 **SharedPreferences** 与 **Hive**。Widget 检查器与 Network Timeline 均**默认关闭、通过面板顶部开关控制（与内存监控一致）**。公共 API 新增 `SharedPrefsProvider`、`HiveProvider`、`NetworkTimeline`、`WidgetTreeInspector`、`WidgetTreeService`、`InspectorSwitchCard`，以及一行注册方法 `ZeroInspectorKit.registerSharedPrefs()` / `registerHive()` 与 `init` 配置项 `enableWidgetInspector` / `enableNetworkTimeline`。
> This release adds a network **Timeline / waterfall view**, **system sharing** of exported content (via `share_plus`), a **Widget inspector** (collapsible business widget tree, auto-excluding the inspector's own overlay), and extends the **Database viewer** to **SharedPreferences** and **Hive**. Both the Widget inspector and Network Timeline are **off by default and toggled via a top switch in the panel (like memory monitoring)**. New public API: `SharedPrefsProvider`, `HiveProvider`, `NetworkTimeline`, `WidgetTreeInspector`, `WidgetTreeService`, `InspectorSwitchCard`, plus one-line registration `ZeroInspectorKit.registerSharedPrefs()` / `registerHive()` and `init` flags `enableWidgetInspector` / `enableNetworkTimeline`.

- 网络 / Network
  - 新增 Timeline 瀑布图视图（`NetworkTimeline`），在 NetworkViewer 中以时间轴展示每个请求的耗时与并发重叠，可点击定位详情
  - Added a Timeline/waterfall view (`NetworkTimeline`) showing per-request duration & overlap on a time axis, tappable to locate details in NetworkViewer
  - Network Timeline 现由面板顶部**总开关**控制，默认关闭；开启后工具栏才出现视图切换，关闭时始终以列表展示（避免无谓的瀑布图布局开销）
  - Network Timeline is now gated by a top **master switch** in the panel, off by default; enabling it reveals the view toggle, and the list is always shown otherwise
- Widget 检查器 / Widget inspector
  - 新增 Widget 树检查器（`WidgetTreeInspector`），以**面包屑导航**浏览当前渲染树快照（主列表只显示当前层、点击下钻、面包屑跳回祖先），叶子节点弹出详情，自动排除检查器自身子树
  - Added a widget-tree inspector (`WidgetTreeInspector`) that browses a **breadcrumb navigation** snapshot of the current widget tree (current-level list, tap to drill in, breadcrumb jumps back to ancestors), with a leaf detail sheet, auto-excluding the inspector's own subtree
  - 由 `WidgetTreeService` 驱动，面板顶部**总开关**控制，默认关闭；仅开启后才遍历渲染树（避免无谓开销），与内存监控一致
  - Driven by `WidgetTreeService`, gated by a top **master switch**, off by default; the element tree is walked only when enabled (no needless overhead), matching memory monitoring
- 导出 / Export
  - 新增基于 `share_plus` 的**系统分享**，日志与网络请求均可一键分享导出文件（pubspec 新增 `share_plus` 依赖）
  - Added `share_plus`-based **system sharing** — logs and network requests can be shared via the system sheet (new `share_plus` dependency)
- 数据库 / Database
  - Database 查看器现支持 **SharedPreferences** 与 **Hive**：新增 `SharedPrefsProvider` / `HiveProvider`，通过 `DatabaseRegistry.instance.registerProvider(...)` 手动注册（插件零依赖，自动适配任意版本）
  - The Database viewer now supports **SharedPreferences** and **Hive**: new `SharedPrefsProvider` / `HiveProvider` registered manually via `DatabaseRegistry.instance.registerProvider(...)` (zero plugin dependency, any version supported)
  - 新增**一行注册 API**：`ZeroInspectorKit.registerSharedPrefs(SharedPreferencesAdapter(prefs))` 与 `ZeroInspectorKit.registerHive({'name': HiveBoxAdapter(box)})`，无需手动拼接 `DatabaseRegistry`
  - New **one-line registration API**: `ZeroInspectorKit.registerSharedPrefs(SharedPreferencesAdapter(prefs))` and `ZeroInspectorKit.registerHive({'name': HiveBoxAdapter(box)})` — no need to touch `DatabaseRegistry` directly
  - `init` / `runAppWithInspector` 新增 `enableWidgetInspector`、`enableNetworkTimeline` 配置项，可直接预置对应开关为开启
  - `init` / `runAppWithInspector` gain `enableWidgetInspector` and `enableNetworkTimeline` flags to pre-enable the switches
- Widget 检查器交互打磨 / Widget inspector UX polish
  - 将浏览方式从「内联可折叠树 + 横向滑动整棵树」改为**面包屑导航**（类似文件管理器）：主列表只显示当前层节点，点击含子节点的项即下钻到下一层，顶部分层面包屑可一键跳回任意祖先层；叶子节点点击弹出底部抽屉看详情。彻底消除深层节点的 `RenderFlex` 横向溢出与反直觉横滑，层级关系依然清晰
  - Reworked browsing from an "inline collapsible tree with whole-tree horizontal scroll" to **breadcrumb navigation** (file-manager style): the main list shows only the current level; tapping an item with children drills into its children, and the breadcrumb bar jumps back to any ancestor; tapping a leaf opens a bottom-sheet detail. This removes the `RenderFlex` horizontal overflow and unintuitive panning on deep trees while keeping the hierarchy clear
- Routes 视图交互打磨 / Routes view UX polish
  - 将路由详情从「底部抽屉」改为与 Network 一致的**同面板双屏详情**（列表 ↔ 详情切换）：点击记录进入详情页，工具栏显示 `Back` 返回箭头 + `Route Detail` 标题，大段 Arguments JSON 可完整滚动展示；列表态工具栏保留数量徽章与清空按钮
  - Reworked route detail from a bottom-sheet into a **same-panel list ↔ detail** view matching Network: tapping a record opens the detail page with a `Back` arrow + `Route Detail` title in the toolbar, letting long `Arguments` JSON scroll fully; the list state keeps the count badge and Clear button

## 1.3.4

> **🧹 元数据与文档清理 / Metadata & docs cleanup：** 本版本补充了 `pubspec.yaml` 的 `documentation` 字段，移除了与 `docs/` 完全镜像的遗留 `wiki/` 目录（统一文档单一信息源），并启用了更严格的 `analysis_options.yaml` 规则（已修复因此暴露的 5 处代码问题）。公共 API 不变。
> This release adds the `documentation` field to `pubspec.yaml`, removes the legacy `wiki/` directory (a mirror of `docs/`, now the single source of truth), and enables stricter `analysis_options.yaml` rules (5 latent code issues fixed as a result). Public API unchanged.

- 元数据 / Metadata
  - `pubspec.yaml` 新增 `documentation` 字段，指向 GitHub Pages 文档站，提升 pub.dev 评分
  - Added `documentation` field to `pubspec.yaml` pointing to the GitHub Pages site for a better pub.dev score
- 文档 / Docs
  - 删除与 `docs/` 内容完全重复的遗留 `wiki/` 目录，并清理 `.github/workflows/ci.yml`、`AGENTS.md`、`CONTRIBUTING.md` 中对 `wiki/**` 的残留引用；`docs/` 成为唯一文档源
  - Removed the legacy `wiki/` directory (a duplicate of `docs/`) and cleaned up `wiki/**` references in `ci.yml`, `AGENTS.md`, `CONTRIBUTING.md`; `docs/` is now the single source of truth
- 代码质量 / Code quality
  - `analysis_options.yaml` 启用 13 条安全 lint 规则（如 `prefer_single_quotes`、`unawaited_futures`），并修复 5 处因此触发的 info 级问题，现 `flutter analyze` 零问题
  - `analysis_options.yaml` enables 13 safe lint rules (e.g. `prefer_single_quotes`, `unawaited_futures`); 5 resulting info-level issues fixed, `flutter analyze` is now clean

## 1.3.3

> **🛡️ 网络拦截健壮性 / Network interception robustness：** 本版本加固了网络拦截，避免并发请求 ID 碰撞、大请求体导致 OOM，以及二进制 / 非 UTF-8 响应体解析异常。公共 API 不变。
> This release hardens network interception: cryptographic request-ID uniqueness under concurrent requests, a 512 KB body cap to prevent OOM on large uploads, and safe handling of binary / non-UTF-8 bodies. Public API unchanged.

本版本整合了此前分散的健壮性修复，统一了请求 ID 生成逻辑（微秒时间戳 + `Random.secure` + 自增计数器），并对请求 / 响应体捕获增加上限与编码回退。支持 iOS 的 podspec 同步更新至 `1.3.3`。
This release consolidates previously scattered robustness fixes, unifying request-ID generation (microsecond timestamp + `Random.secure` + monotonic counter) and adding a body cap plus encoding fallback to request/response capture. The iOS podspec is bumped to `1.3.3` in sync.

**修复 / Fixed:**

- 请求 ID 唯一性 / Request-ID uniqueness
  - `InspectorHttpClient` 与 `InspectorDioInterceptor` 的请求 ID 现由「微秒时间戳 + `Random.secure()` 随机数 + 自增计数器」组合生成，杜绝高并发下同一毫秒内产生重复 ID 导致响应数据错配
  - `InspectorHttpClient` and `InspectorDioInterceptor` now build request IDs from a microsecond timestamp plus a `Random.secure()` value plus a monotonic counter, eliminating duplicate IDs under heavy concurrency that could mis-associate response data
- 大请求体 OOM / OOM on large bodies
  - HTTP 拦截器对请求体（`body`）设置 512 KB 上限；超限时仅记录截断提示，避免大文件上传时内存暴涨
  - The HTTP interceptor caps the captured request `body` at 512 KB and records a truncation note beyond it, preventing memory blowups on large uploads
- 二进制 / 非 UTF-8 响应体 / Binary & non-UTF-8 bodies
  - 响应体优先按 UTF-8 解码，失败时对不可解码的字节做转义，避免二进制内容解析抛错
  - Response bodies now decode as UTF-8 first, falling back to escaping undecodable bytes so binary content no longer throws
- 响应大小展示 / Response size display
  - `InspectorResponseProxy` 在 `contentLength == -1`（未知长度）时显示 "unknown size"，不再误显示为 0
  - `InspectorResponseProxy` shows "unknown size" when `contentLength == -1` instead of incorrectly showing 0
- 测试 / Tests
  - 新增 `test/request_id_collision_test.dart`（会话 ID 唯一性、大请求体截断、二进制 / 非 UTF-8 回退）
  - 新增 `test/http_interceptor_test.dart`（请求 / 响应体捕获）
  - `test/models_test.dart` 新增并发请求 ID 唯一性测试组
  - Adds `test/request_id_collision_test.dart` (session-ID uniqueness, large-body truncation, binary / non-UTF-8 fallback), `test/http_interceptor_test.dart` (request/response body capture), and a concurrent request-ID uniqueness group in `test/models_test.dart`

## 1.3.2

> **🐛 缺陷修复 / Bug fix：** 修复网络请求耗时（duration）在响应尚未到达时即被错误计算的问题。
> This release fixes an issue where network request duration was calculated prematurely, before the response had actually arrived.

本版本修复了 HTTP 拦截器在捕获请求体（body）阶段误将请求标记为已完成、导致耗时计算错误的问题，并补充了对应的单元测试。公共 API 不变。
This release fixes a bug where the HTTP interceptor mistakenly marked a request as complete (and computed its duration) during request-body capture, and adds unit tests for it. Public API unchanged.

**修复 / Fixed:**

- 网络请求耗时计算时机 / Network request duration timing
  - `InspectorService.updateNetworkRequest` 现在仅在提供 `statusCode`（即响应到达）时才设置 `responseTime` 与 `duration`；仅更新请求体（body，例如 HTTP 拦截器在 `close()` 中捕获请求体）时保留原值，不再过早标记请求已完成
  - `InspectorService.updateNetworkRequest` now only sets `responseTime` and `duration` when `statusCode` is provided (response arrival). Updating only the request body (e.g. HTTP interceptor capturing the body in `close()`) keeps them unset, so requests are no longer prematurely marked complete
  - 修复后：先捕获请求体、后收到响应的请求，其 `duration` 反映真实的响应耗时而非请求体捕获时刻
  - After the fix: a request whose body is captured first and response arrives later reports `duration` for the real response time, not the body-capture moment
- 单元测试 / Unit tests
  - `test/models_test.dart` 新增 `InspectorService.updateNetworkRequest responseTime` 测试组，覆盖：仅更新 body 不设置 `responseTime`、提供 `statusCode` 设置、先 body 后响应的时序
  - `test/models_test.dart` adds the `InspectorService.updateNetworkRequest responseTime` group covering: body-only update leaves `responseTime` unset, `statusCode` sets it, and the body-then-response sequence

## 1.3.1

> **🛡️ 告警防风暴 / Alert storm protection：** 本版本为告警系统新增同源节流，避免持续超阈值（内存/FPS 轮询）或突发 5xx/慢请求淹没告警缓冲与未读红点。
> This release adds per-source throttling to the alert system so sustained threshold breaches (memory/FPS polling) or bursts of 5xx/slow requests no longer flood the alert buffer and unread badge.

本版本在告警触发路径上新增节流逻辑，并补充了对应的单元测试。公共 API 不变。
This release adds throttling to the alert firing path and ships unit tests for it. Public API unchanged.

**新增 / Added:**

- 告警同源节流 / Per-source alert throttling
  - `AlertService._fire` 新增按 `(source, message)` 的 1 秒滑动窗口节流：同一来源在冷却期内重复触发被去重，避免告警风暴
  - `AlertService._fire` now applies a 1-second sliding-window throttle keyed on `(source, message)`: repeated firings from the same source within the cooldown are deduplicated to prevent alert storms
  - 节流键使用记录类型 `(String, String)`，避免 URL 含 `|` 分隔符时的键冲突
  - The throttle key uses a `(String, String)` record, avoiding key collisions when a URL contains the `|` separator
  - 持续状态仍会周期提醒：冷却结束后（≥1 秒）同源再次出现仍会正常触发，保证持续问题不会被永久压制
  - Sustained conditions still re-alert periodically: after the cooldown elapses (≥1s) a same-source occurrence fires again, so persistent issues are never permanently suppressed
  - `clearAll()` 同时清理节流表，与告警缓冲保持一致的生命周期
  - `clearAll()` also clears the throttle table, keeping its lifecycle consistent with the alert buffer
- 单元测试 / Unit tests
  - 新增 `test/alert_service_test.dart`，覆盖节流去重、防风暴、规则评估（网络/日志/内存/FPS）、`clearAll` 生命周期与默认规则
  - Added `test/alert_service_test.dart` covering throttle deduplication, storm prevention, rule evaluation (network/log/memory/FPS), `clearAll` lifecycle, and default rules

## 1.3.0

> **🚀 新功能 / New features：** 本版本为网络面板新增批量操作与敏感字段遮蔽导出，并引入告警系统与悬浮球未读红点；同时对 HTTP 拦截器做了纯内部重构（行为不变）。
> This release adds batch operations and sensitive-field masking export to the network panel, introduces an alert system with an unread badge on the floating button, and refactors the HTTP interceptor internally (no behavior change).

本版本在网络调试与告警能力上有较多增强，且保持公共 API 与拦截行为不变。
This release adds substantial network-debugging and alerting enhancements while keeping the public API and interception behavior unchanged.

**新增 / Added:**

- 网络面板批量操作 / Network panel batch operations
  - 列表支持批量选择模式，可批量复制 cURL（Copy as cURL）与批量删除请求
  - The list supports a selection mode for batch "Copy as cURL" and batch deletion
- 敏感字段遮蔽导出 / Sensitive-field masking on export
  - 工具栏新增眼睛图标开关（默认关闭，即完整可见）；开启后 `toCurl` / `netToJson` / `netToHar` / `copyNet` / `exportNetToFile` 自动遮蔽 `Authorization`、`Cookie`、`Set-Cookie`、`Proxy-Authorization`、`X-Auth-Token`、`X-CSRF-Token`、`X-XSRF-Token` 等请求头
  - New eye toggle in the toolbar (off by default, i.e. fully visible); when on, `toCurl`/`netToJson`/`netToHar`/`copyNet`/`exportNetToFile` mask `Authorization`, `Cookie`, `Set-Cookie`, `Proxy-Authorization`, `X-Auth-Token`, `X-CSRF-Token`, `X-XSRF-Token`, etc.
  - 详情页「Copy as cURL」「Copy as JSON」跟随该开关，snackbar 在遮蔽时提示 `(sensitive hidden)`
  - Detail-page "Copy as cURL"/"Copy as JSON" follow the toggle; the snackbar notes `(sensitive hidden)` when masking is active
- 告警系统 / Alert system
  - 新增 `AlertRule` 模型与 `AlertService`，可基于网络请求、日志、内存、FPS 触发条件评估告警
  - Added `AlertRule` model and `AlertService` that evaluate alert conditions on network requests, logs, memory, and FPS
  - 新增 Alerts 标签页，悬浮球显示未读告警数红点（点击面板即清零）
  - New Alerts tab; the floating button shows an unread-count badge (cleared when the panel is opened)
- cURL 复制 / cURL copy
  - `ExportService.toCurl` 支持一键复制请求为 cURL 命令，便于在终端复现
  - `ExportService.toCurl` copies a request as a cURL command for terminal reproduction
- HTTP 拦截器重构 / HTTP interceptor refactor
  - `http_interceptor.dart` 拆分为 `part` 文件（`inspector_http_client.dart`、`inspector_response_proxy.dart`），纯物理拆分，行为不变
  - `http_interceptor.dart` split into `part` files (`inspector_http_client.dart`, `inspector_response_proxy.dart`); pure physical split, no behavior change

## 1.2.2

> **🔔 推荐升级 / Upgrade recommended：** 本版本修复了拦截器的若干健壮性问题（大响应体 OOM、第三方错误上报被覆盖、并发同 URL 请求错乱），并修复了 example 依赖无法解析的问题。
> This release fixes several interceptor robustness issues (large-response OOM, overwritten third-party error reporting, concurrent same-URL request mis-association) and an unresolvable example dependency.

本版本提升了拦截器在与网络请求、错误捕获交互时的健壮性，并修正了 example 工程的可解析性。
This release improves interceptor robustness for network requests and error capture, and fixes the example project's resolvability.

**修复 / Bug Fixes:**

- 拦截器健壮性修复 / Interceptor robustness fixes
  - HTTP 拦截器：捕获的响应体上限设为 512KB，避免下载大文件时内存溢出（OOM）
  - HTTP interceptor: cap captured response body at 512KB to avoid OOM on large downloads
  - 日志拦截器：保留并恢复原始的 `FlutterError.onError`，不再覆盖 Crashlytics / Sentry 等第三方错误上报
  - Log interceptor: preserve and restore the original `FlutterError.onError` so third-party reporters (Crashlytics/Sentry) are no longer overwritten
  - Dio 拦截器：响应/错误匹配优先使用 `x-inspector-request-id`，回退到 URL，避免并发同 URL 请求错乱配对
  - Dio interceptor: match responses/errors by `x-inspector-request-id` first, falling back to URL, to avoid mis-associating concurrent same-URL requests
- 构建修复 / Build fix
  - example 的 `dio` 依赖由不存在的 `5.11.0` 固定为 `5.4.0`，修复 `flutter pub get` 解析失败
  - Pinned example `dio` from the non-existent `5.11.0` to `5.4.0`, fixing `flutter pub get` resolution failure

## 1.2.1

> **🔔 推荐升级 / Upgrade recommended：** 本版本修复了 FPS 计算的根本性准确度问题（时间戳错误、漏判 GPU 卡顿），所有使用 FPS 监控功能的用户建议升级到最新版本。
> This release fixes fundamental FPS accuracy issues (incorrect timestamps, missing GPU jank detection). All users using the FPS monitor feature are advised to upgrade to the latest version.

本版本修复了 FPS 计算的两个根本性准确度问题，并修复了引入真实时间戳后的回归 bug。
This release fixes two fundamental FPS accuracy issues and a regression introduced by switching to real frame timestamps.

**修复 / Bug Fixes:**

- 修复 FPS 计算的两个根本性准确度问题
  - Fixed two fundamental accuracy issues in FPS calculation
  - **问题 1**：帧时间戳使用 `DateTime.now()` 而非帧真实时间戳。由于 `addTimingsCallback` 是批量回调，同一批多帧会共享几乎相同的时间戳，导致滑动窗口 FPS 计算在窗口边缘抖动、批量到达时失真
  - **Issue 1**: Frame timestamps used `DateTime.now()` instead of real frame timestamps. Since `addTimingsCallback` is batched, multiple frames in the same batch shared nearly identical timestamps, causing sliding-window FPS to jitter at window edges and distort on batch arrivals
  - **修复 1**：改用 `timing.timestampInMicroseconds(FramePhase.buildStart)` 获取每帧真实开始时间戳
  - **Fix 1**: Use `timing.timestampInMicroseconds(FramePhase.buildStart)` to get the real per-frame start timestamp
  - **问题 2**：帧耗时只算 `buildDuration`（widget 树构建），漏掉了 `rasterizationDuration`（GPU 光栅化）。GPU 卡顿是 Flutter 最常见的卡顿类型之一，原实现完全检测不到
  - **Issue 2**: Frame duration only counted `buildDuration` (widget tree construction), missing `rasterizationDuration` (GPU rasterization). GPU jank — one of the most common Flutter jank types — was completely undetected
  - **修复 2**：帧耗时改用 `rasterFinish - buildStart`，包含 build 和 raster 全过程
  - **Fix 2**: Frame duration now uses `rasterFinish - buildStart`, covering both build and raster phases
- 修复引入真实时间戳后 FPS 显示 `--` 的回归问题
  - Fixed regression where FPS displayed `--` after switching to real frame timestamps
  - **根因**：`_refreshFps()` 用 `DateTime.now()`（wall clock，自 1970 UTC）作为 "now" 来清理旧时间戳，而帧时间戳用的是 `FramePhase.buildStart`（monotonic time，自引擎启动）。两者时钟基准不同，差值巨大，导致所有帧时间戳在第一次刷新时被全部误清理，FPS 永远为 0
  - **Root cause**: `_refreshFps()` used `DateTime.now()` (wall clock, since 1970 UTC) as "now" to purge old timestamps, but frame timestamps used `FramePhase.buildStart` (monotonic time, since engine start). Different clock bases caused all timestamps to be erroneously purged on first refresh, making FPS always 0
  - **修复**：用帧时间戳中的最大值作为 "now"，确保时钟基准统一
  - **Fix**: Use the max frame timestamp as "now" to ensure a unified clock base
- 移除未使用的 `_frameStartTimes` 字段（死代码清理）
  - Removed unused `_frameStartTimes` field (dead code cleanup)

## 1.2.0

本版本修复了悬浮按钮和检查器面板的根本性稳定性问题，并新增 FPS 监控演示。
This release fixes fundamental stability issues with the floating button and inspector panel, and adds FPS monitoring demos.

**修复 / Bug Fixes:**

- 修复悬浮按钮从未通过 Overlay 正常显示的问题
  - Fixed issue where the floating button was never properly displayed via Overlay
  - **根因**：原实现使用 `Overlay.of(context, rootOverlay: true)` 查找 Overlay，但 `Overlay` 是 `Navigator` 的子组件而非祖先，导致查找结果为 `null`，按钮 OverlayEntry 从未被创建
  - **Root cause**: Original implementation used `Overlay.of(context, rootOverlay: true)` to find Overlay, but Overlay is a child of Navigator, not an ancestor, returning `null` and the button OverlayEntry was never created
  - **修复**：改用 `navigatorState.overlay` 直接从 Navigator 获取其内部 Overlay，并加入下一帧重试机制应对 Navigator 未挂载的情况
  - **Fix**: Use `navigatorState.overlay` to get Overlay directly from Navigator, with next-frame retry when Navigator is not mounted
- 修复开启 FPS 监控后悬浮按钮消失、面板无法展开的问题
  - Fixed issue where enabling FPS monitoring caused the floating button to disappear and the panel could not expand
  - **根因**：`FpsService.notifyListeners()` 会触发 Overlay 重建，叠加原 Overlay 查找失败，导致按钮 State 被销毁且无法恢复
  - **Root cause**: `FpsService.notifyListeners()` triggers Overlay rebuild; combined with the original Overlay lookup failure, the button State was destroyed and could not recover
- 修复 OverlayEntry 内容报 "No Material widget found" 的问题
  - Fixed "No Material widget found" error in OverlayEntry content
  - 面板 OverlayEntry 内部的 `TabBar`、`IconButton`、`InkWell` 等 Material 组件因 OverlayEntry 不在 MaterialApp widget 树中而无法找到 Material 祖先
  - Material widgets (TabBar, IconButton, InkWell) inside the panel OverlayEntry could not find a Material ancestor because OverlayEntry content is outside MaterialApp's widget tree
  - **修复**：在面板 OverlayEntry 内部（`Offstage` 内部）包裹 `Material(color: Colors.transparent)` 作为祖先
  - **Fix**: Wrap `Material(color: Colors.transparent)` inside `Offstage` to provide the Material ancestor
- 修复 OverlayEntry 的 Material 包裹导致下方页面无法点击/滑动的问题
  - Fixed issue where Material wrapper in OverlayEntry made the underlying page unclickable/unscrollable
  - **根因**：`RenderMaterial` 只要设置了 color（即使 `Colors.transparent`）就会在 `hitTestSelf` 返回 `true`，拦截所有触摸事件
  - **Root cause**: `RenderMaterial` with any color (even `Colors.transparent`) returns `true` in `hitTestSelf`, intercepting all touch events
  - **修复 1**：按钮 OverlayEntry 不再包裹 Material（`FloatingInspectorButton` 内部无 InkWell/InkResponse，不需要 Material 祖先）
  - **Fix 1**: Button OverlayEntry no longer wraps Material (FloatingInspectorButton has no InkWell/InkResponse, no Material ancestor needed)
  - **修复 2**：面板 OverlayEntry 中将 `Material` 放在 `Offstage` **内部**，关闭面板时 `RenderOffstage.hitTest` 直接返回 `false`，Material 不参与命中测试，点击穿透到下方页面
  - **Fix 2**: In panel OverlayEntry, `Material` is placed **inside** `Offstage`; when the panel is closed, `RenderOffstage.hitTest` returns `false` directly, so Material never participates in hit testing and clicks pass through to the underlying page
- 修复 FPS Tab 切换后内容消失的问题
  - Fixed issue where FPS Tab content disappeared after switching tabs
  - 使用 `IndexedStack` 替代 `TabBarView`，并为每个 viewer 添加 `ValueKey` 确保状态保持
  - Use `IndexedStack` instead of `TabBarView`, and add `ValueKey` to each viewer to ensure state preservation
- 修复 `AutomaticKeepAliveClientMixin` 与 `IndexedStack` 冲突导致状态销毁的问题
  - Fixed state destruction caused by conflict between `AutomaticKeepAliveClientMixin` and `IndexedStack`
  - 移除所有 viewer（network/log/database/memory/fps/route）中的 `AutomaticKeepAliveClientMixin`
  - Remove `AutomaticKeepAliveClientMixin` from all viewers (network/log/database/memory/fps/route)
- 修复 FPS 计算严重偏低的问题（实际 60 FPS 仅显示 9-10）
  - Fixed severely undercounted FPS (real 60 FPS showed only 9-10)
  - **根因**：`_onFrameTimings` 中 `_recentFrameTimestamps.add(now)` 在 for 循环外，而 Flutter 引擎的 `addTimingsCallback` 是**批量回调**，一次可能返回多帧，但代码每批只记录 1 个时间戳，导致 FPS 计算偏低 6-10 倍
  - **Root cause**: `_recentFrameTimestamps.add(now)` was outside the for-loop in `_onFrameTimings`; Flutter engine's `addTimingsCallback` is **batched** (may return multiple frames per call), but only one timestamp was added per batch, undercounting FPS by 6-10x
  - **修复**：将 `_recentFrameTimestamps.add` 移入 for 循环内，使用 `timing.timestamp.inMicroseconds` 为每帧单独记录时间戳
  - **Fix**: Move `_recentFrameTimestamps.add` inside the for-loop, using `timing.timestamp.inMicroseconds` to record a timestamp per frame

**新功能 / New Features:**

- 悬浮按钮新增边缘吸附收入功能
  - Floating button now auto-docks and tucks into screen edge
  - 拖动松手后自动吸附到最近边缘，平滑动画"收入"边缘仅露出 24px 小弧边
  - Auto-docks to nearest edge on release with smooth animation; tucks into edge leaving only a 24px peek
  - 收入状态下点击露出部分会平滑拉出到完整可见位置（不打开面板，避免误触），再次点击才打开面板
  - Tapping the peek smoothly pulls it out to fully visible (panel not opened, avoids accidental open); tap again to open the panel
  - 此设计避免了从吸附态拖出时与系统返回手势（Android/iOS 边缘右滑退出）的冲突
  - This design avoids conflict with system back gestures (Android/iOS edge swipe to go back) when pulling out from docked state
  - 收入时图标变为方向箭头（左吸附→右箭头，右吸附→左箭头），提示可点击拉出
  - Icon changes to directional chevron when tucked (left dock → right chevron, right dock → left chevron) hinting at tap-to-pull-out
  - 非吸附状态保持虫子图标，点击直接打开面板
  - Bug icon preserved when not docked; tap directly opens the panel
- Example App 新增 FPS 演示模块
  - Example App adds FPS demo module
  - Trigger Jank 按钮（阻塞主线程 100-500ms 模拟掉帧）
  - Trigger Jank button (blocks main thread 100-500ms to simulate jank)
  - Heavy Animations 演示（80 个同时旋转+缩放的 widget 故意触发掉帧）
  - Heavy Animations demo (80 simultaneously rotating+scaling widgets to intentionally trigger jank)
  - Smooth Animation 演示（单个轻量复合动画，演示稳定 60 FPS）
  - Smooth Animation demo (single lightweight compound animation, demonstrates stable 60 FPS)

## 1.1.2

**优化 / Improvements:**

- 简化内存泄漏检测 UI 文案，移除代码示例，仅保留使用提醒
  - Simplified memory leak detection UI instructions by removing code demo and keeping only usage reminders
- 过滤网络请求列表中的 WebSocket 握手请求（如 VM Service `/ws` 端点），避免连接重试时刷屏
  - Filtered WebSocket handshake requests (e.g. VM Service `/ws` endpoints) from the network request list to prevent flooding during connection retries
- 优化内存趋势图：新增 X 轴（时间轴 -2m/-1m/Now）和 Y 轴（内存值 Max/Mid/Min）刻度标签，新增 Min 最小值图例，让趋势变化更清晰直观
  - Optimized memory trend chart: added X-axis (time axis -2m/-1m/Now) and Y-axis (memory value Max/Mid/Min) tick labels, added Min value legend, making trend changes clearer and more intuitive
- 新增简化的日志记录 API：`InspectorLog` 静态类，支持 `InspectorLog.v/d/i/w/e()` 短名方法调用
  - Added simplified logging API: `InspectorLog` static class, supporting `InspectorLog.v/d/i/w/e()` short-name method calls
- 新增简化的内存泄漏追踪 API：`trackMemoryLeak` / `untrackMemoryLeak` 顶层函数和 `Object.trackMemoryLeak()` 扩展方法
  - Added simplified memory leak tracking API: `trackMemoryLeak` / `untrackMemoryLeak` top-level functions and `Object.trackMemoryLeak()` extension method
- 补充单元测试覆盖新 API，总测试数达到 112 条
  - Added unit tests covering the new API, total tests reached 112

## 1.1.1

**修复 / Bug Fixes:**

- 修复 Flutter 3.31+ 中 `activeColor` 属性废弃导致的静态分析警告
  - Fix static analysis warning caused by deprecated `activeColor` property in Flutter 3.31+
  - Switch 组件：`activeColor` → `activeThumbColor`
    - Switch widget: `activeColor` → `activeThumbColor`
  - Checkbox 组件：`activeColor` → `fillColor` + `WidgetStateProperty.resolveWith`
    - Checkbox widget: `activeColor` → `fillColor` + `WidgetStateProperty.resolveWith`

## 1.1.0

**新功能 / New Features:**

- 新增内存监控面板（Memory Viewer），提供全面的内存分析能力
  - Added memory monitoring panel (Memory Viewer) with comprehensive memory analysis capabilities
- 新增内存趋势图（折线图，可切换 RSS / Heap / New / Old 四种指标，2 分钟历史窗口）
  - Added memory trend chart (line chart, switchable between RSS / Heap / New / Old metrics, 2-minute history window)
- 新增 Dart Heap 概览卡片：Usage / Capacity / External 三个核心指标 + 进度条
  - Added Dart Heap overview card: Usage / Capacity / External three core metrics + progress bar
- 新增新生代/老生代详细内存数据卡片
  - Added new/old space detailed memory data card
- 新增手动触发 GC 功能（VM Service 可用时）
  - Added manual GC trigger feature (when VM Service is available)
- 新增历史快照清理功能
  - Added history snapshot clear feature
- 新增 Native 内存采集（Android Debug.MemoryInfo + iOS mach task_info），真机 100% 可用
  - Added Native memory collection (Android Debug.MemoryInfo + iOS mach task_info), 100% available on real devices
  - Android: Total PSS / Dalvik PSS / Native PSS / Native Private Dirty
  - iOS: Physical Footprint / Compressed / Internal / Device Memory
- 新增内存泄漏检测功能（基于 Dart 2.17+ WeakReference）
  - Added memory leak detection feature (based on Dart 2.17+ WeakReference)
  - 四状态流转：tracking → verifying → leaked / released
    - Four-state transition: tracking → verifying → leaked / released
  - 超过预期释放时间自动触发 GC 验证（VM Service 可用时）
    - Auto-trigger GC verification after exceeding expected release time (when VM Service available)
  - 提供 `trackObject()` / `untrackObject()` / `clearLeakRecords()` 三个公开 API
    - Provides three public APIs: `trackObject()` / `untrackObject()` / `clearLeakRecords()`
- 新增内存监控总开关（UI 顶部 Switch），关闭时停止所有定时器和 VM Service 连接，避免性能开销
  - Added memory monitoring master switch (top Switch in UI), stops all timers and VM Service connection when off, avoiding performance overhead
- 图片缓存监控：实时显示缓存大小、数量、加载中/使用中状态
  - Image cache monitoring: real-time display of cache size, count, pending/live status
- 图片缓存清理：一键清除所有图片缓存
  - Image cache cleanup: one-click clear all image cache
- 应用存储统计：文档目录、临时缓存、数据库文件大小统计
  - App storage stats: documents directory, temp cache, database file size statistics
- 应用缓存清理：一键清除应用临时缓存
  - App cache cleanup: one-click clear app temp cache

**改进 / Improvements:**

- VM Service 连接采用 HTTP + WebSocket 双模式自动降级
  - VM Service connection uses HTTP + WebSocket dual-mode automatic fallback
- VM Service 连接增加 500ms 初始延迟 + 最多 5 次重试（1 秒间隔）
  - VM Service connection adds 500ms initial delay + up to 5 retries (1-second interval)
- VM Service 不可用时 UI 优雅降级显示 N/A 占位
  - UI gracefully degrades to show N/A placeholder when VM Service is unavailable
- 历史快照数量为 240 条（500ms × 240 = 2 分钟历史窗口）
  - Historical snapshot count is 240 (500ms × 240 = 2-minute history window)
- 泄漏检测每 2 秒检查一次追踪对象状态，上限 500 条记录
  - Leak detection checks tracked object status every 2 seconds, up to 500 records

**修复 / Bug Fixes:**

- 修复 SQLite 警告：将 SQL 语句中的双引号字符串改为单引号
  - Fix SQLite warning: change double-quoted strings to single quotes in SQL statements
- 修复 TabBar 在小屏幕设备上的溢出问题，支持自适应滚动
  - Fix TabBar overflow on small screen devices, support adaptive scrolling

**重要说明 / Important Notes:**

- **Dart VM Heap 数据在通过 PC 调试时可能不可用**
  - **Dart VM Heap data may be unavailable when debugging via PC**
- **原因**：使用 `flutter run` 连接 PC 调试时，flutter tool 会通过 `adb reverse` 在 PC 和设备之间做端口转发，让 PC 上的 DevTools 能访问设备的 VM Service。但应用进程内部 `Service.getInfo()` 返回的 `serverUri` 是 PC 视角的端口，应用进程访问 `127.0.0.1:PC端口` 时设备本地并没有监听该端口，导致 Connection refused，VM Service 显示 OFF
  - **Reason**: When debugging via PC with `flutter run`, flutter tool sets up port forwarding between PC and device via `adb reverse`, allowing PC-side DevTools to access device's VM Service. However, `Service.getInfo()` returns a `serverUri` from PC's perspective; when the app process accesses `127.0.0.1:PC_port`, the device doesn't have that port listening locally, resulting in Connection refused and VM Service showing OFF
- **不影响实际使用**：不连接 PC 直接打开 debug 应用时，没有 flutter tool 介入，VM Service 直接监听设备本地端口，应用能正常连接，Dart Heap 数据正常显示
  - **Does not affect actual usage**: When opening debug app without PC connection, no flutter tool is involved, VM Service listens directly on device's local port, app can connect normally, Dart Heap data displays correctly
- **降级方案**：VM Service 不可用时，Native 内存（Android PSS / iOS physicalFootprint）仍然正常显示；进程 RSS 始终可用
  - **Fallback**: When VM Service is unavailable, Native memory (Android PSS / iOS physicalFootprint) still displays normally; process RSS is always available

## 1.0.8

**修复 / Bug Fixes:**

- 网络请求拦截修改功能：响应体和响应状态码改为只读，不允许修改
  - Network request interceptor: response body and response status code are now read-only and cannot be modified
- 修复拦截规则编辑面板中 Response 部分输入框可编辑的问题
  - Fix issue where Response section input fields in interceptor rule editor were editable
- 拦截功能现在仅支持修改请求体和请求头
  - Interceptor now only supports modifying request body and request headers

## 1.0.7

**新功能 / New Features:**

- 网络请求拦截修改功能：支持拦截请求并修改请求参数
  - Network request interceptor: support intercepting requests and modifying request parameters
- 支持基于 URL + HTTP Method 的规则匹配（精确匹配和正则匹配）
  - Support URL + HTTP Method based rule matching (exact match and regex match)
- 支持修改请求体和请求头
  - Support modifying request body and request headers
- 网络面板新增拦截规则编辑器，可创建/编辑/启用/禁用/删除规则
  - Network panel adds interceptor rule editor, can create/edit/enable/disable/delete rules
- 请求列表显示拦截规则状态标识
  - Request list displays interceptor rule status indicator

## 1.0.6

**新功能 / New Features:**

- 三大查看器新增模糊搜索功能（网络、日志、数据库）
  - Fuzzy search added to all three viewers (Network, Log, Database)
- 网络请求详情改为面板内导航，带返回按钮
  - Network request detail changed to in-panel navigation with back button
- 数据库查看器重构为双层导航：全局数据库列表 + 数据库内详情
  - Database viewer refactored to two-level navigation: global database list + in-database detail
- 数据库内搜索支持搜索表名和表数据内容（所有列）
  - In-database search supports searching table names and table data content (all columns)

**文档更新 / Documentation Updates:**

- 更新 README，添加官方网站链接
  - Updated README to add official website link
- 更新 README，新增搜索功能和数据库双层导航说明
  - Updated README with search feature and database two-level navigation descriptions

## 1.0.5

**改进 / Improvements:**

- UI 全面美化：现代渐变设计、深色主题、图标增强
  - Comprehensive UI redesign: modern gradient design, dark theme, enhanced icons
- 移除标签页红色计数气泡，改用工具栏紫色胶囊徽章
  - Removed red count badges on tabs, replaced with purple pill badges in toolbar
- 悬浮按钮添加呼吸动画，展开时淡出缩小过渡
  - Floating button adds breathing animation, fade-out scale transition on expand
- 悬浮按钮遮罩改为全透明
  - Floating button overlay changed to fully transparent
- 新增主题配置文件，集中管理所有颜色、渐变和尺寸
  - Added theme configuration file for centralized management of all colors, gradients, and dimensions
- 日志过滤选项改为简写（V/D/I/W/E）
  - Log filter options changed to abbreviations (V/D/I/W/E)

## 1.0.4

**改进 / Improvements:**

- Dio 请求支持零侵入自动捕获（通过 HttpOverrides，无需手动添加拦截器）
  - Dio requests support zero-invasion auto-capture via HttpOverrides, no manual interceptor setup needed

**文档更新 / Documentation Updates:**

- 更新 README，说明 Dio 请求无需额外配置，通过 HttpOverrides 自动捕获（真正零侵入）
  - Updated README to clarify Dio requests require no extra configuration, auto-captured via HttpOverrides (true zero-invasion)
- 更新 README，添加 GitHub 仓库链接
  - Updated README to add GitHub repository link
- 更新示例 app，移除 Dio 手动拦截器配置代码
  - Updated example app to remove Dio manual interceptor configuration code

## 1.0.3

**改进 / Improvements:**

- 更新 SDK 约束为范围版本，支持 Dart 3.11.x 和 3.12.x
  - Updated SDK constraint to range version, supporting Dart 3.11.x and 3.12.x
- 为所有源码文件添加中英双语注释，提高代码可读性和国际化支持
  - Added Chinese-English bilingual comments to all source files, improving code readability and international support
- 更新 iOS podspec 配置（版本号、描述、作者信息）
  - Updated iOS podspec configuration (version, description, author info)

**文档更新 / Documentation Updates:**

- 更新 README 说明零侵入范围：http 包用户真正零侵入，Dio 用户需要额外配置拦截器
  - Updated README to clarify zero-invasion scope: true zero-invasion for http package users, Dio users need additional interceptor configuration
- 更新 README 说明第三方日志库集成是自动的，无需任何配置
  - Updated README to clarify third-party log library integration is automatic, no configuration needed
- 更新 README 明确区分可选功能和自动功能
  - Updated README to clearly distinguish optional features from automatic features

## 1.0.2

**文档更新 / Documentation Updates:**

- 更新 README 安装方式，将 pub.dev 作为推荐方式
  - Updated README installation section, making pub.dev the recommended method

## 1.0.1

**新增功能 / New Features:**

- 新增 `ZeroInspectorKit.runAppWithInspector()` 方法，支持一行代码集成
  - Added `ZeroInspectorKit.runAppWithInspector()` method for one-line integration
- 通过 Zone 捕获所有 `print()` 调用，无需修改现有代码
  - Capture all `print()` calls via Zone without modifying existing code
- HTTP 包请求自动拦截（通过 HttpOverrides），无需手动调用
  - Auto-intercept HTTP package requests via HttpOverrides, no manual calls needed

**改进 / Improvements:**

- 第三方日志库日志统一归类到 INFO 级别
  - Third-party log library logs are categorized as INFO level
- 为所有源码文件添加中文注释
  - Added Chinese comments to all source files

**修复 / Bug Fixes:**

- 修复 overlay 相关报错（重复添加、生命周期安全）
  - Fixed overlay related errors (duplicate addition, lifecycle safety)
- 修复 `InspectorLogInterceptorCallback` 未定义错误
  - Fixed undefined `InspectorLogInterceptorCallback` error
- 移除不存在的 `network_interceptor.dart` 导出
  - Removed non-existent `network_interceptor.dart` export

## 1.0.0

**初始版本 / Initial Release:**

- 网络请求查看，支持 Dio 和 http 拦截器
  - Network request viewing with Dio and http interceptor support
- 自动捕获 print() 输出和 Flutter 错误
  - Auto-capture print() output and Flutter errors
- 第三方日志库集成支持
  - Third-party log library integration support
- SQLite 数据库检查（支持 .db 和 .sqlite 文件）
  - SQLite database inspection (.db and .sqlite files)
- 路由追踪（Navigator observer）
  - Route tracking with Navigator observer
- 生产环境自动禁用（kReleaseMode）
  - Production build auto-disable (kReleaseMode)
- 可拖动的悬浮检查器按钮
  - Floating inspector button with drag support
- 透明覆盖层背景
  - Transparent overlay background
- 数据库查看器带返回导航按钮
  - Database viewer with back navigation button
- 支持 ANSI 颜色代码的日志级别检测
  - Log level detection with ANSI color code support

