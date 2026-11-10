#!/usr/bin/env bash
# Builds build/OpenUnikeyIM.app, the InputMethodKit input method, signs it like
# build-app.sh, installs it into ~/Library/Input Methods, registers it and
# selects it as the input source. The bundle posts key events, so it needs the
# Accessibility permission too; macOS asks on first use.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/build/OpenUnikeyIM.app"
INSTALLED="$HOME/Library/Input Methods/OpenUnikeyIM.app"

IDENTITY="$("$ROOT/scripts/signing-identity.sh")" # fails without the certificate

cd "$ROOT"
swift build -c "$CONFIG" --product OpenUnikeyIM
BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/OpenUnikeyIM" "$APP/Contents/MacOS/OpenUnikeyIM"
cp "$ROOT/Packaging/InputMethod-Info.plist" "$APP/Contents/Info.plist"
swift "$ROOT/scripts/make-im-icon.swift" "$APP/Contents/Resources/InputMethodIcon.tiff"
codesign --force --sign "$IDENTITY" "$APP"

# A running input method keeps the old binary; macOS starts it again on demand.
pkill -x OpenUnikeyIM || true
mkdir -p "$HOME/Library/Input Methods"
rm -rf "$INSTALLED"
cp -R "$APP" "$INSTALLED"
"$INSTALLED/Contents/MacOS/OpenUnikeyIM" --install
echo "Installed $INSTALLED (signed with: $IDENTITY)"
