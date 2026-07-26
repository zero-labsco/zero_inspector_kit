# Changelog

## 1.0.9

**新功能 / New Features:**

- 新增内存监控面板（Memory Viewer）
  - Added memory monitoring panel (Memory Viewer)
- 图片缓存监控：实时显示缓存大小、数量、加载中/使用中状态
  - Image cache monitoring: real-time display of cache size, count, pending/live status
- 图片缓存清理：一键清除所有图片缓存
  - Image cache cleanup: one-click clear all image cache
- 应用存储统计：文档目录、临时缓存、数据库文件大小统计
  - App storage stats: documents directory, temp cache, database file size statistics
- 应用缓存清理：一键清除应用临时缓存
  - App cache cleanup: one-click clear app temp cache

**修复 / Bug Fixes:**

- 修复 SQLite 警告：将 SQL 语句中的双引号字符串改为单引号
  - Fix SQLite warning: change double-quoted strings to single quotes in SQL statements
- 修复 TabBar 在小屏幕设备上的溢出问题，支持自适应滚动
  - Fix TabBar overflow on small screen devices, support adaptive scrolling

**说明 / Notes:**

- Dart VM Heap 内存监控和趋势图功能暂时移除（Android 真机上 VM Service 连接问题），将在后续版本恢复
  - Dart VM Heap memory monitoring and trend chart features are temporarily removed (VM Service connection issue on Android real devices), will be restored in future versions

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

