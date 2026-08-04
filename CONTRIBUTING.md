# Contributing to Zero Inspector Kit

First off, thanks for taking the time to contribute! 🎉

The following is a set of guidelines for contributing to Zero Inspector Kit. These are mostly guidelines, not rules. Use your best judgment, and feel free to propose changes to this document in a pull request.

> 感谢你抽出时间为本项目做贡献!以下是参与贡献 Zero Inspector Kit 的指引,内容以建议为主而非强制规则。请运用你的判断力,也欢迎通过 PR 提出对本文档的改进。

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Code Style](#code-style)
- [Testing](#testing)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)
- [Release Process](#release-process)

## Code of Conduct

This project is licensed under GPL-3.0. By participating, you are expected to uphold a respectful and collaborative tone. Please be kind to maintainers and other contributors.

> 本项目采用 GPL-3.0 许可证。参与贡献请保持尊重、协作的态度,对维护者和其他贡献者友善。

## Getting Started

### Prerequisites

- Flutter >= 3.3.0 (stable channel)
- Dart >= 3.11.0
- Android Studio / Xcode (for platform-specific testing)
- Git

> 环境要求:Flutter >= 3.3.0(stable 通道)、Dart >= 3.11.0、Android Studio / Xcode(用于平台测试)、Git。

### Setup

1. Fork the repository on GitHub.
2. Clone your fork locally:

   ```bash
   git clone https://github.com/<your-username>/zero_inspector_kit.git
   cd zero_inspector_kit
   ```

3. Add the upstream remote to keep your fork in sync:

   ```bash
   git remote add upstream https://github.com/zero-labsco/zero_inspector_kit.git
   ```

4. Install dependencies:

   ```bash
   flutter pub get
   cd example && flutter pub get && cd ..
   ```

5. Run the example app to verify everything works:

   ```bash
   cd example && flutter run
   ```

> 本地初始化步骤:Fork 仓库 → clone 你的 fork → 添加 upstream 远程 → 安装依赖 → 运行 example 验证。

## Development Workflow

1. Create a feature branch from `main`:

   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

2. Make your changes. Keep commits focused and write clear commit messages (see [Conventional Commits](https://www.conventionalcommits.org/)).

3. Run all checks before committing (see [Code Style](#code-style) and [Testing](#testing)).

4. Push to your fork and open a Pull Request against `main`.

> 开发流程:从 `main` 切出 feature/fix 分支 → 提交时保持 commit 聚合并写清晰消息(遵循 Conventional Commits) → 提交前跑完所有检查 → push 到你的 fork 并向 `main` 发起 PR。

## Code Style

This project follows the [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide.

> 本项目遵循 [Effective Dart](https://dart.dev/guides/language/effective-dart) 风格指南。

### Required Bilingual Comments

All Dart source files must include **bilingual (Chinese and English) comments** for classes, methods, and properties. This is a hard constraint of this project.

> 所有 Dart 源文件中的类、方法和属性必须包含**中英双语注释**,这是项目的硬性约定。

Example:

```dart
/// 实时帧率监测服务 / Real-time FPS monitoring service
class FpsService extends ChangeNotifier {
  /// 当前 FPS / Current FPS value
  double get currentFps => _currentFps;
}
```

### Formatting

Run before committing:

```bash
dart format lib/
dart format example/lib/
```

CI uses `dart format --set-exit-if-changed` to enforce formatting.

> 提交前运行 `dart format` 格式化。CI 使用 `--set-exit-if-changed` 强制检查。

### Analysis

Run before committing:

```bash
flutter analyze lib/
flutter analyze example/lib/
```

CI uses `flutter analyze` to enforce zero warnings/errors.

> 提交前运行 `flutter analyze` 静态分析。CI 要求零警告、零错误。

### Dependency Versions

All dependency versions in `pubspec.yaml` must use **exact version numbers without `^`** to ensure consistency.

> `pubspec.yaml` 中所有依赖版本必须使用**精确版本号(不带 `^`)**以保证一致性。

## Testing

### Run Tests

```bash
flutter test
```

All new features and bug fixes should include tests in the `test/` directory.

> 所有新功能和 bug 修复都应在 `test/` 目录中补充对应测试。

### Test Naming

Name test files `<source_file>_test.dart` and place them under `test/` mirroring the `lib/` structure.

> 测试文件命名 `<源文件>_test.dart`,放在 `test/` 下并镜像 `lib/` 结构。

## Pull Request Process

1. **Update CHANGELOG.md** under an `## [Unreleased]` section (or create one if missing). Describe what changed and why.
2. **Update documentation** if your change affects public API or user-facing behavior (README.md, README_zh.md, wiki/).
3. **Bilingual comments** must be added for any new code.
4. **CI must pass** — the CI workflow runs format check, analyze, and tests on every PR.
5. **Keep PRs focused** — one feature/fix per PR makes review faster.
6. **Link related issues** in the PR description (e.g., `Closes #123`).

> PR 流程:1) 在 CHANGELOG.md 的 `## [Unreleased]` 节更新变更说明;2) 若影响公开 API 或用户行为,同步更新 README/wiki;3) 新代码必须加双语注释;4) CI 必须通过;5) 一个 PR 只做一件事,便于审查;6) 在 PR 描述中关联相关 Issue(如 `Closes #123`)。

### PR Title Convention

Follow [Conventional Commits](https://www.conventionalcommits.org/):

- `feat: add new inspector tab`
- `fix: resolve FPS calculation on Android`
- `docs: update README with FPS section`
- `refactor: simplify floating button animation`
- `test: add FpsService unit tests`
- `chore: bump dependencies`

> PR 标题遵循 Conventional Commits 规范,如 `feat:` / `fix:` / `docs:` / `refactor:` / `test:` / `chore:`。

## Reporting Bugs

Use the [Bug Report template](https://github.com/zero-labsco/zero_inspector_kit/issues/new?template=bug_report.md). Please include:

- Flutter / Dart version (`flutter doctor -v`)
- Plugin version
- Platform (Android / iOS) and device/OS version
- Minimal reproduction steps
- Expected vs actual behavior
- Logs / screenshots if applicable

> 报告 Bug 请使用 Bug Report 模板,并提供:Flutter/Dart 版本(`flutter doctor -v`)、插件版本、平台与设备系统版本、最小复现步骤、期望 vs 实际行为、相关日志/截图。

## Suggesting Enhancements

Use the [Feature Request template](https://github.com/zero-labsco/zero_inspector_kit/issues/new?template=feature_request.md). For general discussion, please use [GitHub Discussions](https://github.com/zero-labsco/zero_inspector_kit/discussions) instead of opening an issue.

> 功能建议请用 Feature Request 模板;一般性讨论请到 [GitHub Discussions](https://github.com/zero-labsco/zero_inspector_kit/discussions),而非开 Issue。

## Release Process

Releases are managed by maintainers via git tags:

1. Ensure `pubspec.yaml` `version` is updated.
2. Ensure `CHANGELOG.md` is updated with the new version section.
3. Commit and push to `main`.
4. Create and push a tag `v<version>` (e.g., `v1.2.2`). **Do not name a branch `v<version>`** — a same-named branch/tag pair makes `git push origin v<version>` ambiguous. Use `refs/tags/` to push the tag explicitly:

   ```bash
   git tag v1.2.2
   git push origin refs/tags/v1.2.2
   ```

5. The `pub-publish.yml` workflow will automatically publish to pub.dev and create a GitHub Release.
6. (Optional) Archive the release as a branch named `release/<version>` (e.g., `release/1.2.2`). This branch does **not** trigger CI and exists only for archival. Create it via an explicit refspec:

   ```bash
   git push origin main:refs/heads/release/1.2.2
   ```

> 发布由维护者通过 git tag 管理:1) 更新 `pubspec.yaml` 的 `version`;2) 更新 `CHANGELOG.md` 对应版本节;3) 提交并 push 到 `main`;4) 创建并 push `v<version>` tag(如 `v1.2.2`)——**不要把分支命名为 `v<version>`**,同名分支/tag 会让 push 产生歧义,请用 `refs/tags/` 显式推送;5) `pub-publish.yml` 工作流会自动发布到 pub.dev 并创建 GitHub Release;6)(可选)以 `release/<version>` 命名归档分支(如 `release/1.2.2`),该分支不触发 CI、仅作归档,需经显式 refspec 创建。

---

Thank you for contributing! / 感谢你的贡献!
