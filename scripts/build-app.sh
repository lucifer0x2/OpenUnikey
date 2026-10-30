#!/usr/bin/env bash
# Builds build/OpenUnikey.app (release by default) and signs it with the
# identity from scripts/signing-identity.sh. With the "OpenUnikey Dev"
# certificate (see README) the Accessibility permission survives rebuilds;
# with the ad-hoc fallback macOS asks for it again after each build.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/build/OpenUnikey.app"

IDENTITY="$("$ROOT/scripts/signing-identity.sh")" # fails without the certificate

cd "$ROOT"
swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

# Never swap the bundle under a running, trusted tap.
if pkill -x OpenUnikey; then
  echo "Stopped the running OpenUnikey; open it again after the build."
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/OpenUnikey" "$APP/Contents/MacOS/OpenUnikey"
cp "$ROOT/Packaging/Info.plist" "$APP/Contents/Info.plist"

codesign --force --sign "$IDENTITY" "$APP"
echo "Built $APP (signed with: $IDENTITY)"
