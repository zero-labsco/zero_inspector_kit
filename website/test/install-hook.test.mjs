#!/usr/bin/env node
/**
 * Regression tests for website/scripts/install-hook.mjs.
 *
 * Verifies that the installer:
 *   - creates the pre-commit hook on first run
 *   - is idempotent when the hook already matches the template
 *   - backs up (rather than silently overwrites) an existing custom hook
 *   - overwrites without backup when --force is passed
 */

import { execSync } from 'node:child_process';
import {
  cpSync,
  existsSync,
  mkdtempSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const __dirname = dirname(fileURLToPath(import.meta.url));
const repoRoot = join(__dirname, '..', '..');
const scriptSrc = join(repoRoot, 'website', 'scripts', 'install-hook.mjs');
const templateSrc = join(repoRoot, 'website', 'scripts', 'pre-commit');

function makeTempRepo() {
  const dir = mkdtempSync(join(tmpdir(), 'zik-install-hook-'));
  try {
    execSync('git init', { cwd: dir, stdio: 'ignore' });
    mkdirSync(join(dir, 'website', 'scripts'), { recursive: true });
    cpSync(scriptSrc, join(dir, 'website', 'scripts', 'install-hook.mjs'));
    cpSync(templateSrc, join(dir, 'website', 'scripts', 'pre-commit'));
    return dir;
  } catch (err) {
    rmSync(dir, { recursive: true, force: true });
    throw err;
  }
}

function hookPath(dir) {
  return join(dir, '.git', 'hooks', 'pre-commit');
}

function runInstaller(dir, args = '') {
  return execSync(
    `node ${join(dir, 'website', 'scripts', 'install-hook.mjs')} ${args}`,
    { cwd: dir, encoding: 'utf8', stdio: 'pipe' },
  );
}

function listBackups(dir) {
  const hooksDir = join(dir, '.git', 'hooks');
  if (!existsSync(hooksDir)) return [];
  return readdirSync(hooksDir).filter((n) => n.startsWith('pre-commit.backup-'));
}

const tests = [];
function test(name, fn) {
  tests.push({ name, fn });
}

test('installs hook into a fresh git repository', () => {
  const dir = makeTempRepo();
  try {
    const out = runInstaller(dir);
    assert.ok(existsSync(hookPath(dir)), 'pre-commit hook should be created');
    assert.ok(out.includes('installed'), 'installer should report success');
    assert.strictEqual(
      readFileSync(hookPath(dir), 'utf8'),
      readFileSync(templateSrc, 'utf8'),
      'installed hook should match template',
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('is idempotent when hook already matches template', () => {
  const dir = makeTempRepo();
  try {
    runInstaller(dir);
    const before = readFileSync(hookPath(dir), 'utf8');
    const out = runInstaller(dir);
    const after = readFileSync(hookPath(dir), 'utf8');
    assert.strictEqual(before, after, 'hook should be unchanged');
    assert.ok(out.includes('already up to date'), 'installer should report idempotency');
    assert.deepStrictEqual(listBackups(dir), [], 'should not create backup files');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('backs up an existing custom hook instead of overwriting it', () => {
  const dir = makeTempRepo();
  const custom = '#!/bin/sh\necho custom\n';
  try {
    runInstaller(dir);
    writeFileSync(hookPath(dir), custom, { mode: 0o755 });

    const out = runInstaller(dir);
    const backups = listBackups(dir);
    assert.ok(backups.length > 0, 'installer should create a backup');
    assert.strictEqual(
      readFileSync(join(dir, '.git', 'hooks', backups[0]), 'utf8'),
      custom,
      'backup should contain the original custom hook',
    );
    assert.strictEqual(
      readFileSync(hookPath(dir), 'utf8'),
      readFileSync(templateSrc, 'utf8'),
      'target should now contain the template',
    );
    assert.ok(out.includes('backed up'), 'installer should mention the backup');
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('--force overwrites an existing custom hook without creating a backup', () => {
  const dir = makeTempRepo();
  const custom = '#!/bin/sh\necho custom\n';
  try {
    runInstaller(dir);
    writeFileSync(hookPath(dir), custom, { mode: 0o755 });

    runInstaller(dir, '--force');
    assert.deepStrictEqual(listBackups(dir), [], 'should not create backup files with --force');
    assert.strictEqual(
      readFileSync(hookPath(dir), 'utf8'),
      readFileSync(templateSrc, 'utf8'),
      'target should contain the template',
    );
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

let failed = false;
for (const { name, fn } of tests) {
  try {
    fn();
    console.log(`  ✓ ${name}`);
  } catch (err) {
    failed = true;
    console.error(`  ✗ ${name}`);
    console.error(err.message);
  }
}

if (failed) {
  process.exit(1);
}
console.log(`\n${tests.length} install-hook tests passed.`);
