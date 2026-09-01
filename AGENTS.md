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

### Pull request body template / PR 正文模板

AI coding agents (CodeBuddy, Trae, Cursor, Claude Code, GitHub Copilot, Codex, etc.) and contributors SHOULD follow the body template below when opening PRs. Keep the `###` section structure; fill in real content. Use English as the primary language and Chinese as the secondary language (EN-primary, ZH-secondary) for each section. Brand the assistant with **Zero Buddy** (two words, NOT "ZeroBuddy") at the end.

AI 协作工具（CodeBuddy、Trae、Cursor、Claude Code、GitHub Copilot、Codex 等）与贡献者开 PR 时应遵循以下正文模板。保留 `###` 章节结构并填入真实内容。每个章节采用英文为主、中文为辅（EN-primary, ZH-secondary）。文末以 **Zero Buddy**（两个单词，不要写成 "ZeroBuddy"）署名。

```markdown
### Summary / 摘要

<one-line plain-English summary> + <对应中文一句话摘要>

### Changes / 变更

- <change bullet, EN> / <中文说明>
- <change bullet, EN> / <中文说明>

### Context / 背景

<why this change is needed, EN> / <改动背景的中文说明>

### Checklist / 检查项

- [ ] Title follows Conventional Commits / 标题符合约定式提交
- [ ] CI checks pass after merge / 合入后 CI 通过

## Test plan

- [ ] <how to verify, EN> / <验证方式>

🤖 Generated with [Zero Buddy](https://www.zerolabsco.com)
```

Notes / 说明:
- The PR **title** stays English-only and MUST follow Conventional Commits (enforced by `pr-title-check.yml`). Bilingual content goes in the body only.
  PR **标题**仅用英文，且必须符合约定式提交（`pr-title-check.yml` 强制校验）。双语内容只放在正文。
- For Dependabot PRs, do NOT author the body manually — `dependabot-pr-bilingual.yml` auto-appends the bilingual summary (see CI section).
  Dependabot 的 PR 不要手动写正文，由 `dependabot-pr-bilingual.yml` 自动追加双语摘要（见 CI 段）。

### CI
- `ci.yml`: `actions/checkout@v7`, `subosito/flutter-action@v2`, `actions/cache@v5` (pub cache keyed on `pubspec.lock` plus `example/pubspec.lock`); runs `flutter analyze`, `flutter test`, and `pana` score check.
- `stale.yml`: `actions/stale@v11` marks stale issues/PRs.
- `dependabot-pr-bilingual.yml`: `actions/github-script@v7` appends a bilingual (EN-primary, ZH-secondary) summary to the **body** of Dependabot PRs only (`github.actor == 'dependabot[bot]'`, idempotent via marker). It does NOT touch the PR title or commit subject — those stay English per the Conventional Commits rule. When reviewing Dependabot PRs, verify the build passes, check changelogs for breaking changes on major bumps, and confirm the caret (`^`) constraint is preserved.
- `dart-format-fix.yml`: on PR `opened`/`synchronize`/`reopened` (and `workflow_dispatch` manual trigger), runs `dart format .` and, if it changed anything, auto-commits and pushes the fix back to the **same PR branch** as `github-actions[bot]`. Keeps style consistent without reviewer nudging. Note: uses `pull_request` (not `pull_request_target`) with `permissions: contents: write`; if branch protection blocks workflow pushes or requires signed commits, switch it to open a fix branch / post a comment instead.
- `link-check.yml`: on PR changes to `README.md`, `README_zh.md`, `CHANGELOG.md`, `docs/**` (and `workflow_dispatch` manual trigger), runs `lychee-action@v2` to scan those docs for dead/broken links and fails only on real broken links (mailto and common redirects/rate-limits are excluded). Use the Actions tab manual run to scan the default branch on demand.
- `pr-title-check.yml` details: allowed types are `feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert`; `requireScope` is `false`; PRs labeled `dependencies` or `github-actions` are ignored. The same type list applies to commit messages (Conventional Commits).
- `paths-ignore` skips pure assets/non-package files (images `**.png`/`**.jpg`/`**gif`/`**webp`/`**svg`/`**ico`, `**.txt`, `**.gitignore`, `LICENSE`, example build artifacts, etc.) but it MUST NOT blanket-ignore all `**.md` or `docs/**`. `README*.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, `TODO.md`, `docs/**` are intentionally **kept OUT of `paths-ignore`** so docs-only PRs still trigger the `ci.yml` workflow — otherwise the entire workflow would be skipped and the branch-protection required checks would never appear (yellow), blocking merge.
- Whether a triggered run actually executes the heavy jobs is decided by the `path-filter` job's `code` output:
  - The `code` list contains **only code paths** (`lib/**`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `test/**`, `example/lib/**`, `example/pubspec.yaml`, `example/pubspec.lock`, `example/analysis_options.yaml`, `.github/workflows/ci.yml`).
  - A **docs/asset-only PR** (any `*.md` / `*.yml` / `*.txt` / `docs/**` / images / `LICENSE`) matches no entry in the `code` list → `code=false` → `Analyze & Test` and `Pana Score Check` **skip green** (pana NOT run), satisfying branch protection so the PR can merge.
  - A **docs + code PR** (also touches any code path above) → `code=true` → runs the real `flutter analyze` / `flutter test` / `pana` jobs.
  - The only non-code exception kept in the `code` list is `.github/workflows/ci.yml` (CI config changes, e.g. Dependabot action bumps, must be validated).
- Never reintroduce `'**.md'` or `'docs/**'` to `paths-ignore` — it would skip the whole workflow and block docs-only PRs from merging.

### Release and publish
1. Bump `version` in `pubspec.yaml` (semver; major bump for breaking public API).
   **Mandatory version-bump checklist — every one of these MUST be updated to the new version `X.Y.Z` (and the old version string removed). Missing any of them is a recurring, real mistake — verify each explicitly, do not assume a previous pass covered them:**
   - [ ] `pubspec.yaml` → `version: X.Y.Z`
   - [ ] `ios/zero_inspector_kit.podspec` → `s.version = 'X.Y.Z'` (this file is often stale; always check it)
   - [ ] `README.md`:
     - [ ] the `^X.Y.Z` dependency constraint in the install snippet
     - [ ] the `` `X.Y.Z` `` placeholder in "install from GitHub" (replace `X.Y.Z` with the version you need)
     - [ ] the `ref: release/vX.Y.Z` in the GitHub install git block (use the `release/vX.Y.Z` archive **branch**, NOT the `vX.Y.Z` tag — the tag collides with branch refspec and breaks `git push`)
     - [ ] the "🔔 Upgrade recommended" callout — briefly summarize what the **current** release changed and recommend upgrading to the latest version (`^X.Y.Z`); it must **NOT** mention or reference previous versions (no "on top of vX.(Y-1)'s …", no feature/changelog recap of older releases). Each release, bump only the literal latest version token and update the one-line summary of the current change, e.g. `> **🔔 Upgrade recommended:** This release fixes multi-line log reassembly so split logs no longer render out of order. All users are encouraged to upgrade to the latest version (^X.Y.Z).`
     - [ ] `README_zh.md`: same spots as `README.md` (`^X.Y.Z`, `` `X.Y.Z` `` placeholder, `ref: release/vX.Y.Z`, and the "🔔 推荐升级：" callout). The callout should briefly summarize what the current release changed and recommend the latest version; it must not reference previous versions.
   - [ ] `website/pages/*.md`: the install snippet uses the `__ZIK_VERSION__` placeholder; it is auto-filled from `pubspec.yaml` by `website/scripts/sync-docs.mjs`, so bumping `pubspec.yaml` alone is enough (do NOT hardcode a version there).
   - [ ] `CHANGELOG.md`: add a new `## X.Y.Z` section at the top describing the changes.
   - **Changelog scope rule / 变更日志范围规则:** Only changes to `lib/` (i.e. published-package runtime behavior) earn a CHANGELOG entry. Pure documentation updates (`README*.md`, `website/`, `docs/`) and `example/` changes must NOT get a CHANGELOG entry — they do not change the released package's runtime behavior. The single exception is a **pure version-bump commit**: bumping the version legitimately updates the CHANGELOG (and the doc version strings) as part of cutting the release, which is allowed. / 只有 `lib/` 的改动（即已发布包的运行行为）才进 CHANGELOG；纯文档（`README*.md`、`website/`、`docs/`）与 `example/` 的改动不应写进 CHANGELOG——它们不改变发布包的运行行为。唯一的例外是「单纯 bump 版本」的提交：为发版而更新 CHANGELOG（及文档版本号）是允许的。
   - Grep sanity check before committing: `grep -rn "old_version" README.md README_zh.md website/pages` must return NOTHING (only legitimate historical prose may remain; the `__ZIK_VERSION__` placeholder is expected and is not a real version).
   **Website (Nextra docs site):** `website/` is built and synced to `docs/` automatically by the `pre-commit` hook (`website/scripts/sync-docs.mjs`). Version references in `website/pages/*.md` use the `__ZIK_VERSION__` placeholder, which is filled from `pubspec.yaml` at build time — bumping `pubspec.yaml` propagates to the site automatically. Never edit `docs/` by hand; it is regenerated on every commit that touches `website/`.
2. Update `README.md` / `CHANGELOG.md` as needed.
3. Locally verify before pushing:
   - `dart format .` — must report no changes. The `dart-format-fix.yml` CI workflow auto-commits any formatting diff back to the PR branch, so keep the tree formatted locally to avoid surprise commits.
   - `flutter analyze` — must pass with no errors.
   - `flutter test` — all unit tests green.
   - `flutter pub publish --dry-run` — confirm the package scores well on `pana` and no files are unintentionally excluded.
4. Commit on a branch, open PR, merge to `main` after the 3 required checks pass.
5. Tag (drives publishing): `git tag vX.Y.Z <commit> && git push origin vX.Y.Z`. The `vX.Y.Z` tag — NOT a branch — triggers `pub-publish.yml`. Never name a branch `vX.Y.Z`; it collides with the tag refspec and breaks `git push`.
6. Archive branch (optional, for release snapshots): create `release/vX.Y.Z` from the tagged commit via explicit refspec to avoid the tag/branch collision, e.g. `git push origin <commit>:refs/heads/release/vX.Y.Z`. These branches are inert (no CI triggers on them) and serve only as frozen snapshots. The remote `v*` archive branches were renamed to `release/v*` to prevent tag/branch refspec ambiguity.
   - 远程 `v*` 归档分支已重命名为 `release/v*` 以避免 tag 与分支的 refspec 歧义。
7. `pub-publish.yml` publishes via `k-paxian/dart-package-publisher@v1.6` using the `PUB_CREDENTIALS_JSON` secret (fields `accessToken`, `refreshToken`; set `flutter: true`). Do NOT pass OIDC fields (`idToken` / `tokenEndpoint` / `scopes`); the action does not support them and emits invalid-input warnings.
   - Note: `k-paxian` internally uses older actions that emit Node 20 deprecation warnings. This is accepted (B1 decision); functionality is unaffected.

### Pub publish validation pitfalls (observed during v1.3.0)
`dart pub publish` (run by `pub-publish.yml`) performs validation that FAILS the build (exit 65) on certain warnings. The following were hit and the fixes applied. Re-verify with `flutter pub publish --dry-run` before tagging.

- **Checked-in file ignored by `.gitignore`** — Pub flags any file that is BOTH in the git index AND matched by `.gitignore` (error message points at e.g. `.codebuddy/skills/zero-inspector-kit/SKILL.md`). Fix: do NOT try to solve this with `.pubignore` (pub's "checked-in but ignored" check ignores `.pubignore`); instead **untrack** the path so it is no longer "checked in":
  `git rm -r --cached .codebuddy` (file stays on disk, remains gitignored, no longer in the index). Keep `.codebuddy/` ignored in `.gitignore` — it is personal IDE data.
- **Top-level `docs/` directory (plural name)** — Pub warns that plural top-level dirs aren't recognized by its layout convention and suggests renaming to `doc/`. Do NOT rename: `docs/` is the GitHub Pages site (served from `docs/github-pages`), renaming breaks the Pages workflow. Fix: exclude it from the package via `.pubignore` (`docs/`).
- **`.pubignore` usage** — Add a `.pubignore` at repo root to keep repo-internal content out of the published tarball. Recommended entries: `docs/`, `.codebuddy/`, `AGENTS.md`, `CONTRIBUTING.md`, `TODO.md`. `.pubignore` is respected by `dart pub publish` but does NOT silence the "checked-in but gitignored" conflict above.

When re-tagging after a fix, force-update both the `vX.Y.Z` tag and the `release/vX.Y.Z` archive branch to the new commit so the publish job runs against the corrected tree.

### Documentation site (GitHub Pages)
- Source content lives in `docs/`. The legacy `wiki/` directory was removed; `docs/` is now the single source of truth.
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
- [ ] For user-facing changes, update `README.md` and the `website/` source (the `docs/` site is built and synced automatically by the pre-commit hook).
- [ ] For releases, bump `version` AND follow the **Mandatory version-bump checklist** under "Release and publish" above (pubspec, iOS podspec, README.md, README_zh.md, `website/pages/*.md` via the `__ZIK_VERSION__` placeholder, CHANGELOG.md — grep for the old version string to confirm nothing is left). Tag `vX.Y.Z` (triggers publish), and optionally push a `release/vX.Y.Z` archive branch via explicit refspec.
