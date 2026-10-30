#!/usr/bin/env bash
# End-to-end typing check through OpenUnikey's real event tap.
#
#   scripts/run-harness.sh [--rebuild] [harness options] --corpus FILE...
#
# Builds build/TypingHarness.app on first use or with --rebuild. Signed with
# the "OpenUnikey Dev" certificate it keeps its Accessibility permission (needed
# to post key events) across rebuilds; ad-hoc signed, macOS asks again.
# Options are listed in Sources/TypingHarness/main.swift.
# OpenUnikey must be running in V mode with the matching input method; do not
# use the keyboard or mouse while it types (it stops if it loses focus).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/build/TypingHarness.app"
REPORT="${TMPDIR:-/tmp}/typing-harness-$$.txt"

if [ "${1:-}" = "--rebuild" ] || [ ! -d "$APP" ]; then
  [ "${1:-}" = "--rebuild" ] && shift
  IDENTITY="$("$ROOT/scripts/signing-identity.sh")" # fails without the certificate
  (cd "$ROOT" && swift build -c release --product TypingHarness)
  BIN_DIR="$(cd "$ROOT" && swift build -c release --show-bin-path)"
  rm -rf "$APP"
  mkdir -p "$APP/Contents/MacOS"
  cp "$BIN_DIR/TypingHarness" "$APP/Contents/MacOS/TypingHarness"
  cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>TypingHarness</string>
	<key>CFBundleIdentifier</key><string>io.github.openunikey.harness</string>
	<key>CFBundleName</key><string>TypingHarness</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>LSMinimumSystemVersion</key><string>13.0</string>
</dict>
</plist>
PLIST
  codesign --force --sign "$IDENTITY" "$APP"
fi

open -W -n "$APP" --args --out "$REPORT" "$@"
cat "$REPORT"
