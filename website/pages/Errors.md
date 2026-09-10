# Errors / 异常聚合查看器

## Overview / 概述

> **Available since v1.9.0**
>
> **v1.9.0 起可用**

The Errors tab surfaces "the same crash happening repeatedly". When the inspector is running, `ErrorService` hooks both `FlutterError.onError` and `PlatformDispatcher.onError` (keeping the default red-screen / console behavior for both) and aggregates every exception by **type + stack signature**. Repeated instances of the same crash merge into one record that shows how many times it occurred and when it was first/last seen — instead of flooding the log with hundreds of identical stack traces.

Errors 标签页用来快速发现"同一处崩溃反复出现"的问题。检查器运行时，`ErrorService` 会接管 `FlutterError.onError`（保留默认的红色报错与控制台行为），把每次异常按**类型 + 堆栈签名**去重聚合：同一处崩溃的多次发生会合并为一条记录，展示累计次数与首末次时间——而不是用成百上千条相同的堆栈刷屏日志。

## What Gets Captured / 捕获来源

| Source / 来源 | How / 方式 |
|---------------|------------|
| Flutter framework errors / Flutter 框架异常 | Hooks `FlutterError.onError` (default handler kept) / 接管 `FlutterError.onError`（保留默认处理） |
| Framework-boundary & platform-channel errors / 框架边界外与平台通道异常 | `PlatformDispatcher.onError` (with save/restore) / `PlatformDispatcher.onError`（接管 + 还原） |
| Uncaught async errors / 未捕获异步异常 | `runZonedGuarded` inside `runAppWithInspector()` / `runAppWithInspector()` 内部的 `runZonedGuarded` |
| Manual reports / 手动上报 | `ErrorService.instance.report(exception, stackTrace)` — for gRPC / custom protocols / your own error paths / 用于 gRPC / 自定义协议或你自己的错误通道 |

Captured records are also **persisted to disk** (see [Session Persistence](#session-persistence--会话持久化) below), so aggregated errors from previous sessions are replayed on the next launch.

捕获到的记录也会**落盘持久化**（见下文[会话持久化](#session-persistence--会话持久化)），下次启动时会回放上次会话的聚合异常。

## Deduplication / 去重规则

- Records are keyed by exception **type** plus a **stack signature** (first frames with line/address noise stripped) / 按异常**类型** + **堆栈签名**（取前若干帧并去掉行号/地址噪声）去重
- A new occurrence of an existing signature bumps its `count` and updates `lastSeen` instead of adding a new row / 同签名的再次发生只累加 `count` 并更新 `lastSeen`，不新增行
- Ring buffer capped at **200 aggregated records** (oldest dropped) / 环形缓冲上限 **200 条**聚合记录（超出丢弃最旧）

## UI Features / UI 功能

### Errors Tab / Errors 标签页

- Lists aggregated errors newest-first, showing the exception **type**, **message**, `first seen` / `last seen` time, and a **×N** badge when the same crash recurred / 按最新在前列出聚合异常，展示异常**类型**、**消息**、`首次/末次`出现时间，同崩溃复发时显示 **×N** 徽章
- Tap a row to expand the **full stack sample** (truncated at 8000 chars); tap again to collapse / 点击行展开**完整堆栈样本**（8000 字符截断）；再点收起
- **Copy stack** per row / 行内**复制堆栈**
- **Search** filters by exception type or message / **搜索**按异常类型或消息过滤
- **Clear** empties the aggregated list / **清除**清空聚合列表

### Tab Badge / 标签页红点

- The **Errors tab icon** shows a red count badge while there are aggregated errors (capped at `99+`), so recurring crashes are visible at a glance / **Errors 标签页图标**在有聚合异常时显示红色计数（`99+` 封顶），一眼可见反复崩溃
- Opening the Errors tab is **not** required to see the badge — it reflects `ErrorService.instance.errorCount` whenever the panel is open / 只要面板打开，标签红点即反映 `ErrorService.instance.errorCount`，无需先进入 Errors 页

> Note: the floating ball itself stays clean — its red count (if any) is the **Alerts** unread badge (`AlertService`), not error aggregation.
>
> 注意：悬浮球本身保持纯粹——球上的红色数字（如有）来自**告警**未读数（`AlertService`），与异常聚合无关。

## API / 接口

The full service is re-exported from the package root — no need to import `lib/src/`.

完整服务已从包根导出，无需 import `lib/src/`。

```dart
import 'package:zero_inspector_kit/zero_inspector_kit.dart';

// Report an exception manually (gRPC/custom protocol/your own error paths) / 手动上报异常
ErrorService.instance.report(error, stackTrace, 'myModule');

// Read the aggregated view (newest first) / 读取聚合视图（最新在前）
final ErrorRecord latest = ErrorService.instance.errors.first;
print('${latest.type} x${latest.count} — first ${latest.firstSeen} / last ${latest.lastSeen}');

// Clear all records / 清空所有记录
ErrorService.instance.clear();
```

| Member | Description |
|--------|-------------|
| `errors` | `List<ErrorRecord>` — aggregated records, newest first / 聚合记录，最新在前 |
| `errorCount` | `int` — number of aggregated records / 聚合记录条数 |
| `isEnabled` | `bool` — capture toggle (programmatic) / 抓取开关（代码控制） |
| `report(exception, stack, [context])` | Manually report an exception / 手动上报异常 |
| `restore(records)` | Restore persisted records (replay on launch; existing dedup ids are skipped) / 恢复持久化记录（启动回放；已存在的去重 id 跳过） |
| `clear()` | Clear all aggregated records / 清空全部记录 |
| `install()` / `uninstall()` | Hook / restore `FlutterError.onError` **and** `PlatformDispatcher.onError` / 接管 / 还原 `FlutterError.onError` 与 `PlatformDispatcher.onError` |

### ErrorRecord / 异常记录

| Field | Description |
|-------|-------------|
| `type` | Exception type name (e.g. `_TypeError`) / 异常类型名 |
| `message` | Exception message / 异常消息 |
| `count` | Total occurrences / 累计出现次数 |
| `firstSeen` / `lastSeen` | First / last occurrence time / 首次 / 末次出现时间 |
| `sampleStack` | One full stack sample (may be truncated) / 一条完整堆栈样本（可能截断） |

## Session Persistence / 会话持久化

Errors — together with logs, network requests **and alerts** — are asynchronously flushed to a local SQLite **ring buffer** (`zero_inspector_kit.db`). On the next launch, **logs, aggregated errors and alerts replay into their tabs**, so a crash you saw yesterday is still inspectable today even though the panel was never opened; network requests stay archived on disk for later export. Use the **storage icon** in the panel header to open the **Persisted data** manager: see the current row counts, **export the full session archive** as JSON, or clear the disk. See [Configuration](Configuration) (PersistenceService section) for details and the tuning parameters.

异常与日志、网络请求、告警一起被异步写入本地 SQLite **环形缓冲**（`zero_inspector_kit.db`）。**下次启动时，日志、聚合异常与告警会回放入各自标签页**——即使昨天从没打开过面板，今天依然能复盘当时的崩溃现场；网络请求保留在磁盘存档，供之后导出。点击面板头部的**存储图标**可打开 **Persisted data** 管理弹层：查看当前行数、**导出完整会话存档** JSON，或清空磁盘。详见 [Configuration](Configuration)（PersistenceService 一节）的参数说明。

## Enable / Disable / 开关

- `enableErrorCapture` (default `true`) in `ZeroInspectorKit.init()` controls error aggregation / `init()` 的 `enableErrorCapture`（默认 `true`）控制异常聚合
- `enablePersistence` (default `true`) controls the disk ring buffer / `enablePersistence`（默认 `true`）控制磁盘环形缓冲
- Set both to `false` to keep everything in memory only / 两者都设为 `false` 时数据仅保留在内存

```dart
ZeroInspectorKit.init(
  enableErrorCapture: true,
  enablePersistence: true,   // false → memory-only / 关闭后仅内存
);
```

## Related / 相关

- [Log Viewer](Log-Viewer) — raw log stream including error lines / 原始日志流（含错误行）
- [Configuration](Configuration) — init parameters and full service APIs / 初始化参数与完整服务接口
- [Usage](Usage) — general usage guide / 使用指南
