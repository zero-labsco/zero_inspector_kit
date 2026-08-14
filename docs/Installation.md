# Installation / 安装

## From pub.dev (Recommended) / 从 pub.dev 安装（推荐）

Add the following to your `pubspec.yaml`:

在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  zero_inspector_kit: ^1.4.1
```

Then run:

然后运行：

```bash
flutter pub get
```

## From GitHub / 从 GitHub 安装

Alternatively, install from GitHub:

或者从 GitHub 安装：

```yaml
dependencies:
  zero_inspector_kit:
    git:
      url: https://github.com/zero-labsco/zero_inspector_kit.git
      ref: main
```

## Platform Setup / 平台配置

### Android

No additional configuration needed.

无需额外配置。

### iOS

No additional configuration needed.

无需额外配置。

### HarmonyOS (OpenHarmony)

HarmonyOS support ships inside the **same pub.dev package** — there is no separate
package to add. The `ohos/` native code is bundled with the package and compiled by
the OHOS Flutter fork. To use it:

鸿蒙支持**已包含在同一个 pub.dev 包中**,无需额外添加任何包。`ohos/` 原生代码随包分发,由鸿蒙定制 Flutter 分支编译。使用方式:

1. Install the plugin as above (pub.dev or GitHub).
   照常从 pub.dev 或 GitHub 安装本插件。
2. Build the HAP with the **OHOS Flutter fork** (e.g. an fvm-managed build such as
   `custom_3.35.8-ohos-1.0.1`), not the official stable Flutter.
   使用**鸿蒙定制 Flutter 分支**(如 fvm 管理的 `custom_3.35.8-ohos-1.0.1`)编译 HAP,而非官方稳定版。
3. No extra Dart imports or config are required — `runAppWithInspector()` works the
   same way. Native crash/freeze logs are collected via `hiAppEvent`; no additional
   permission needs to be declared by the consumer (the bundled HAR does not request
   one).
   无需额外的 Dart 引入或配置,`runAppWithInspector()` 用法一致。原生崩溃/卡死日志通过 `hiAppEvent` 订阅;消费者无需声明额外权限(随包分发的 HAR 不申请权限)。

> Note: the official `flutter analyze` / `pana` CI runs on stable Flutter and ignores
> the `ohos` platform; OHOS runtime verification happens on the OHOS fork only.
> 注意:官方 `flutter analyze` / `pana` CI 运行于稳定版 Flutter,会忽略 `ohos` 平台;鸿蒙运行时验证仅在定制 Flutter 下进行。

#### Local verification / 本地验证

The `ohos/` native code is **not compiled by the official CI** — it is bundled into
the pub.dev package as files and compiled only by the OHOS Flutter fork when a
developer builds the HAP. To verify it works on your machine:

`ohos/` 原生代码**不由官方 CI 编译**——它以文件形式随 pub.dev 包分发,只有当开发者用鸿蒙定制 Flutter 编译 HAP 时才会被编译。本地验证步骤:

1. Use the OHOS Flutter fork (e.g. via fvm):
   使用鸿蒙定制 Flutter(如通过 fvm 切换):
   ```bash
   fvm use custom_3.35.8-ohos-1.0.1   # or whichever OHOS fork you have
   flutter pub get
   ```
2. Build the HAP — this is where the bundled `ohos/` `.ets` code gets compiled into
   your app:
   编译 HAP——这一步才会把包内 `ohos/` 下的 `.ets` 代码编译进你的应用:
   ```bash
   flutter build hap
   ```
3. Confirm the plugin `.ets` made it in: the output HAP under
   `your_app/ohos/entry/build/default/outputs/default/` and the bundled
   `zero_inspector_kit` plugin should appear without ArkTS errors.
   确认插件 `.ets` 已编译进包:产物位于 `your_app/ohos/entry/build/default/outputs/default/`,
   且 `zero_inspector_kit` 插件无 ArkTS 报错。
4. (Optional) Run on a device/emulator to exercise native crash/freeze log capture
   via `hiAppEvent`. Signing is required for a real device.
   (可选)在真机/模拟器运行,验证通过 `hiAppEvent` 抓取的原生崩溃/卡死日志。真机安装需签名。

> The official `flutter analyze` / `pana` only checks the pure-Dart `lib/` code on
> stable Flutter; it never touches `ohos/`. That is expected and does **not** affect
> HarmonyOS developers, who build with the OHOS fork.
> 官方 `flutter analyze` / `pana` 只在稳定版 Flutter 上检查纯 Dart 的 `lib/` 代码,从不触碰 `ohos/`。
> 这是预期行为,**不影响**使用鸿蒙定制 Flutter 的开发者。

## Import / 导入

```dart
import 'package:zero_inspector_kit/zero_inspector_kit.dart';
```

## Requirements / 环境要求

| Requirement | Version |
|-------------|---------|
| Flutter | >= 3.3.0 |
| Dart SDK | >= 3.9.2 < 4.0.0 |

## Next Steps / 下一步

- [Getting Started](Getting-Started) — Quick start guide / 快速开始
- [Usage](Usage) — Full usage guide / 完整使用指南
