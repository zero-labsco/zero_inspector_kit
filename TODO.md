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
