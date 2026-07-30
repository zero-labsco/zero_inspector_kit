---
name: zero-inspector-kit
description: This skill should be used when working inside the zero_inspector_kit Flutter plugin repository - implementing features, fixing bugs, changing public API, opening pull requests, cutting releases, publishing to pub.dev, or updating the GitHub Pages docs. It encodes the project's architecture, coding conventions, and enforced GitHub workflows.
---

# Zero Inspector Kit

## Overview
This skill activates when working in the `zero_inspector_kit` Flutter plugin repository. The full, tool-agnostic project guidance (architecture, coding conventions, branch/PR/CI/release/docs workflows, and the new-feature checklist) is defined in `AGENTS.md` at the repository root.

`AGENTS.md` is read by CodeBuddy as well as other AI coding tools (Trae, Cursor, Claude Code, GitHub Copilot, Codex, etc.), so it is the single source of truth and this skill deliberately avoids duplicating it.

## How to use
1. Read `AGENTS.md` from the repository root.
2. Follow its architecture, conventions, and workflow rules for any task in this repo.
3. The public API surface, platform-channel pattern, and release procedure are all specified there.

This skill exists only so CodeBuddy auto-loads the project guide through the conventional-commits-aware trigger described in the frontmatter.
