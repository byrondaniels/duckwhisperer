#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PYTHON_BIN="${PYTHON_BIN:-}"
REQUESTED_PYTHON_BIN="$PYTHON_BIN"
ARGOS_TRANSLATE_SPEC="${ARGOS_TRANSLATE_SPEC:-argostranslate==1.11.0}"
SENTENCEPIECE_SPEC="${SENTENCEPIECE_SPEC:-sentencepiece==0.2.1}"
SUPPORT_ROOT="${DUCKWHISPERER_SUPPORT_DIR:-${LOCAL_WHISPERER_SUPPORT_DIR:-$HOME/Library/Application Support/Local Whisperer}}"
TRANSLATION_DIR="$SUPPORT_ROOT/Translation"
VENV_DIR="$TRANSLATION_DIR/.venv"
PACKAGE_DIR="$TRANSLATION_DIR/Packages"
DATA_HOME="$TRANSLATION_DIR/Data"
CACHE_HOME="$TRANSLATION_DIR/Cache"

python_is_supported() {
  "$1" - <<'PY' >/dev/null 2>&1
import sys
sys.exit(0 if (3, 11) <= sys.version_info[:2] < (3, 14) else 1)
PY
}

python_version() {
  "$1" - <<'PY'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")
PY
}

resolve_python_command() {
  local command_name="$1"
  command -v "$command_name" 2>/dev/null || true
}

find_supported_python() {
  local candidates=(
    "$PYTHON_BIN"
    /opt/homebrew/opt/python@3.13/bin/python3.13
    /opt/homebrew/bin/python3.13
    /usr/local/opt/python@3.13/bin/python3.13
    /usr/local/bin/python3.13
    /opt/homebrew/opt/python@3.12/bin/python3.12
    /opt/homebrew/bin/python3.12
    /usr/local/opt/python@3.12/bin/python3.12
    /usr/local/bin/python3.12
    /opt/homebrew/opt/python@3.11/bin/python3.11
    /opt/homebrew/bin/python3.11
    /usr/local/opt/python@3.11/bin/python3.11
    /usr/local/bin/python3.11
    "$(resolve_python_command python3.13)"
    "$(resolve_python_command python3.12)"
    "$(resolve_python_command python3.11)"
    "$(resolve_python_command python3)"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    [[ -n "$candidate" ]] || continue
    [[ -x "$candidate" ]] || continue
    if python_is_supported "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

if [[ -n "$PYTHON_BIN" && ! -x "$PYTHON_BIN" ]]; then
  resolved_python_bin="$(command -v "$PYTHON_BIN" 2>/dev/null || true)"
  if [[ -n "$resolved_python_bin" ]]; then
    PYTHON_BIN="$resolved_python_bin"
  else
    echo "PYTHON_BIN points to a non-executable path: $PYTHON_BIN" >&2
    exit 1
  fi
fi

if [[ -n "$REQUESTED_PYTHON_BIN" ]] && ! python_is_supported "$PYTHON_BIN"; then
  echo "PYTHON_BIN must be Python 3.11, 3.12, or 3.13. Got Python $(python_version "$PYTHON_BIN") at $PYTHON_BIN." >&2
  exit 1
fi

if ! PYTHON_BIN="$(find_supported_python)"; then
  cat >&2 <<'EOF'
DuckWhisperer translation needs Python 3.11, 3.12, or 3.13.

Install one with Homebrew, for example:
  brew install python@3.13

Or skip local translation setup:
  INSTALL_TRANSLATION=0 ./scripts/build_app.sh
EOF
  exit 1
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
for source, target in (("en", "fr"), ("en", "nl"), ("fr", "en"), ("nl", "en")):
    if source not in languages or target not in languages:
        missing.append((source, target))
        continue
    try:
        translation = languages[source].get_translation(languages[target])
    except Exception:
        translation = None
    if translation is None:
        missing.append((source, target))

sys.exit(1 if missing else 0)
PY
}

if translation_ready; then
  echo "Local translation runtime already installed in $VENV_DIR"
  echo "Local translation models already installed in $DATA_HOME"
  exit 0
fi

if [[ -x "$VENV_DIR/bin/python" ]] && ! python_is_supported "$VENV_DIR/bin/python"; then
  echo "Removing incompatible translation runtime created with Python $(python_version "$VENV_DIR/bin/python")."
  rm -rf "$VENV_DIR"
fi

if [[ ! -x "$VENV_DIR/bin/python" ]]; then
  echo "Creating translation runtime with $PYTHON_BIN (Python $(python_version "$PYTHON_BIN"))."
  "$PYTHON_BIN" -m venv "$VENV_DIR"
fi

if ! "$VENV_DIR/bin/python" -c 'import argostranslate' >/dev/null 2>&1; then
  if ! "$VENV_DIR/bin/python" -m pip install \
    --no-cache-dir \
    --only-binary=:all: \
    "$ARGOS_TRANSLATE_SPEC" \
    "$SENTENCEPIECE_SPEC"; then
    cat >&2 <<EOF
DuckWhisperer could not install the local translation runtime from binary wheels.

Python used:
  $("$VENV_DIR/bin/python" -c 'import sys; print(sys.version)')

Try installing Homebrew Python 3.13 or 3.12, then rerun:
  brew install python@3.13
  PYTHON_BIN=/opt/homebrew/bin/python3.13 ./scripts/setup_local_translation.sh

You can still install and use transcription without translation:
  INSTALL_TRANSLATION=0 ./scripts/install_app.sh
EOF
    exit 1
  fi
fi

curl -fL -o "$PACKAGE_DIR/translate-en_fr-1_9.argosmodel" \
  https://argos-net.com/v1/translate-en_fr-1_9.argosmodel
curl -fL -o "$PACKAGE_DIR/translate-en_nl-1_8.argosmodel" \
  https://argos-net.com/v1/translate-en_nl-1_8.argosmodel
curl -fL -o "$PACKAGE_DIR/translate-fr_en-1_9.argosmodel" \
  https://argos-net.com/v1/translate-fr_en-1_9.argosmodel
curl -fL -o "$PACKAGE_DIR/translate-nl_en-1_8.argosmodel" \
  https://argos-net.com/v1/translate-nl_en-1_8.argosmodel

XDG_DATA_HOME="$DATA_HOME" \
XDG_CACHE_HOME="$CACHE_HOME" \
"$VENV_DIR/bin/python" -c \
  "from pathlib import Path; from argostranslate import package; [package.install_from_path(str(path)) for path in sorted(Path('$PACKAGE_DIR').glob('*.argosmodel'))]"

rm -f "$PACKAGE_DIR"/translate-*.argosmodel

echo "Local translation runtime installed in $VENV_DIR"
echo "Local translation models installed in $DATA_HOME"
