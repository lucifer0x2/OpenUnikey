#!/usr/bin/env bash
# Prints the code signing identity for local builds: $SIGN_IDENTITY when set,
# else the self-signed "OpenUnikey Dev" certificate. A real certificate keeps
# the app's identity stable, so macOS keeps the Accessibility permission
# across rebuilds. Without it the build fails, unless ALLOW_ADHOC=1: an ad-hoc
# build no longer matches the granted permission, and replacing a running,
# trusted app with it is how input got frozen before.
set -euo pipefail

DEV_IDENTITY="OpenUnikey Dev"
if [ -n "${SIGN_IDENTITY:-}" ]; then
  echo "$SIGN_IDENTITY"
elif security find-identity -p codesigning 2>/dev/null | grep -q "\"$DEV_IDENTITY\""; then
  echo "$DEV_IDENTITY"
elif [ "${ALLOW_ADHOC:-0}" = "1" ]; then
  echo "-"
else
  echo "error: no \"$DEV_IDENTITY\" code signing certificate in the keychain." >&2
  echo "Create it (see README) or build with ALLOW_ADHOC=1." >&2
  exit 1
fi
