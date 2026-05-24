#!/usr/bin/env bash
set -u

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SUPPORT_ROOT="${PLUME_SUPPORT_DIR:-${DUCKWHISPERER_SUPPORT_DIR:-${LOCAL_WHISPERER_SUPPORT_DIR:-$HOME/Library/Application Support/Plume}}}"
LEGACY_SUPPORT_ROOT="$HOME/Library/Application Support/Local Whisperer"
TRANSLATION_DIR="$SUPPORT_ROOT/Translation"
STYLE_REWRITER_DIR="$SUPPORT_ROOT/StyleRewriter"
MODEL_DIR="$SUPPORT_ROOT/Models"
APP_PATH="${PLUME_INSTALL_DIR:-${DUCKWHISPERER_INSTALL_DIR:-/Applications}}/Plume.app"
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

resolve_support_root() {
  if [[ -d "$SUPPORT_ROOT" ]]; then
    return
  fi
  if [[ -d "$LEGACY_SUPPORT_ROOT" ]]; then
    SUPPORT_ROOT="$LEGACY_SUPPORT_ROOT"
    TRANSLATION_DIR="$SUPPORT_ROOT/Translation"
    STYLE_REWRITER_DIR="$SUPPORT_ROOT/StyleRewriter"
    MODEL_DIR="$SUPPORT_ROOT/Models"
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
    fail "Plume requires macOS."
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

check_style_rewriter() {
  if [[ -x "$STYLE_REWRITER_DIR/Runner/llama-cli" ]]; then
    pass "Enhanced Robot local runner is installed"
  elif [[ -x /opt/homebrew/bin/llama-cli || -x /usr/local/bin/llama-cli || -x /opt/homebrew/bin/llama || -x /usr/local/bin/llama ]]; then
    pass "Enhanced Robot can use an installed llama.cpp runner"
  else
    warn "Enhanced Robot runner is not installed; basic Robot mode still works"
  fi

  if [[ -f "$STYLE_REWRITER_DIR/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf" ]]; then
    pass "Enhanced Robot model is installed"
  else
    warn "Enhanced Robot model is not installed; install it from Speed & Accuracy if wanted"
  fi
}

check_installed_app() {
  if [[ -d "$APP_PATH" ]]; then
    pass "installed app exists at $APP_PATH"
  else
    warn "installed app was not found at $APP_PATH"
  fi
}

find_codesigning_identity() {
  security find-identity -v -p codesigning 2>/dev/null |
    awk -F '"' '
      /Developer ID Application/ { developer = $2 }
      /Apple Development/ && !local { local = $2 }
      /Mac Developer/ && !local { local = $2 }
      /3rd Party Mac Developer Application/ && !local { local = $2 }
      END {
        if (developer) {
          print "developer:" developer
        } else if (local) {
          print "local:" local
        }
      }
    '
}

check_signing_identity() {
  local identity
  identity="$(find_codesigning_identity)"
  case "$identity" in
    developer:*)
      pass "Developer ID signing identity is available"
      ;;
    local:*)
      pass "local code-signing identity is available: ${identity#local:}"
      warn "no Developer ID signing identity found; release packages may still trigger Gatekeeper on other Macs"
      ;;
    *)
      warn "no code-signing identity found; builds will be ad-hoc signed, Accessibility trust may reset after rebuilds, and packages may trigger Gatekeeper on other Macs"
      ;;
  esac
}

check_installed_app_signature() {
  [[ -d "$APP_PATH" ]] || return

  local requirement verify_output
  if ! verify_output="$(codesign --verify --deep --strict "$APP_PATH" 2>&1)"; then
    warn "installed app signature does not pass strict verification: $verify_output"
    return
  fi

  requirement="$(codesign -d -r- "$APP_PATH" 2>&1 || true)"
  if [[ "$requirement" == *'designated => cdhash'* ]]; then
    warn "installed app is ad-hoc signed; macOS may require re-enabling Accessibility after each reinstall"
  elif [[ "$requirement" == *'designated =>'* ]]; then
    pass "installed app has a stable code-signing requirement"
  else
    warn "could not read installed app signing requirement"
  fi
}

resolve_support_root
check_macos
require_command swift "Install Xcode Command Line Tools: xcode-select --install"
require_command swiftc "Install Xcode Command Line Tools: xcode-select --install"
require_command curl "curl is required for backend/model downloads."
require_command ditto "ditto is required to assemble and install the app bundle."
require_command hdiutil "hdiutil is required to create release DMGs."
require_command codesign "codesign is required for the ad-hoc app signature."
require_command shasum "shasum is required to verify downloaded model checksums."
require_command git "git is required for source checkout and development."
check_signing_identity
check_backend
check_default_model
check_translation
check_style_rewriter
check_installed_app
check_installed_app_signature

printf '\n'
if (( failures > 0 )); then
  printf 'Plume doctor found %d failure(s) and %d warning(s).\n' "$failures" "$warnings"
  exit 1
fi

printf 'Plume doctor passed with %d warning(s).\n' "$warnings"
