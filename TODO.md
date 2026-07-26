# TODO / 待办事项

## Memory Inspector / 内存检查器

### 高优先级

- [ ] **恢复 Dart VM Heap 内存监控功能 / Restore Dart VM Heap memory monitoring feature**
  - **状态**: 暂时移除 / Temporarily removed
  - **原因**: 在 Android 真机上连接 VM Service 失败（Connection refused）
  - **原因**: Failed to connect to VM Service on Android real devices (Connection refused)
  - **涉及文件 / Related files**:
    - `lib/src/services/memory_inspector_service.dart`
    - `lib/src/ui/memory_viewer.dart`
    - `lib/src/models/memory_snapshot.dart` (已删除 / deleted)
  - **需要恢复的功能 / Features to restore**:
    - Dart Heap 内存使用量概览卡片 / Dart Heap memory usage overview card
    - 内存趋势图（折线图）/ Memory trend chart (line chart)
    - 新生代/老生代详细内存数据 / New generation / old generation detailed memory data
    - 手动触发 GC 功能 / Manual GC trigger feature
    - 历史快照清理功能 / History snapshot clear feature
  - **可能的解决方案 / Possible solutions**:
    - 研究 Android 真机上 VM Service 的正确连接方式
    - Research the correct way to connect to VM Service on Android real devices
    - 尝试使用 `dart:developer` 的其他 API
    - Try other APIs from `dart:developer`
    - 考虑使用 `ProcessInfo` 获取进程级内存作为替代
    - Consider using `ProcessInfo` to get process-level memory as an alternative

### 低优先级

- [ ] 研究 iOS 上 VM Service 的连接情况 / Research VM Service connection on iOS
- [ ] 添加内存泄漏检测功能 / Add memory leak detection feature
- [ ] 添加图片内存详细信息（单张图片大小）/ Add detailed image memory info (per image size)
