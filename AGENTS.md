# Zero Inspector Kit - Agent Guide

This file defines the architecture, coding conventions, and required workflows for the `zero_inspector_kit` Flutter plugin. AI coding agents (CodeBuddy, Trae, Cursor, Claude Code, GitHub Copilot, Codex, etc.) should read and follow it for any task in this repository. It is the single source of truth for project conventions.

## Overview
`zero_inspector_kit` is a Flutter plugin providing an in-app developer console: network inspection, logging, database viewing, memory monitoring, FPS monitoring, and route tracking for Android and iOS. Integration is one line (`ZeroInspectorKit.runAppWithInspector`). The inspector auto-disables in release builds (tree-shaken out).

## When to apply
- Implementing features, fixing bugs, or changing the public API in `lib/`.
- Opening pull requests (titles must follow Conventional Commits; 3 status checks are required to merge).
- Cutting a release or publishing to pub.dev.
- Updating the GitHub Pages documentation site.
- Editing `pubspec.yaml`, the workflows under `.github/workflows/`, or the native Android/iOS code.

## Architecture
- `lib/zero_inspector_kit.dart` - public barrel; re-export the public API only. Add new public symbols here.
- `lib/zero_inspector_kit_platform_interface.dart` - `ZeroInspectorKitPlatform` abstract base.
- `lib/zero_inspector_kit_method_channel.dart` - default `MethodChannel` implementation.
- `lib/zero_inspector_kit_dio.dart` - Dio integration helper.
- `lib/src/` - 33 implementation files (services, UI, models). Do not import directly from consumers.
- Platform pattern: define the abstract API in the platform interface, provide the `MethodChannel` default, register it in the barrel.
- How features work: network capture via `HttpOverrides` (covers `http` and Dio's `HttpClient`); logging via Zone plus `debugPrint` override; memory/FPS via VM Service plus `addTimingsCallback` (v1.2.1+ uses real frame timestamps and `rasterFinish - buildStart` duration to catch GPU jank).
- Native: Android `android/src/main/kotlin/.../ZeroInspectorKitPlugin.kt` (package `com.zerolabsco.zero_inspector_kit`); iOS `ios/Classes/ZeroInspectorKitPlugin.swift`. Keep native changes minimal and matching the method channel contract.
- License: GPL-3.0. Do not relicense.

## Coding conventions
- Follow `effective_dart`; style is enforced by `flutter analyze` / `flutter_lints` (v6) in CI.
- Use Conventional Commits for both commit messages AND PR titles: `feat:`, `fix:`, `docs:`, `style:`, `refactor:`, `perf:`, `test:`, `build:`, `ci:`, `chore:`, `revert:`.
- Do not break the public API without a major version bump.

## Workflows

### Branching and PRs
- Branch from `main` with a typed prefix: `feat/`, `fix/`, `docs/`, `ci/`, `chore/`, etc.
- Never push directly to `main`; it is branch-protected and requires 3 passing status checks to merge.
- PR titles MUST follow Conventional Commits, enforced by `pr-title-check.yml` (`amannn/action-semantic-pull-request@v6`).
- Required checks before merge: `Analyze & Test`, `Pana Score Check`, `Check PR Title (Conventional Commits)`.

### CI
- `ci.yml`: `actions/checkout@v7`, `subosito/flutter-action@v2`, `actions/cache@v5` (pub cache keyed on `pubspec.lock` plus `example/pubspec.lock`); runs `flutter analyze`, `flutter test`, and `pana` score check.
- `stale.yml`: `actions/stale@v11` marks stale issues/PRs.
- `paths-ignore` skips user-facing docs (`README*.md`, `CHANGELOG.md`, `TODO.md`, `wiki/**`, `docs/**`) to save CI minutes, but it MUST NOT blanket-ignore all `**.md`. `AGENTS.md` and `.codebuddy/**` are intentionally kept out of `paths-ignore` so docs-only PRs still run the required checks and can merge (branch protection requires 3 passing checks; a skipped `ci.yml` would block the merge). Never reintroduce `'**.md'` to `paths-ignore`.

### Release and publish
1. Bump `version` in `pubspec.yaml` (semver; major bump for breaking public API).
2. Update `README.md` / `CHANGELOG.md` as needed.
3. Commit on a branch, open PR, merge to `main` after checks pass.
4. Tag: `git tag vX.Y.Z && git push origin vX.Y.Z`.
5. `pub-publish.yml` publishes via `k-paxian/dart-package-publisher@v1.6` using the `PUB_CREDENTIALS_JSON` secret (fields `accessToken`, `refreshToken`; set `flutter: true`). Do NOT pass OIDC fields (`idToken` / `tokenEndpoint` / `scopes`); the action does not support them and emits invalid-input warnings.
   - Note: `k-paxian` internally uses older actions that emit Node 20 deprecation warnings. This is accepted (B1 decision); functionality is unaffected.

### Documentation site (GitHub Pages)
- Source content lives in `docs/` (migrated from `wiki/` via `git mv wiki docs`).
- Publishing branch: `docs/github-pages`; GitHub Pages serves the `/docs` folder of that branch.
- Live site: https://zero-labsco.github.io/zero_inspector_kit/
- To update docs: edit `docs/` on `docs/github-pages`, commit, push; Pages redeploys automatically.
- `pubspec.yaml` has a `documentation:` field pointing to the site (rendered on pub.dev). Keep it in sync after the site URL is stable.

## New feature development checklist
- [ ] Confirm the change against `effective_dart` and the existing `lib/src/` structure.
- [ ] Expose any new public symbol through `lib/zero_inspector_kit.dart` only.
- [ ] Add or update unit tests under `test/`.
- [ ] Keep native Android/iOS changes minimal and matching the method channel contract.
- [ ] Run `flutter analyze` and `flutter test` locally before pushing.
- [ ] Use a typed branch (`feat/...`) and a Conventional Commits PR title.
- [ ] Ensure the 3 required status checks pass before requesting review/merge.
- [ ] For user-facing changes, update `README.md` and the `docs/` site.
- [ ] For releases, bump `version`, update changelog, tag `vX.Y.Z`, and let `pub-publish.yml` publish.
