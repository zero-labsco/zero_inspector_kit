# Zero Inspector Kit

A powerful Flutter plugin for in-app developer console, providing real-time debugging tools including network request inspection, logging, error aggregation, database viewing, and route tracking.

一个功能强大的 Flutter 插件，提供应用内开发者控制台，包括网络请求检查、日志记录、异常聚合、数据库查看和路由追踪。

## ✨ Features / 功能特性

| Feature | Description |
|---------|-------------|
| **Zero Invasion** | Integrate with 1 line of code / 一行代码集成 |
| **Network Inspector** | Real-time HTTP request viewing (http + Dio) / 实时网络请求查看 |
| **Log Viewer** | Auto-capture print()/debugPrint() and third-party logs / 自动捕获日志 |
| **Errors** | Aggregate & dedupe crashes by type + stack, with count and first/last seen / 按类型+堆栈去重聚合崩溃，记录次数与首末次时间 |
| **Database Viewer** | SQLite inspection with table data / 数据库查看 |
| **Memory Viewer** | Trend chart, Dart Heap, Native memory, leak detection (incl. Flutter MemoryAllocations bridge) / 内存趋势图、Dart Heap、Native 内存、泄漏检测（含官方 MemoryAllocations 桥接） |
| **FPS Monitor** | Real-time FPS, jank rate, trend chart / 实时 FPS、卡顿率、趋势图 |
| **Route Tracker** | Navigation history tracking / 路由追踪 |
| **Session Persistence** | Logs/network/errors survive restarts via a disk ring buffer; logs & errors replay on launch; one-tap session archive export / 日志/网络/异常通过磁盘环形缓冲跨重启保留，启动时回放日志与异常；一键导出会话存档 |
| **Alerts** | Rule-based alerts (network/log/memory/FPS) with unread badge / 基于规则的告警（网络/日志/内存/FPS）与未读角标 |
| **Sensitive Masking & cURL** | Mask secrets on export; one-click cURL copy; batch ops / 导出遮蔽敏感字段、一键复制 cURL、批量操作 |
| **Fuzzy Search** | Search in all viewers / 各查看器模糊搜索 |
| **Cross-platform** | Android, iOS / 跨平台支持 |

## 📚 Table of Contents / 目录

| Page | Description |
|------|-------------|
| [Getting Started](Getting-Started) | Quick start guide / 快速开始 |
| [Installation](Installation) | How to install / 安装方式 |
| [Usage](Usage) | Detailed usage / 详细使用 |
| [Network Inspector](Network-Inspector) | Network request viewing / 网络检查器 |
| [Log Viewer](Log-Viewer) | Log capturing and viewing / 日志查看器 |
| [Errors](Errors) | Aggregated error viewing / 异常聚合查看 |
| [Database Viewer](Database-Viewer) | Database inspection / 数据库查看器 |
| [Route Tracker](Route-Tracker) | Route tracking / 路由追踪 |
| [Memory Viewer](Memory-Viewer) | Memory monitoring & leak detection / 内存监控与泄漏检测 |
| [FPS Viewer](FPS-Viewer) | FPS monitoring & jank detection / FPS 监控与卡顿检测 |
| [Alerts](Alerts) | Rule-based alerting / 基于规则的告警 |
| [Configuration](Configuration) | Configuration options / 配置说明 |
| [Custom Database Provider](Custom-Database-Provider) | Extend database support / 自定义数据库提供者 |
| [FAQ](FAQ) | Frequently asked questions / 常见问题 |

## 🔗 Links / 链接

- [GitHub](https://github.com/zero-labsco/zero_inspector_kit)
- [Official Website](https://www.zerolabsco.com/)
- [pub.dev](https://pub.dev/packages/zero_inspector_kit)

## 📄 License / 许可证

This project is licensed under the **GNU General Public License v3.0**.

本项目采用 GNU General Public License v3.0 许可证。

This plugin is provided "as is", without warranty of any kind. The author assumes no responsibility or liability for the functionality, security, or any consequences arising from the use of modified versions or derivative projects.

本插件按"原样"提供，不提供任何担保。作者不对修改版或衍生项目的功能、安全性及任何使用后果承担责任。
