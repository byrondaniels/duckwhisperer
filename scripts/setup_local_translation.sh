#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-}"
SUPPORT_ROOT="${DUCKWHISPERER_SUPPORT_DIR:-${LOCAL_WHISPERER_SUPPORT_DIR:-$HOME/Library/Application Support/Local Whisperer}}"
TRANSLATION_DIR="$SUPPORT_ROOT/Translation"
VENV_DIR="$TRANSLATION_DIR/.venv"
PACKAGE_DIR="$TRANSLATION_DIR/Packages"
DATA_HOME="$TRANSLATION_DIR/Data"
CACHE_HOME="$TRANSLATION_DIR/Cache"

if [[ -z "$PYTHON_BIN" ]]; then
  if [[ -x /opt/homebrew/opt/python@3.11/bin/python3.11 ]]; then
    PYTHON_BIN=/opt/homebrew/opt/python@3.11/bin/python3.11
  elif command -v python3.11 >/dev/null 2>&1; then
    PYTHON_BIN=python3.11
  else
    PYTHON_BIN=python3
  fi
fi

mkdir -p "$PACKAGE_DIR" "$DATA_HOME" "$CACHE_HOME"

translation_ready() {
  [[ -x "$VENV_DIR/bin/python" ]] || return 1
  XDG_DATA_HOME="$DATA_HOME" \
  XDG_CACHE_HOME="$CACHE_HOME" \
  "$VENV_DIR/bin/python" - <<'PY'
import sys

try:
    from argostranslate import translate
except Exception:
    sys.exit(1)

languages = {language.code: language for language in translate.get_installed_languages()}
missing = []
for source, target in (("en", "fr"), ("en", "nl")):
    if source not in languages or target not in languages:
        missing.append((source, target))
        continue
    try:
        languages[source].get_translation(languages[target])
    except Exception:
        missing.append((source, target))

sys.exit(1 if missing else 0)
PY
}

if translation_ready; then
  echo "Local translation runtime already installed in $VENV_DIR"
  echo "Local translation models already installed in $DATA_HOME"
  exit 0
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

if ! "$VENV_DIR/bin/python" -c 'import argostranslate' >/dev/null 2>&1; then
  "$VENV_DIR/bin/python" -m pip install --no-cache-dir 'argostranslate==1.9.6'
fi

curl -L -o "$PACKAGE_DIR/translate-en_fr-1_9.argosmodel" \
  https://argos-net.com/v1/translate-en_fr-1_9.argosmodel
curl -L -o "$PACKAGE_DIR/translate-en_nl-1_8.argosmodel" \
  https://argos-net.com/v1/translate-en_nl-1_8.argosmodel

XDG_DATA_HOME="$DATA_HOME" \
XDG_CACHE_HOME="$CACHE_HOME" \
"$VENV_DIR/bin/python" -c \
  "from pathlib import Path; from argostranslate import package; [package.install_from_path(str(path)) for path in sorted(Path('$PACKAGE_DIR').glob('*.argosmodel'))]"

rm -f "$PACKAGE_DIR"/translate-*.argosmodel

echo "Local translation runtime installed in $VENV_DIR"
echo "Local translation models installed in $DATA_HOME"
