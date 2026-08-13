#!/usr/bin/env node
/**
 * sync-docs.mjs
 *
 * Git pre-commit helper for the Nextra documentation site.
 *
 * What it does:
 *   1. Detects whether this commit touches the website *source* (anything under
 *      website/ except website/out, website/.next, website/node_modules).
 *   2. If nothing changed -> exits 0 immediately (no build, docs/ untouched).
 *   3. If something changed:
 *        a. Reads the package version from pubspec.yaml (single source of truth)
 *           and injects it into website/pages/*.md placeholders (__ZIK_VERSION__).
 *        b. Runs `npm run build` to produce out/.
 *        c. Replaces the contents of docs/ with website/out/ (this removes the
 *           old docsify files: index.html, _Sidebar.md, _Footer.md, etc.).
 *        d. Stages the new docs/ so the commit includes the built site.
 *        e. Restores the original website/pages/*.md (placeholders are kept in
 *           the repo; only the build output ever contains the real version).
 *
 * Run automatically via .git/hooks/pre-commit. Safe to run manually too.
 */

import { execSync } from 'node:child_process';
import {
  cpSync,
  readdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
  existsSync,
} from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const websiteDir = join(scriptDir, '..');
const repoRoot = join(scriptDir, '..', '..');
const pagesDir = join(websiteDir, 'pages');
const outDir = join(websiteDir, 'out');
const docsDir = join(repoRoot, 'docs');

const PLACEHOLDER = '__ZIK_VERSION__';

function run(cmd, cwd = repoRoot) {
  return execSync(cmd, { cwd, stdio: 'pipe' }).toString().trim();
}

function getPubVersion() {
  const pub = readFileSync(join(repoRoot, 'pubspec.yaml'), 'utf8');
  const m = pub.match(/^version:\s*([0-9]+\.[0-9]+\.[0-9]+)/m);
  if (!m) throw new Error('Could not find version in pubspec.yaml');
  return m[1];
}

function websiteSourceChanged() {
  let files = '';
  try {
    files += run('git diff --cached --name-only') + '\n';
  } catch {}
  try {
    files += run('git diff --name-only') + '\n';
  } catch {}
  const ignored = ['website/out/', 'website/.next/', 'website/node_modules/'];
  return files
    .split('\n')
    .filter(Boolean)
    .some(
      (f) =>
        f.startsWith('website/') && !ignored.some((p) => f.startsWith(p)),
    );
}

// The package version in pubspec.yaml is the single source of truth for the
// website's version string. Bumping it alone (without touching website/ source)
// must still trigger a rebuild so docs/ picks up the new version.
function pubspecVersionChanged() {
  let staged = '';
  try {
    staged = run('git diff --cached -- pubspec.yaml');
  } catch {}
  if (staged) return true;
  try {
    return run('git diff -- pubspec.yaml') !== '';
  } catch {
    return false;
  }
}

function collectMd(dir) {
  const out = [];
  for (const e of readdirSync(dir, { withFileTypes: true })) {
    const p = join(dir, e.name);
    if (e.isDirectory()) out.push(...collectMd(p));
    else if (e.name.endsWith('.md')) out.push(p);
  }
  return out;
}

const backups = new Map();

function injectVersion(version) {
  for (const f of collectMd(pagesDir)) {
    const original = readFileSync(f, 'utf8');
    backups.set(f, original);
    const injected = original.split(PLACEHOLDER).join(version);
    if (injected !== original) writeFileSync(f, injected);
  }
}

function restoreOriginals() {
  for (const [f, original] of backups) writeFileSync(f, original);
  backups.clear();
}

function syncOutToDocs() {
  if (!existsSync(outDir)) {
    throw new Error('website/out does not exist — build may have failed');
  }
  for (const entry of readdirSync(docsDir)) {
    rmSync(join(docsDir, entry), { recursive: true, force: true });
  }
  cpSync(outDir, docsDir, { recursive: true });
}

function main() {
  const dryRun =
    process.argv.includes('--dry-run') || process.env.SYNC_DOCS_DRYRUN === '1';

  if (!websiteSourceChanged() && !pubspecVersionChanged()) {
    console.log(
      '[sync-docs] No website source or pubspec version changes — skipping build.',
    );
    return;
  }

  const version = getPubVersion();

  if (dryRun) {
    console.log(
      `[sync-docs][dry-run] Website source changed (v${version}). ` +
        `Would build and sync website/out/ -> docs/. ` +
        `Placeholder ${PLACEHOLDER} would become ${version}.`,
    );
    return;
  }

  console.log(
    `[sync-docs] Website source changed (v${version}) — building and syncing to docs/`,
  );

  injectVersion(version);
  try {
    execSync('npm run build', { cwd: websiteDir, stdio: 'inherit' });
    syncOutToDocs();
    run('git add docs/');
    console.log('[sync-docs] docs/ updated and staged.');
  } finally {
    restoreOriginals();
  }
}

try {
  main();
} catch (err) {
  console.error('[sync-docs] FAILED:', err.message);
  process.exit(1);
}
