# TODO / 待办清单

## HarmonyOS (OpenHarmony) 适配调研 / HarmonyOS (OpenHarmony) Adaptation Research

> 分支：`feat/ohos-support`（基于 `main`）。调研时间：2026-08-12。
> Branch: `feat/ohos-support` (based on `main`). Research date: 2026-08-12.

### 可行性结论 / Feasibility verdict

- ✅ **可行 / Feasible**，但属于中等偏大的工程，不是开关式支持。
  Feasible, but a medium-to-large effort — not a toggle.
- 鸿蒙用的是 **OpenHarmony SIG 的 Flutter 定制分支**（非官方稳定版），你的官方 Flutter 3.41.7（安卓/iOS）**完全不受影响**，两者物理隔离在不同目录。
  HarmonyOS uses OpenHarmony SIG's custom Flutter fork (not official stable). Your official Flutter 3.41.7 (Android/iOS) is **unaffected**; the two are physically isolated in separate directories.
- 已在本机装好鸿蒙 Flutter：`D:\Flutter\fvm\versions\custom_3.35.8-ohos-1.0.1`（Dart 3.9.2），通过 fvm 管理；OpenHarmony SDK 在 `D:\OpenHarmony\Sdk`（API 20）。
  HarmonyOS Flutter installed locally: `D:\Flutter\fvm\versions\custom_3.35.8-ohos-1.0.1` (Dart 3.9.2), managed via fvm; OpenHarmony SDK at `D:\OpenHarmony\Sdk` (API 20).

### 平台分流方案（保安卓/iOS 稳定性）/ Platform branching (keep Android/iOS stable)

- Dart 侧用 `defaultTargetPlatform == TargetPlatform.ohos` 做 `if`/`switch` 分流（鸿蒙分支给 `TargetPlatform` 加了 `ohos` 枚举值）。
  Use `defaultTargetPlatform == TargetPlatform.ohos` for `if`/`switch` branching (the OHOS fork adds an `ohos` enum value to `TargetPlatform`).
- 插件层利用现有 `plugin_platform_interface`：注册 `ZeroInspectorKitOhos`（新写）与 `ZeroInspectorKitMethodChannel`（安卓/iOS 原样不动）并存。
  Leverage the existing `plugin_platform_interface`: register a new `ZeroInspectorKitOhos` alongside the untouched `ZeroInspectorKitMethodChannel` (Android/iOS unchanged).
- 原生代码放新目录 `ohos/`（ArkTS `.ets`），`android/` 与 `ios/` 目录互不干扰；普通 `flutter build apk/ios` 不会编译 `ohos/`。
  Native code lives in a new `ohos/` dir (ArkTS `.ets`); `android/` and `ios/` are untouched; normal `flutter build apk/ios` won't compile `ohos/`.

### 两个核心风险点调研结果 / Two core risk findings

#### 风险 1：`HttpOverrides` 网络拦截在鸿蒙 Engine 是否生效？ ✅ 生效

- 调研结论（来源：CSDN《Flutter 三方库 http_client_interceptor 的鸿蒙化适配指南》2026-03-11）：
  - 鸿蒙端**原生支持** `HttpOverrides` + 注入代理 `HttpClient` 的全局拦截方案，**不需要额外 package**。
  - 能拦截全量 Dart 原生 `HttpClient` 请求，含第三方插件内部直接使用的 `HttpClient`（对业务代码零侵入）。
  - 限制/坑点：
    1. 必须在**首个 `main()` 的 `runZoned` 内启动 `runApp`**，覆盖不全则部分请求绕过拦截；
    2. 需正确传递 `SecurityContext` 以免 HTTPS 证书校验失败；
    3. 响应流需"包装流非破坏嗅探"，避免过早关闭 Body 流导致业务代码拿不到数据。
- 对本插件影响：网络日志拦截（`HttpOverrides` + `inspector_http_client`）**核心机制在鸿蒙可用**，但需在 `runAppWithInspector` 入口确保 `HttpOverrides.runZoned` 覆盖完整，并在鸿蒙下验证 HTTPS 与流式响应读取。
  Impact: the network-log interception core (`HttpOverrides` + `inspector_http_client`) **is usable on OHOS**, but `runAppWithInspector` must ensure full `runZoned` coverage, and HTTPS/streaming responses must be verified on OHOS.

#### 风险 2：`sqflite` 在鸿蒙是否可用？ ✅ 可用

- 调研结论（来源：CSDN《Flutter 三方库 sqflite 的鸿蒙化适配与实战指南》2026-05-13）：
  - `sqflite` 在鸿蒙上兼容性总体不错，**无需替换为其他包**。
  - 推荐版本 `sqflite: ^2.3.0`（原文标注「2.3.x 在鸿蒙上比较稳定」）；本插件当前 `^2.4.0` 应在鸿蒙可用，真机实测确认。
  - 数据库路径用 `sqflite` 自带的 `getDatabasesPath()` + `path` 包 `join()`，**不依赖 `path_provider`**。
  - 踩坑：路径拼接必须用 `path` 包 `join`，禁止字符串 `+ '/'`。
- 对本插件影响：数据库查看器（基于 `sqflite`）**可在鸿蒙复用**，但 `pubspec.yaml` 依赖需处理：
  - `path_provider` → 鸿蒙下用 `path_provider_harmonyos`（或条件依赖 / `dependency_overrides`）；
  - `sqflite` 当前 `^2.4.0` 在鸿蒙应可用，需实测验证。
  Impact: the database viewer (based on `sqflite`) **can be reused on OHOS**, but `pubspec.yaml` deps need handling: `path_provider` → `path_provider_harmonyos` on OHOS (or conditional dep / `dependency_overrides`). Current `sqflite: ^2.4.0` likely works on OHOS — verify on device/simulator.

### 需要补齐的清单 / Checklist of what to add

#### 高优先级 / High priority

- [x] **新增 `ohos/` 原生目录与 ArkTS 插件实现 / Add `ohos/` native dir + ArkTS plugin** ✅ (2026-08-12)
  - `ohos/src/main/ets/components/plugin/ZeroInspectorKitPlugin.ets`，`implements FlutterPlugin, MethodCallHandler`，注册 MethodChannel `zero_inspector_kit`。
  - `ohos/oh-package.json5` 版本已对齐 `1.3.3`，`ohos/` 下 `module.json5` deviceTypes 精简为 `["default"]`。
  - 安卓 `ZeroInspectorKitPlugin.kt` / iOS `ZeroInspectorKitPlugin.swift` 不动。
  - 示例 `flutter build hap` 已跑通，产物 `example/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`（unsigned，待签名装真机）。
- [x] **新增 `ZeroInspectorKitOhos` 平台实现类 / Add `ZeroInspectorKitOhos` platform impl** ✅ (2026-08-12)
  - 新增 `lib/zero_inspector_kit_ohos.dart`（`ZeroInspectorKitOhos extends ZeroInspectorKitPlatform`，走 MethodChannel `zero_inspector_kit`）。
  - `lib/zero_inspector_kit_platform_interface.dart` 新增 `isOhos` 判断与 `ensurePlatformImplementation()`，**不引用 `TargetPlatform.ohos` 枚举**（官方 Flutter 无此值，会编译报错），改用 `defaultTargetPlatform.toString().contains('ohos')` 运行时判断；`ZeroInspectorKit.init()` 早期调用。
  - barrel `lib/zero_inspector_kit.dart` 已 export `zero_inspector_kit_ohos.dart`，并 import 平台接口。
  - `flutter analyze` 0 issues，`dart format` 通过。核心能力仍纯 Dart 跨平台共用，鸿蒙专属分支预留在 ohos 实现类内。
- [x] **`pubspec.yaml` 平台声明 / `pubspec.yaml` platform declaration** ✅ (2026-08-12)
  - `flutter.plugin.platforms` 已加 `ohos`（package `zero_inspector_kit`, pluginClass `ZeroInspectorKitPlugin`），插件已被识别并打包进 HAP。
- [x] **`ohos` 原生方法对标安卓/iOS / `ohos` native methods parity with Android/iOS** ✅ (2026-08-12)
  - `ohos/.../ZeroInspectorKitPlugin.ets` 补齐中英双语注释（原仅一行占位），并与 kt/swift 对齐 MethodChannel 契约：实现 `getPlatformVersion` / `getNativeLogs` / `startNativeLogListener` / `stopNativeLogListener` / `getProcessMemoryInfo`。
  - `getProcessMemoryInfo` 返回与 iOS 一致的字段结构（含 `rss`/`totalPss`/`totalMem`/`availMem`/`lowMemory` 等），鸿蒙具体取值暂以 0 填充占位，避免 Dart 侧解析异常。Dart 侧 `PlatformChannel` 早已定义这 4 个方法，此前 `.ets` 缺实现会导致 `notImplemented`/null，现已对齐。
- [x] **`ohos` 接入真实内存与日志取值 / `ohos` real memory & log values** ✅ (2026-08-12, 代码已接入)
  - **内存（真实）**：`getProcessMemoryInfo` 同步读取应用自身 `/proc/self/status`（普通应用可读），正则解析 `VmRSS:`（真实进程常驻内存，字节）填入 `rss`/`totalRss`，`VmSwap:` 填入 `totalSwapPss`；其余安卓分项（PSS 等）OpenHarmony 无等价 API → 填 0 + `notAvailable: true`；设备级 `totalMem`/`availMem` 无公开 API → 0 + `notAvailable: true`。
  - **日志（真实但非全量）**：OpenHarmony **无** logcat 等价读取 API（hilog 仅写、不可读系统日志流），但可通过 `@ohos.hiviewdfx.hiAppEvent` 的 `addWatcher` **真实订阅应用级崩溃/卡死事件**（`hiAppEvent.event.APP_CRASH` / `APP_FREEZE`）。已落地 **B 方案**：`startNativeLogListener` 开启订阅（幂等）、`onReceive` 把事件 JSON 序列化进 `appEvents` 缓存、`getNativeLogs` 回放缓存（截断到 `limit` 条，保持 `List<String>` 契约）、`stopNativeLogListener` 取消订阅并清空。需在 `module.json5` 声明 `ohos.permission.APP_TRACKING_CONSENT` 权限（reason 用 `$string:app_tracking_reason` 引用 `resources/base/element/string.json` 资源，文案已改为英文）。注意：这是"应用级异常事件"而非全量 stdout 日志——与 iOS 用 `dup2` 抓 stdout/stderr 的真实全量日志**能力不同**；iOS 早已真实接好，无需改动。
  - 已对照 `@ohos.file.fs.readTextSync` / `@ohos.hilog` + `%{public}s` / `@ohos.hiviewdfx.hiAppEvent.addWatcher`/`removeWatcher` 公开契约编写；`flutter analyze lib` 无回归。
  - ✅ **已验证**：完整 `flutter build hap` 已在鸿蒙定制 Flutter `custom_3.35.8-ohos-1.0.1`（OpenHarmony SDK `D:\OpenHarmony\Sdk` API 20，DevEco `D:\Program Files\Huawei\DevEco Studio`）下端到端跑通，产出 `example/ohos/entry/build/default/outputs/default/entry-default-unsigned.hap`（unsigned，待签名装真机），`.ets` 零 ArkTS 错误，`flutter analyze lib` 通过。工具链 PATH 需含 ohpm/node/hvigor 与 `OHOS_SDK_HOME`/`HVIGOR_HOME`。
- [x] **`pubspec.yaml` 依赖约束对齐 / Align `pubspec.yaml` dependency constraints** ✅ (2026-08-12)
  - `environment: dart` 已放宽为 `>=3.9.2 <4.0.0`（满足鸿蒙 Dart 3.9.2，且仍兼容官方 Flutter 3.3+ 的 Dart）。`flutter: ">=3.3.0"` 满足（鸿蒙 3.35.8 ≥ 3.3.0）。
  - `path_provider_harmonyos: ^0.0.1` 已加入依赖，作为 `path_provider` 的鸿蒙联邦实现层（`lib/src/services/` 下 sqlite_provider / memory_inspector_service / export_service 三处 `import 'package:path_provider/path_provider.dart'` 在鸿蒙下由它提供平台后端）。
- [ ] **验证 `runAppWithInspector` 在鸿蒙的 `HttpOverrides.runZoned` 覆盖 / Verify `HttpOverrides.runZoned` coverage on OHOS**
  - 确保入口 Zone 覆盖完整，HTTPS + 流式响应在鸿蒙实测通过（待真机验证）。

#### 中优先级 / Medium priority

- [ ] **Memory / FPS 监控在鸿蒙的可用性 / Memory & FPS monitoring on OHOS**
  - `addTimingsCallback`（FPS）与 VM Service（内存）在鸿蒙 Engine 是否保留需实测（FPS 大概率可用；VM Service 取决于鸿蒙 Debug 模式支持）。
- [ ] **`docs/Installation.md` 增加鸿蒙段落 / Add OHOS section to `docs/Installation.md`**
  - 说明：安卓/iOS 用户照常 `flutter pub add zero_inspector_kit` 即用；**鸿蒙用户也直接从 pub.dev 拉同一包**，但需用定制 Flutter 分支（如 fvm 的 `custom_3.35.8-ohos-1.0.1`）编译 `.hap`，`ohos/` 原生代码随包分发、无需额外配置。
- [ ] **CI 与发布策略 / CI & publish strategy**
  - **继续发 pub.dev**（方案 A）：`ohos/` 原生代码随包分发，安卓/iOS/鸿蒙用户均 `flutter pub add` 一行接入。需解决 CI 干扰——官方 `flutter analyze`/`pana` 跑在官方稳定 Flutter 上，不识别 `TargetPlatform.ohos` 也不编译 `ohos/`，故要确保官方 analyze 不因 `ohos:` 平台声明或 `ohos/` 目录报错（必要时在 analyze 步骤加平台限制或路径忽略）。鸿蒙侧真机验证需在定制 Flutter 环境单独跑，不进官方 CI。

#### 低优先级 / Low priority

- [ ] **`release` 模式的 tree-shake 剔除在鸿蒙是否生效 / Verify release tree-shake on OHOS**
  - 确认 `kReleaseMode` 在鸿蒙下表现，保证 Inspector 在 release 构建被剔除。

### 下一步 / Next steps

- 已完成：调研 + `ohos/` 原生骨架 + `pubspec.yaml` 平台声明 + 示例 `flutter build hap` 跑通（unsigned HAP）+ `flutter analyze`/`dart format` 通过。安卓/iOS 业务代码保持未动。
  Done: research + `ohos/` native skeleton + `pubspec.yaml` platform declaration + example `flutter build hap` (unsigned HAP) + `flutter analyze`/`dart format` green. Android/iOS business code untouched.
- 待办（剩余）：鸿蒙真机实测 `runAppWithInspector` 的 `HttpOverrides.runZoned` 覆盖（HTTPS + 流式响应）；Memory/FPS 监控在鸿蒙 Engine 的可用性；`release` 模式 tree-shake 在鸿蒙是否生效；`docs/Installation.md` 鸿蒙段落；CI 官方 analyze 对 `ohos:` 平台声明的隔离处理。
  Todo (remaining): verify `runAppWithInspector`'s `HttpOverrides.runZoned` coverage on OHOS (HTTPS + streaming); Memory/FPS availability on OHOS Engine; release tree-shake on OHOS; `docs/Installation.md` OHOS section; CI official-analyze isolation for the `ohos:` platform declaration.
