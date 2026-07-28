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
