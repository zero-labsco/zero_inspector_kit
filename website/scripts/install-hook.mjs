#!/usr/bin/env node
/**
 * install-hook.mjs
 *
 * Installs the Nextra pre-commit hook into the local git repository.
 * Run via `npm run setup-hook` (or `node website/scripts/install-hook.mjs`).
 *
 * It copies website/scripts/pre-commit (the tracked template) to
 * .git/hooks/pre-commit and makes it executable, so that committing
 * automatically builds & syncs the documentation site.
 *
 * Safe to run repeatedly: if the installed hook already matches the template it
 * is a no-op. If a different pre-commit hook already exists, it is backed up
 * before being replaced (use --force to skip the backup).
 */

import {
  copyFileSync,
  chmodSync,
  existsSync,
  mkdirSync,
  readFileSync,
} from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(scriptDir, '..', '..');
const template = join(scriptDir, 'pre-commit');

if (!existsSync(template)) {
  console.error('[install-hook] Missing hook template:', template);
  process.exit(1);
}

// Resolve the real hooks directory (handles worktrees and non-default git dirs)
// before doing anything that could touch the filesystem.
let hooksDir;
try {
  hooksDir = execSync('git rev-parse --git-path hooks', {
    cwd: repoRoot,
    stdio: 'pipe',
  })
    .toString()
    .trim();
} catch {
  console.error('[install-hook] Not inside a git repository?');
  process.exit(1);
}

const target = join(repoRoot, hooksDir, 'pre-commit');

// Protect an existing pre-commit hook from silent overwrite. If the target is
// already identical to the template, the install is a no-op (idempotent).
if (existsSync(target)) {
  const existing = readFileSync(target, 'utf8');
  const desired = readFileSync(template, 'utf8');
  if (existing === desired) {
    console.log('[install-hook] Pre-commit hook already up to date.');
    process.exit(0);
  }
  const force = process.argv.includes('--force');
  if (!force) {
    const backup = `${target}.backup-${Date.now()}`;
    copyFileSync(target, backup);
    console.log('[install-hook] Existing pre-commit hook backed up to:', backup);
  }
}

mkdirSync(dirname(target), { recursive: true });
copyFileSync(template, target);

// Make executable on POSIX; on Windows the .sh is run by git's shell, chmod is a no-op-safe call.
try {
  chmodSync(target, 0o755);
} catch {}

console.log('[install-hook] Pre-commit hook installed at', target);
console.log('[install-hook] It will build & sync the docs site on relevant commits.');
