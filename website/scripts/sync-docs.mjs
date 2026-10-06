#!/usr/bin/env node
/**
 * sync-docs.mjs
 *
 * Builds the Nextra documentation site into `website/out/`.
 *
 * What it does:
 *   1. Detects whether this commit touches the website *source* (anything under
 *      website/ except website/out, website/.next, website/node_modules), or
 *      whether the pubspec.yaml version changed. If neither, it exits 0 without
 *      building.
 *   2. Reads the package version from pubspec.yaml (the single source of truth)
 *      and injects it into the `website/pages/*.md` placeholders
 *      (__ZIK_VERSION__).
 *   3. Runs `npm run build`, producing `website/out/`.
 *   4. Writes `website/out/.nojekyll`. GitHub Pages runs Jekyll by default,
 *      which silently drops every file or directory whose name starts with an
 *      underscore (for example `_next`, `_meta`) — that would strip all CSS and
 *      JS and leave the site unstyled.
 *   5. Restores the original `website/pages/*.md`. The placeholder stays in the
 *      repository; only the build output ever contains the real version.
 *
 * `website/out/` is what CI publishes to the `gh-pages` branch, see
 * .github/workflows/docs.yml. The repository no longer keeps a generated
 * `docs/` directory on `main`, so this script never writes into `docs/`.
 *
 * Flags:
 *   --ci       Build even when the working tree shows no website/pubspec
 *              changes. CI checks out a clean tree, where the change detection
 *              in step 1 would otherwise always skip.
 *   --dry-run  Print what would happen without building.
 *
 * The flags can also be set with the SYNC_DOCS_CI=1 / SYNC_DOCS_DRYRUN=1
 * environment variables. Safe to run manually.
 */

import { execSync } from 'node:child_process';
import {
  readdirSync,
  readFileSync,
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
// must still trigger a rebuild so the published site picks up the new version.
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

function writeNojekyll() {
  if (!existsSync(outDir)) {
    throw new Error('website/out does not exist — build may have failed');
  }
  // GitHub Pages runs Jekyll by default, which silently drops any file or
  // directory whose name begins with an underscore (e.g. _next, _meta). That
  // strips all CSS/JS from the static export and leaves the site unstyled.
  // An empty .nojekyll disables Jekyll so the build is served verbatim.
  writeFileSync(join(outDir, '.nojekyll'), '');
}

function main() {
  const dryRun =
    process.argv.includes('--dry-run') || process.env.SYNC_DOCS_DRYRUN === '1';
  // --ci forces a rebuild. CI runs on a clean checkout where neither the staged
  // nor the unstaged diff contains anything, so change detection would skip.
  const ci =
    process.argv.includes('--ci') || process.env.SYNC_DOCS_CI === '1';

  if (!ci && !websiteSourceChanged() && !pubspecVersionChanged()) {
    console.log(
      '[sync-docs] No website source or pubspec version changes — skipping build.',
    );
    return;
  }

  const version = getPubVersion();

  if (dryRun) {
    console.log(
      `[sync-docs][dry-run] Website source changed (v${version}). ` +
        `Would build website/out/ for publication to the gh-pages branch. ` +
        `Placeholder ${PLACEHOLDER} would become ${version}.`,
    );
    return;
  }

  console.log(
    `[sync-docs] Building site (v${version}) into website/out/ ...`,
  );

  injectVersion(version);
  try {
    execSync('npm run build', { cwd: websiteDir, stdio: 'inherit' });
    writeNojekyll();
    console.log(
      '[sync-docs] website/out/ is ready to publish to the gh-pages branch.',
    );
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
