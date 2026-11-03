#!/usr/bin/env bash
# normalize-eol.sh — force LF line endings (no BOM) across the repository.
# 强制全仓库 LF 换行（无 BOM）。
#
# Cross-platform companion to tool/normalize-eol.ps1 (Windows / PowerShell).
# Mirrors the approach used in flutter_rtc_link: the repo enforces LF via
# `.gitattributes` (`* text=auto eol=lf`), and this script repairs the working
# tree (editors on Windows tend to write CRLF) before a commit. Run it after
# adding or editing files so nothing CRLF reaches git.
# 与 flutter_rtc_link 的做法一致：仓库通过 `.gitattributes` 强制 LF，本脚本在提交前
# 修复工作区（Windows 上的编辑器常写出 CRLF）。新增/修改文件后跑一次即可。
set -euo pipefail

# Resolve the repo root (parent of the tool/ directory).
root="$(cd "$(dirname "$0")/.." && pwd)"

# Ensure perl is available — it does the CRLF→LF and BOM stripping portably.
if ! command -v perl >/dev/null 2>&1; then
  echo "error: 'perl' is required but not found in PATH." >&2
  exit 1
fi

fixed=0
# shellcheck disable=SC2044
while IFS= read -r -d '' f; do
  # Detect CRLF/CR or a UTF-8 BOM (first three bytes EF BB BF) before rewriting.
  if grep -q $'\r' "$f" || head -c3 "$f" | grep -q $'\xEF\xBB\xBF'; then
    perl -i -pe 's/\r\n/\n/g; s/\r/\n/g; s/^\xEF\xBB\xBF//' "$f"
    fixed=$((fixed + 1))
    echo "normalized: $f"
  fi
done < <(find "$root" \
  -type d \( -name .git -o -name build -o -name .dart_tool -o -name node_modules -o -name .next \) -prune -o \
  -type f \( \
    -name '*.dart' -o -name '*.yaml' -o -name '*.yml' -o -name '*.md' -o \
    -name '*.kt' -o -name '*.swift' -o -name '*.gradle' -o -name '*.json' -o \
    -name '*.podspec' -o -name '*.mjs' -o -name '*.tsx' -o -name '*.js' -o \
    -name '*.plist' -o -name '*.xml' -o -name '*.properties' -o -name '*.txt' -o \
    -name '*.toml' -o -name '*.gitignore' -o -name '*.gitattributes' -o -name '*.pubignore' \
  \) -print0)

echo "done, $fixed file(s) normalized to LF"
