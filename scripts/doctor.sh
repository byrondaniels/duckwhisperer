#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPPORT_ROOT="${DUCKWHISPERER_SUPPORT_DIR:-${LOCAL_WHISPERER_SUPPORT_DIR:-$HOME/Library/Application Support/Local Whisperer}}"
TRANSLATION_DIR="$SUPPORT_ROOT/Translation"
MODEL_DIR="$SUPPORT_ROOT/Models"
APP_PATH="${DUCKWHISPERER_INSTALL_DIR:-/Applications}/DuckWhisperer.app"
FRAMEWORK_DIR="$ROOT_DIR/vendor/whisper-xcframework/build-apple/whisper.xcframework"

failures=0
warnings=0

pass() {
  printf 'ok   %s\n' "$1"
}

warn() {
  warnings=$((warnings + 1))
  printf 'warn %s\n' "$1"
}

fail() {
  failures=$((failures + 1))
  printf 'fail %s\n' "$1"
}

command_path() {
  command -v "$1" 2>/dev/null || true
}

require_command() {
  local name="$1"
  local hint="$2"
  if [[ -n "$(command_path "$name")" ]]; then
    pass "$name is available"
  else
    fail "$name is missing. $hint"
  fi
}

python_version() {
  "$1" - <<'PY' 2>/dev/null
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}")
PY
}

python_is_supported() {
  "$1" - <<'PY' >/dev/null 2>&1
import sys
sys.exit(0 if (3, 11) <= sys.version_info[:2] < (3, 14) else 1)
PY
}

resolve_python_command() {
  command -v "$1" 2>/dev/null || true
}

find_supported_python() {
  local candidates=(
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

check_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    fail "DuckWhisperer requires macOS."
    return
  fi

  local version major
  version="$(sw_vers -productVersion 2>/dev/null || true)"
  major="${version%%.*}"
  if [[ "$major" =~ ^[0-9]+$ ]] && (( major >= 13 )); then
    pass "macOS $version is supported"
  else
    fail "macOS 13 or newer is required. Found: ${version:-unknown}"
  fi
}

check_backend() {
  if [[ -d "$FRAMEWORK_DIR" ]]; then
    pass "whisper.cpp framework is bootstrapped"
  else
    warn "whisper.cpp framework is missing. Run ./scripts/bootstrap_backend.sh before building."
  fi
}

check_default_model() {
  if [[ -f "$MODEL_DIR/ggml-small.en.bin" ]]; then
    pass "default Small English model is installed"
  else
    warn "default Small English model is not installed. Run ./scripts/setup_default_model.sh or let install_app.sh download it."
  fi
}

check_translation() {
  local python
  if python="$(find_supported_python)"; then
    pass "translation setup can use Python $(python_version "$python") at $python"
  else
    warn "no Python 3.11, 3.12, or 3.13 found; local translation install will be skipped/fail until one is installed"
  fi

  if [[ -x "$TRANSLATION_DIR/.venv/bin/python" ]]; then
    local runtime_python
    runtime_python="$TRANSLATION_DIR/.venv/bin/python"
    if python_is_supported "$runtime_python"; then
      pass "installed translation runtime uses Python $(python_version "$runtime_python")"
    else
      warn "installed translation runtime uses unsupported Python $(python_version "$runtime_python"); rerun scripts/setup_local_translation.sh"
    fi
  else
    warn "local translation runtime is not installed; this is fine unless French/Dutch output is needed"
  fi
}

check_installed_app() {
  if [[ -d "$APP_PATH" ]]; then
    pass "installed app exists at $APP_PATH"
  else
    warn "installed app was not found at $APP_PATH"
  fi
}

check_macos
require_command swift "Install Xcode Command Line Tools: xcode-select --install"
require_command swiftc "Install Xcode Command Line Tools: xcode-select --install"
require_command curl "curl is required for backend/model downloads."
require_command ditto "ditto is required to assemble and install the app bundle."
require_command hdiutil "hdiutil is required to create release DMGs."
require_command codesign "codesign is required for the ad-hoc app signature."
require_command shasum "shasum is required to verify downloaded model checksums."
require_command git "git is required for source checkout and development."
if security find-identity -v -p codesigning 2>/dev/null | grep -q 'Developer ID Application'; then
  pass "Developer ID signing identity is available"
else
  warn "no Developer ID signing identity found; local packages will be ad-hoc signed and may trigger Gatekeeper on other Macs"
fi
check_backend
check_default_model
check_translation
check_installed_app

printf '\n'
if (( failures > 0 )); then
  printf 'DuckWhisperer doctor found %d failure(s) and %d warning(s).\n' "$failures" "$warnings"
  exit 1
fi

printf 'DuckWhisperer doctor passed with %d warning(s).\n' "$warnings"
