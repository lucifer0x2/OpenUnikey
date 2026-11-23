#!/usr/bin/env bash
# Builds build/OpenUnikeyIM.app, the InputMethodKit input method, signs it like
# build-app.sh, installs it, registers it and selects it as the input source.
# Rebuild in the existing system location when present; otherwise use ~/Library.
#
# --system installs into /Library/Input Methods instead (asks for sudo).
# --user explicitly moves it back to ~/Library/Input Methods.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
USER_DIR="$HOME/Library/Input Methods"
SYSTEM_DIR="/Library/Input Methods"
INSTALL_DIR="$USER_DIR"
STALE_DIR="$SYSTEM_DIR"
LOCATION="${1:-}"
if [[ "$LOCATION" == "--system" ]] ||
   { [[ "$LOCATION" != "--user" ]] && [[ -e "$SYSTEM_DIR/OpenUnikeyIM.app" ]]; }; then
    INSTALL_DIR="$SYSTEM_DIR"
    STALE_DIR="$USER_DIR"
fi
if [[ "$LOCATION" == "--system" || "$LOCATION" == "--user" ]]; then shift; fi
CONFIG="${1:-release}"
if [[ $# -gt 1 || ( "$CONFIG" != "release" && "$CONFIG" != "debug" ) ]]; then
    echo "Usage: $0 [--system|--user] [release|debug]" >&2
    exit 2
fi
# Runs a command with sudo when it touches the system folder.
in_dir() {
    local dir="$1"; shift
    if [[ "$dir" == "$SYSTEM_DIR" ]]; then sudo "$@"; else "$@"; fi
}
APP="$ROOT/build/OpenUnikeyIM.app"
INSTALLED="$INSTALL_DIR/OpenUnikeyIM.app"
STALE="$STALE_DIR/OpenUnikeyIM.app"

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
# One copy only: two registered bundles share the input source ID.
MOVED=false
if [[ -e "$STALE" ]]; then in_dir "$STALE_DIR" rm -rf "$STALE"; MOVED=true; fi
in_dir "$INSTALL_DIR" mkdir -p "$INSTALL_DIR"
in_dir "$INSTALL_DIR" rm -rf "$INSTALLED"
in_dir "$INSTALL_DIR" cp -R "$APP" "$INSTALLED"
# imklaunchagent remembers where the input method was and fails to start it
# from a new folder (LaunchInputMethod status -50). Clear that old location
# BEFORE registration/selection creates the new server/client connection.
if $MOVED; then killall imklaunchagent 2>/dev/null || true; fi
"$INSTALLED/Contents/MacOS/OpenUnikeyIM" --install
echo "Installed $INSTALLED (signed with: $IDENTITY)"
if $MOVED; then
    echo "Location changed. Try ABC → OpenUnikey; Quit/reopen affected apps if their IMK connection is stale."
    echo "If that is insufficient, log out and back in. Other apps were not force-quit."
fi
