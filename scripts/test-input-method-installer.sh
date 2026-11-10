#!/usr/bin/env bash
# Runs the real installer against temporary paths and stubbed OS/build tools.
# No real sudo, process signalling, registration, or user installation.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/openunikey-installer.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT
mkdir -p "$FIXTURE/project/scripts" "$FIXTURE/project/Packaging" "$FIXTURE/bin" "$FIXTURE/compiled"
export INSTALLER_TEST_LOG="$FIXTURE/actions.log"
export INSTALLER_TEST_BIN="$FIXTURE/compiled"
sed -e "s|^USER_DIR=.*|USER_DIR=\"$FIXTURE/user\"|" \
    -e "s|^SYSTEM_DIR=.*|SYSTEM_DIR=\"$FIXTURE/system\"|" \
    "$ROOT/scripts/build-input-method.sh" > "$FIXTURE/project/scripts/build-input-method.sh"
# Refuse to execute if a future script edit defeats either path replacement.
rg -Fxq "USER_DIR=\"$FIXTURE/user\"" "$FIXTURE/project/scripts/build-input-method.sh"
rg -Fxq "SYSTEM_DIR=\"$FIXTURE/system\"" "$FIXTURE/project/scripts/build-input-method.sh"
cat > "$FIXTURE/project/scripts/signing-identity.sh" <<'SH'
#!/usr/bin/env bash
echo fixture-identity
SH
cat > "$FIXTURE/compiled/OpenUnikeyIM" <<'SH'
#!/usr/bin/env bash
echo "register:$0:$*" >> "$INSTALLER_TEST_LOG"
SH
cat > "$FIXTURE/bin/swift" <<'SH'
#!/usr/bin/env bash
if [[ "$*" == *--show-bin-path* ]]; then echo "$INSTALLER_TEST_BIN"; fi
SH
for command in sudo codesign pkill killall; do
    cat > "$FIXTURE/bin/$command" <<'SH'
#!/usr/bin/env bash
name="${0##*/}"
echo "$name:$*" >> "$INSTALLER_TEST_LOG"
if [[ "$name" == sudo ]]; then exec "$@"; fi
SH
done
touch "$FIXTURE/project/Packaging/InputMethod-Info.plist"
chmod +x "$FIXTURE/project/scripts/signing-identity.sh" "$FIXTURE/compiled/OpenUnikeyIM" "$FIXTURE/bin/"*

run_installer() {
    : > "$INSTALLER_TEST_LOG"
    PATH="$FIXTURE/bin:$PATH" bash "$FIXTURE/project/scripts/build-input-method.sh" "$@" > "$FIXTURE/output" 2>&1
}
require() {
    if ! "$@"; then echo "FAIL: $*" >&2; exit 1; fi
}

# New install uses the user directory and does not disturb imklaunchagent.
run_installer
require test -x "$FIXTURE/user/OpenUnikeyIM.app/Contents/MacOS/OpenUnikeyIM"
require rg -q "Installed $FIXTURE/user/OpenUnikeyIM.app" "$FIXTURE/output"
if rg -q '^(sudo|killall):' "$INSTALLER_TEST_LOG"; then exit 1; fi

# A move refreshes the launcher BEFORE registration/selection, never afterwards.
run_installer --system
require test ! -e "$FIXTURE/user/OpenUnikeyIM.app"
require test -x "$FIXTURE/system/OpenUnikeyIM.app/Contents/MacOS/OpenUnikeyIM"
refresh_line="$(rg -n '^killall:imklaunchagent$' "$INSTALLER_TEST_LOG" | cut -d: -f1)"
register_line="$(rg -n '^register:' "$INSTALLER_TEST_LOG" | cut -d: -f1)"
require test "$refresh_line" -lt "$register_line"
require rg -q 'Quit/reopen affected apps' "$FIXTURE/output"

# No-argument rebuild preserves an existing system installation.
run_installer
require test -d "$FIXTURE/system/OpenUnikeyIM.app"
require test ! -e "$FIXTURE/user/OpenUnikeyIM.app"
require rg -q "Installed $FIXTURE/system/OpenUnikeyIM.app" "$FIXTURE/output"
if rg -q '^killall:' "$INSTALLER_TEST_LOG"; then exit 1; fi

# Moving back requires the explicit --user flag and uses the same ordering.
run_installer --user debug
require test ! -e "$FIXTURE/system/OpenUnikeyIM.app"
require test -d "$FIXTURE/user/OpenUnikeyIM.app"
refresh_line="$(rg -n '^killall:imklaunchagent$' "$INSTALLER_TEST_LOG" | cut -d: -f1)"
register_line="$(rg -n '^register:' "$INSTALLER_TEST_LOG" | cut -d: -f1)"
require test "$refresh_line" -lt "$register_line"

# Reject unknown options before invoking any build or installation commands.
if run_installer --invalid; then echo 'accepted invalid arguments' >&2; exit 1; fi
require test ! -s "$INSTALLER_TEST_LOG"
require rg -q '^Usage:' "$FIXTURE/output"
echo 'PASS: installer location, move ordering, explicit rollback, argument validation'
