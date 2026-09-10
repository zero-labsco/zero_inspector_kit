# TODO / 待办事项

> 本文件记录 `zero_inspector_kit` 的中长期工程待办与已规划但尚未动工的大型功能。
> 短期、已排期进入具体版本的功能见各版本 `CHANGELOG.md`。
> This file tracks the long-term engineering backlog and planned-but-not-started
> large features. Short-term, version-bound work lives in `CHANGELOG.md`.

## 已规划 · 大型工程待办 / Planned · Large Engineering Backlog

### 网络 / Network
- [ ] **拦截规则增强**：正则匹配、按域/路径前缀分组、命中计数与最近命中时间、规则导入导出（`InterceptorRule` 序列化）。
- [ ] **请求/响应差异对比**：同 URL 两次请求体的 diff 视图，定位接口字段漂移。
- [ ] **重放历史**：已重放的请求与响应归档，支持"再次重放同一份响应"。
- [ ] **WebSocket 流量统计**：按连接聚合收/发字节、帧数、吞吐曲线。

### 日志 / Logs
- [ ] **日志级别实时过滤开关**：面板内按 V/D/I/W/E 即时筛选，替代仅 tag 过滤。
- [ ] **日志导出裁剪**：按时间区间 / 级别 / tag 组合导出，避免导出整库。
- [ ] **结构化日志（jsonLog）解析**：自动展开 JSON 字段，可折叠树形查看。

### 内存 / Memory
- [ ] **图片内存详细信息**：`Image` / `ImageProvider` 尺寸、解码后字节、缓存命中，定位内存大户。
- [ ] **内存历史窗口可配置**：保留时长 / 采样间隔作为 `init` 参数暴露（当前硬编码）。
- [ ] **泄漏对象引用链**：结合 `FlutterMemoryAllocations` 给出从根到泄漏对象的保留路径。

### 性能 / FPS
- [ ] **分阶段耗时下钻**：build/layout/paint/raster 四段分别计时（当前仅 build/raster 两段），定位具体卡顿阶段。
- [ ] **帧耗时火焰图**：连续帧的 build/raster 耗时叠加，识别周期性尖刺。
- [ ] **着色器编译卡顿标记**：首次构建帧标记为 warm-up，不计入稳态 jank。

### 错误 / Errors
- [ ] **崩溃会话快照**：捕获未处理异常时自动导出最近 N 条日志 + 网络 + 内存快照为单文件。
- [ ] **错误去重智能合并**：跨重启按堆栈签名合并，长期累计历史出现次数。
- [ ] **自定义上报钩子**：`onErrorReport` 回调，接入 Sentry / Firebase Crashlytics。

### 路由 / Routes
- [ ] **路由观察者单元测试补充**：覆盖嵌套 Navigator、命名路由、Dialog/Overlay 场景。
- [ ] **路由耗时**：页面 `initState` → `build` → 首帧 的端到端耗时统计。

### 持久化 / Persistence
- [ ] **导出格式增强**：cURL/HAR 已支持，补充 OpenAPI 推断与 `har2postman`。
- [ ] **磁盘配额**：持久化按字节上限裁剪（当前仅行数 + 保留时长）。
- [ ] **Web / 桌面后端**：`PersistenceService` 在桌面/Web 用 `sqlite3` / `indexed_db` 后端替代 sqflite。

### 工程化 / Engineering
- [ ] **悬浮按钮位置持久化**：保存并恢复拖拽位置，需引入轻量持久化（评估是否值得引入依赖）。
- [ ] **自动化截屏回归**：`test/` 下补充 `golden` 测试，覆盖九大查看器标签页。
- [ ] **pub.dev 评分专项**：补全 API 文档覆盖率、示例工程 `example/`，目标 pana 140/140。
- [ ] **CI 矩阵**：扩展 `ci.yml` 在 stable + beta 双 Flutter 版本上跑 analyze/test。

## 已完成功能 / Completed Features

- **Dart VM Heap 内存监控** — HTTP 轮询连接 VM Service + `ProcessInfo.currentRss` 降级；趋势图、新生代/老生代、手动 GC、历史清理。
- **内存泄漏检测** — `WeakReference` 弱引用 + 四状态机（tracking → verifying → leaked/released），自动 GC 验证。
- **FPS / 帧率监控** — `addTimingsCallback` 采集帧数据，实时 FPS + 掉帧预警；单帧 build/raster 分项耗时 + 自适应刷新率阈值。
- **数据导出与分享** — 日志/网络导出 JSON/文本/CSV/HAR/cURL；剪贴板复制；`share_plus` 系统分享 + 敏感头遮蔽。
- **内存查看器** — 趋势图触摸交互（十字准线、拖动手跟手浏览、自适应 Y 轴）。
- **网络查看器** — Timeline 瀑布图、按 Method/状态码/拦截状态三维筛选；可编辑重放编辑器（仅查询参数可改，URL/Header/Body 只读）。
- **日志查看器增强** — 自动滚动（可暂停）、正则搜索、按 tag 过滤、单条复制、主视图内详情页。
- **SharedPreferences 查看器** — 以自定义 DB 源并入 Database 体系，抽象 `SharedPrefsLike` 不依赖 `shared_preferences`。
- **Widget 检查器** — 渲染树一次性快照 + 面包屑导航浏览。
- **路由追踪穿透包装** — 构建期穿过中间壳 Widget 注入 `navigatorObservers`，兼容非直接 `MaterialApp`。
- **异常聚合（Errors Tab）** — 接管 `FlutterError.onError` 与 `PlatformDispatcher.onError`，按类型+堆栈签名去重。
- **告警服务** — 命中规则入队、未读红点、节流防风暴、磁盘环形缓冲持久化（跨重启回放）。
- **持久化环形缓冲** — 日志/网络/异常/告警异步落盘到 SQLite，按行数 + 保留时长滚动裁剪，会话存档导出。
- **`ZeroInspectorKit.dispose()`** — 完整释放进程级资源，支持运行时彻底停采。
