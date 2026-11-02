# Installation / 安装

## From pub.dev (Recommended) / 从 pub.dev 安装（推荐）

Add the following to your `pubspec.yaml`:

在 `pubspec.yaml` 中添加以下依赖：

```yaml
dependencies:
  zero_inspector_kit: ^__ZIK_VERSION__
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
      ref: release/v__ZIK_VERSION__
```

## OpenHarmony / 鸿蒙

> The OpenHarmony native port (ArkTS plugin) lives on the `ohos/vX.Y.Z` branch — `main` does not ship it. To use the inspector on OpenHarmony, install from that branch:

> OpenHarmony 原生端口（ArkTS 插件）位于 `ohos/vX.Y.Z` 分支——`main` 不包含它。要在 OpenHarmony 上使用检查器，请从该分支安装：

```yaml
dependencies:
  zero_inspector_kit:
    git:
      url: https://github.com/zero-labsco/zero_inspector_kit.git
      ref: ohos/v__ZIK_VERSION__
```

Requires the OpenHarmony Flutter SDK and DevEco Studio; the bundled `ohos/` native module must be built as part of your OHOS app.

需配合 OpenHarmony Flutter SDK 与 DevEco Studio；随包提供的 `ohos/` 原生模块需作为你的 OHOS 应用的一部分一起构建。

## Platform Setup / 平台配置

### Android

No additional configuration needed.

无需额外配置。

### iOS

No additional configuration needed.

无需额外配置。

## Import / 导入

```dart
import 'package:zero_inspector_kit/zero_inspector_kit.dart';
```

## Requirements / 环境要求

| Requirement | Version |
|-------------|---------|
| Flutter | >= 3.3.0 |
| Dart SDK | >= 3.11.0 < 4.0.0 |

## Next Steps / 下一步

- [Getting Started](Getting-Started) — Quick start guide / 快速开始
- [Usage](Usage) — Full usage guide / 完整使用指南
