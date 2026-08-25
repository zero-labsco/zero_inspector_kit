# TODO / 待办事项

> 历史待办已清理（2026-08-26）：剩余未完成项（悬浮按钮位置持久化、内存历史窗口可配置、拦截规则增强、iOS VM Service 研究、图片内存详细信息、路由观察者单元测试补充）经评估暂不推进——其中悬浮按钮持久化需引入额外持久化依赖，与其余项一同暂缓。以下仅保留已完成功能作为项目历史记录。

## 已完成功能 / Completed Features

- **Dart VM Heap 内存监控** — HTTP 轮询连接 VM Service + `ProcessInfo.currentRss` 降级；趋势图、新生代/老生代、手动 GC、历史清理。
- **内存泄漏检测** — `WeakReference` 弱引用 + 四状态机（tracking → verifying → leaked/released），自动 GC 验证。
- **FPS / 帧率监控** — `addTimingsCallback` 采集帧数据，实时 FPS + 掉帧预警。
- **数据导出与分享** — 日志/网络导出 JSON/文本/CSV/HAR/cURL；剪贴板复制；`share_plus` 系统分享 + 敏感头遮蔽。
- **内存查看器** — 趋势图触摸交互（十字准线、拖动手跟手浏览、自适应 Y 轴）。
- **网络查看器** — Timeline 瀑布图、按 Method/状态码/拦截状态三维筛选。
- **日志查看器增强** — 自动滚动（可暂停）、正则搜索、按 tag 过滤、单条复制、主视图内详情页。
- **SharedPreferences 查看器** — 以自定义 DB 源并入 Database 体系，抽象 `SharedPrefsLike` 不依赖 `shared_preferences`。
- **Widget 检查器** — 渲染树一次性快照 + 面包屑导航浏览。
- **路由追踪穿透包装** — 构建期穿过中间壳 Widget 注入 `navigatorObservers`，兼容非直接 `MaterialApp`。
