#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "Checking plist..."
plutil -lint Info.plist

echo "Checking shell scripts..."
bash -n scripts/*.sh

echo "Checking Python helper..."
python3 -m py_compile translation/translate_local.py

echo "Checking source for machine-local paths..."
if command -v rg >/dev/null 2>&1; then
  forbidden_matches="$(rg -n '/Users/byrondaniels|argostranslate==1\.9\.6' \
    --glob '!scripts/verify.sh' \
    README.md scripts Sources translation Info.plist || true)"
else
  forbidden_matches="$(grep -R -n -E '/Users/byrondaniels|argostranslate==1\.9\.6' \
    --exclude 'verify.sh' \
    README.md scripts Sources translation Info.plist || true)"
fi
if [[ -n "$forbidden_matches" ]]; then
  printf '%s\n' "$forbidden_matches"
  echo "Found machine-local path or stale dependency pin." >&2
  exit 1
fi

echo "Checking whitespace..."
git diff --check

echo "Building lightweight app bundle..."
INSTALL_DEFAULT_MODEL=0 INSTALL_TRANSLATION=0 ./scripts/build_app.sh >/dev/null

echo "Running doctor..."
./scripts/doctor.sh

echo "Verification complete."
