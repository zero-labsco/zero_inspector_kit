# Changelog

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

