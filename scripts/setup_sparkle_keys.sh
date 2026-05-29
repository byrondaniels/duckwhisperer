#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACCOUNT="${SPARKLE_ACCOUNT:-duckwhisperer}"
PUBLIC_KEY_FILE="${SPARKLE_PUBLIC_ED_KEY_FILE:-$ROOT_DIR/.sparkle-public-ed-key}"

"$ROOT_DIR/scripts/bootstrap_sparkle.sh" >/dev/null

GENERATE_KEYS="$ROOT_DIR/vendor/Sparkle/bin/generate_keys"
if [[ ! -x "$GENERATE_KEYS" ]]; then
  echo "Missing Sparkle generate_keys tool. Run scripts/bootstrap_sparkle.sh first." >&2
  exit 1
fi

output="$("$GENERATE_KEYS" --account "$ACCOUNT")"
printf '%s\n' "$output"

public_key="$(printf '%s\n' "$output" | sed -n 's/.*SUPublicEDKey[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' | tail -n 1)"
if [[ -z "$public_key" ]]; then
  public_key="$(printf '%s\n' "$output" | awk '
    /<key>SUPublicEDKey<\/key>/ { getline; print }
  ' | sed -n 's/.*<string>\(.*\)<\/string>.*/\1/p' | tail -n 1)"
fi

if [[ -z "$public_key" ]]; then
  echo "Could not parse SUPublicEDKey from Sparkle generate_keys output." >&2
  exit 1
fi

printf '%s\n' "$public_key" > "$PUBLIC_KEY_FILE"
cat <<EOF

Wrote Sparkle public key to:
$PUBLIC_KEY_FILE

Keep the private key in Keychain or export it through Sparkle only for CI secrets.
The public key is not secret; release builds read it from this file or SPARKLE_PUBLIC_ED_KEY.
EOF
