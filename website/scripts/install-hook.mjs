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
 * Safe to run repeatedly. Does nothing destructive.
 */

import {
  copyFileSync,
  chmodSync,
  existsSync,
  mkdirSync,
} from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(scriptDir, '..', '..');
const template = join(scriptDir, 'pre-commit');
const hooksDir = join(repoRoot, '.git', 'hooks');
const target = join(hooksDir, 'pre-commit');

if (!existsSync(template)) {
  console.error('[install-hook] Missing hook template:', template);
  process.exit(1);
}

mkdirSync(hooksDir, { recursive: true });
copyFileSync(template, target);

// Make executable on POSIX; on Windows the .sh is run by git's shell, chmod is a no-op-safe call.
try {
  chmodSync(target, 0o755);
} catch {}

// Verify git can find the hook path (basic sanity).
try {
  execSync('git rev-parse --git-dir', { cwd: repoRoot, stdio: 'pipe' });
} catch {
  console.error('[install-hook] Not inside a git repository?');
  process.exit(1);
}

console.log('[install-hook] Pre-commit hook installed at .git/hooks/pre-commit');
console.log('[install-hook] It will build & sync the docs site on relevant commits.');
