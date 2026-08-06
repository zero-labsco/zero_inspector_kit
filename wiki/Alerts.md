# Alerts / 告警系统

## Overview / 概述

> **Available since v1.3.0**
>
> **v1.3.0 起可用**

The alert system lets you define rules that proactively surface problems across network requests, logs, memory, and FPS — without manually scanning the panels.

告警系统允许你定义规则，主动暴露网络请求、日志、内存、FPS 方面的问题，无需手动逐个面板排查。

## How It Works / 工作原理

- Rules are evaluated by `AlertService` whenever a relevant event occurs / 每当相关事件发生时，`AlertService` 会评估规则
- Matched rules produce alerts, and the unread count is exposed via a `ValueNotifier<int>` / 命中的规则会生成告警，未读数通过 `ValueNotifier<int>` 暴露
- The floating button shows an unread-count badge; opening the panel clears it / 悬浮球显示未读数量角标，打开面板即清零
- An **Alerts** tab in the inspector panel lists all triggered alerts / 检查器面板的 **Alerts** 标签页列出所有已触发的告警

## Rule Types / 规则类型

| Type | Trigger / 触发条件 | Example / 示例 |
|------|-------------------|----------------|
| **Network** | Response status code / 响应状态码 | Alert when status ≥ 400 / 状态码 ≥ 400 时告警 |
| **Log** | Log level or message / 日志级别或内容 | Alert on error logs / 出现 error 日志时告警 |
| **Memory** | Dart heap / Native memory threshold / 内存阈值 | Alert when Dart heap > 100 MB / Dart 堆 > 100 MB 时告警 |
| **FPS** | Frame rate / 帧率 | Alert when FPS < 50 / FPS < 50 时告警 |

## UI Features / UI 功能

### Floating Button Badge / 悬浮球角标

- A red badge shows the current unread alert count (clamped 0–99) / 红色角标显示当前未读告警数（0–99）
- The number is drawn inside the button so it is never clipped at screen edges / 数字直接绘制在按钮内部，吸附屏幕边缘时不会被裁切
- Opening the inspector panel clears the unread count / 打开检查器面板即清零未读数

### Alerts Tab / Alerts 标签页

- Lists triggered alerts with type, condition, and timestamp / 列出已触发告警的类型、条件与时间
- Tap an alert to jump to the related panel (network / log / memory / FPS) / 点击告警可跳转到相关面板（网络 / 日志 / 内存 / FPS）

## Notes / 备注

- Alerts are evaluated in-process and shown in the developer console only; they do not send data off-device / 告警仅在本机开发者控制台内评估与展示，不会将数据发送到设备外
- The alert system is tree-shaken out in release builds, like the rest of the inspector / 与检查器其余部分一样，告警系统在 release 构建中被 tree-shake 移除
