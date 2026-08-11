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
- [ ] **`pubspec.yaml` 依赖约束对齐 / Align `pubspec.yaml` dependency constraints**
  - `environment: dart` 当前 `>=3.11.0`，但鸿蒙 Dart 是 3.9.2 → **不满足**。需条件约束或 `>=3.9.2 <4.0.0`（评估放宽影响），或 `dependency_overrides` 临时解。
  - `flutter: ">=3.3.0"` 满足（鸿蒙 3.35.8 ≥ 3.3.0）。
  - `path_provider` 增加鸿蒙条件依赖 `path_provider_harmonyos`。
- [ ] **验证 `runAppWithInspector` 在鸿蒙的 `HttpOverrides.runZoned` 覆盖 / Verify `HttpOverrides.runZoned` coverage on OHOS**
  - 确保入口 Zone 覆盖完整，HTTPS + 流式响应在鸿蒙实测通过（待真机验证）。

#### 中优先级 / Medium priority

- [ ] **Memory / FPS 监控在鸿蒙的可用性 / Memory & FPS monitoring on OHOS**
  - `addTimingsCallback`（FPS）与 VM Service（内存）在鸿蒙 Engine 是否保留需实测（FPS 大概率可用；VM Service 取决于鸿蒙 Debug 模式支持）。
- [ ] **`docs/Installation.md` 增加鸿蒙段落 / Add OHOS section to `docs/Installation.md`**
  - 说明需使用 fvm 的鸿蒙 Flutter 分支编译 `.hap`，不走 pub.dev。
- [ ] **CI 与发布策略 / CI & publish strategy**
  - 鸿蒙包不走 pub.dev（走华为/OpenHarmony 私仓或单独发布），CI 需排除 `ohos/` 对官方 `flutter analyze` 的干扰（或加 `if (ohos)` 隔离）。

#### 低优先级 / Low priority

- [ ] **`release` 模式的 tree-shake 剔除在鸿蒙是否生效 / Verify release tree-shake on OHOS**
  - 确认 `kReleaseMode` 在鸿蒙下表现，保证 Inspector 在 release 构建被剔除。

### 下一步 / Next steps

- 已完成：调研 + `ohos/` 原生骨架 + `pubspec.yaml` 平台声明 + 示例 `flutter build hap` 跑通（unsigned HAP）+ `flutter analyze`/`dart format` 通过。安卓/iOS 业务代码保持未动。
  Done: research + `ohos/` native skeleton + `pubspec.yaml` platform declaration + example `flutter build hap` (unsigned HAP) + `flutter analyze`/`dart format` green. Android/iOS business code untouched.
- 待办：补 `ZeroInspectorKitOhos` Dart 分流类、`path_provider` 鸿蒙依赖、dart 约束对齐；并在真机实测网络拦截/数据库/内存FPS/HTTPS 流式。
  Todo: add `ZeroInspectorKitOhos` Dart branch class, `path_provider` OHOS dep, dart constraint alignment; verify network/db/memory/FPS/HTTPS-streaming on real device.
