# Changelog

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
