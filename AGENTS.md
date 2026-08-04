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
- `lib/src/` - 33 implementation files grouped as: `interceptors/` (dio, http, log, route_observer), `platform/` (platform_channel), `models/` (database_info, interceptor_rule, leak_record, log_entry, memory_snapshot, network_request, route_entry), `services/` (database_provider, database_service, export_service, fps_service, inspector_service, memory_inspector_service, sqlite_provider), `utils/` (environment, inspector_log, memory_leak_tracking), `ui/` (conditional_inspector, database_viewer, floating_button, fps_viewer, inspector_panel, log_viewer, memory_trend_chart, memory_viewer, network_viewer, route_viewer, theme/inspector_theme). Do not import `lib/src/` directly from consumers.
- Public API entry: the `ZeroInspectorKit` class (in the barrel) exposes `init()`, `wrapApp()`, and `runAppWithInspector()`. The barrel also re-exports the interceptors, services, UI widgets, and utils listed above so consumers use them via the package root, never via `lib/src/`.

## Dependencies and SDK constraints
- Dart SDK: `>=3.11.0 <4.0.0`; Flutter: `>=3.3.0` (from `pubspec.yaml`).
- Runtime deps: `plugin_platform_interface`, `http`, `sqflite`, `path_provider`, `collection`. Keep the caret (`^`) constraint on pub dependencies; do not pin exact versions without reason.
- Dev deps: `flutter_test`, `flutter_lints` (v6). Analysis is governed by `analysis_options.yaml`.
- License: GPL-3.0. Do not relicense.
- Platform pattern: define the abstract API in the platform interface, provide the `MethodChannel` default, register it in the barrel.
- How features work: network capture via `HttpOverrides` (covers `http` and Dio's `HttpClient`); logging via Zone plus `debugPrint` override; memory/FPS via VM Service plus `addTimingsCallback` (v1.2.1+ uses real frame timestamps and `rasterFinish - buildStart` duration to catch GPU jank).
- Native: Android `android/src/main/kotlin/.../ZeroInspectorKitPlugin.kt` (package `com.zerolabsco.zero_inspector_kit`); iOS `ios/Classes/ZeroInspectorKitPlugin.swift`. Keep native changes minimal and matching the method channel contract.

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
- `dependabot-pr-bilingual.yml`: `actions/github-script@v7` appends a bilingual (EN-primary, ZH-secondary) summary to the **body** of Dependabot PRs only (`github.actor == 'dependabot[bot]'`, idempotent via marker). It does NOT touch the PR title or commit subject — those stay English per the Conventional Commits rule. When reviewing Dependabot PRs, verify the build passes, check changelogs for breaking changes on major bumps, and confirm the caret (`^`) constraint is preserved.
- `dart-format-fix.yml`: on PR `opened`/`synchronize`/`reopened` (and `workflow_dispatch` manual trigger), runs `dart format .` and, if it changed anything, auto-commits and pushes the fix back to the **same PR branch** as `github-actions[bot]`. Keeps style consistent without reviewer nudging. Note: uses `pull_request` (not `pull_request_target`) with `permissions: contents: write`; if branch protection blocks workflow pushes or requires signed commits, switch it to open a fix branch / post a comment instead.
- `link-check.yml`: on PR changes to `README.md`, `README_zh.md`, `CHANGELOG.md`, `docs/**` (and `workflow_dispatch` manual trigger), runs `lychee-action@v2` to scan those docs for dead/broken links and fails only on real broken links (mailto and common redirects/rate-limits are excluded). Use the Actions tab manual run to scan the default branch on demand.
- `pr-title-check.yml` details: allowed types are `feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert`; `requireScope` is `false`; PRs labeled `dependencies` or `github-actions` are ignored. The same type list applies to commit messages (Conventional Commits).
- `paths-ignore` skips user-facing docs (`README*.md`, `CHANGELOG.md`, `TODO.md`, `wiki/**`, `docs/**`) to save CI minutes, but it MUST NOT blanket-ignore all `**.md`. `AGENTS.md` and `.codebuddy/**` are intentionally kept out of `paths-ignore` so docs-only PRs still run the required checks and can merge (branch protection requires 3 passing checks; a skipped `ci.yml` would block the merge). Never reintroduce `'**.md'` to `paths-ignore`.

### Release and publish
1. Bump `version` in `pubspec.yaml` (semver; major bump for breaking public API).
2. Update `README.md` / `CHANGELOG.md` as needed.
3. Locally verify before pushing:
   - `flutter analyze` — must pass with no errors.
   - `flutter test` — all unit tests green.
   - `flutter pub publish --dry-run` — confirm the package scores well on `pana` and no files are unintentionally excluded.
4. Commit on a branch, open PR, merge to `main` after the 3 required checks pass.
5. Tag (drives publishing): `git tag vX.Y.Z <commit> && git push origin vX.Y.Z`. The `vX.Y.Z` tag — NOT a branch — triggers `pub-publish.yml`. Never name a branch `vX.Y.Z`; it collides with the tag refspec and breaks `git push`.
6. Archive branch (optional, for release snapshots): create `release/vX.Y.Z` from the tagged commit via explicit refspec to avoid the tag/branch collision, e.g. `git push origin <commit>:refs/heads/release/vX.Y.Z`. These branches are inert (no CI triggers on them) and serve only as frozen snapshots. Note: early versions `v1.1.0` and `v1.1.1` cannot be pushed as archive branches (their commits are rejected by the remote); those two versions are kept as tags only.
7. `pub-publish.yml` publishes via `k-paxian/dart-package-publisher@v1.6` using the `PUB_CREDENTIALS_JSON` secret (fields `accessToken`, `refreshToken`; set `flutter: true`). Do NOT pass OIDC fields (`idToken` / `tokenEndpoint` / `scopes`); the action does not support them and emits invalid-input warnings.
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
- [ ] For releases, bump `version`, update changelog, tag `vX.Y.Z` (triggers publish), and optionally push a `release/vX.Y.Z` archive branch via explicit refspec.
