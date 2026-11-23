# Typing Vietnamese in password fields

Status: system installation confirmed working by the user (2026-11-10), after
Quit/reopening affected apps. Earlier rollback notes below describe the first
attempt, not the current installation. Password-field behavior still needs a
separate end-to-end check.

## Problem

When a password field gets focus (secure event input), macOS switches
OpenUnikey to ABC and hides it from the input source list. Apple's own
Vietnamese input method stays selectable there.

## Findings (lldb on macOS 26)

- Each input source has `TSMInputSourcePropertyIsSecure`: ABC and every mode
  of `com.apple.inputmethod.VietnameseIM` are 1; OpenUnikey in `~/Library` is 0.
  Read it with `TISGetInputSourceProperty(src, "TSMInputSourcePropertyIsSecure")`.
- HIToolbox `islGetInputSourceIsSecureCandidate` sets it: true for system
  sources and keyboard layouts; for any other input method, true only when its
  bundle path starts with `/Library/Input Methods/`.
- `kTISPropertyInputSourceIsASCIICapable` is already true for OpenUnikey; it is
  not the gate. No Info.plist key changes the result.

## What was tried

`scripts/build-input-method.sh --system` installs into `/Library/Input Methods`
(sudo) and removes the `~/Library` copy. On the first attempt `IsSecure` was 1,
but the user reported typing stopped everywhere:

1. `imklaunchagent` (running since boot) kept failing with
   `LaunchInputMethod() Error, status=-50`. Restarting it let the IM start from
   `/Library` and register its XPC endpoint.
2. Apps opened before the move (the Claude app, pid 1249) still did not get a
   working connection: one `requestIMKXPCEndpointInvalid`, then no endpoint
   request when OpenUnikey was selected. A freshly opened TextEdit did not
   type either, per the user.

Other log lines seen right after the move:
- `imklaunchagent: Refusing connection name for bundle: unrecognized
  'InputMethodConnectionName' value`
- `amfid: ... not valid: ... adhoc signed or signed by an unknown certificate
  chain` and `taskgated-helper: Disallowing io.github.openunikey.inputmethod.
  OpenUnikey because no eligible provisioning profiles found`: the IM is signed
  with the local "OpenUnikey Dev" certificate, not a Developer ID. A
  root-owned bundle in /Library may be held to that.
- LaunchServices also has `build/OpenUnikeyIM.app` registered with the same
  bundle ID.

## Subsequent confirmation and installation guidance

The user later ran the system installer and confirmed typing worked after
quitting and reopening the affected apps. This establishes that the system
location can work with the current signing setup; the earlier signing log lines
are not proof that a Developer ID is required.

The installer now retains an existing system location on a no-argument rebuild,
supports explicit `--system` / `--user`, and refreshes imklaunchagent after a
location move before registering/selecting the new bundle. It does not quit
other apps or guarantee every already-open IMK client reconnects. Try switching
ABC → OpenUnikey first, then Quit/reopen only affected apps. If connections stay
stale after moving locations, logging out/in is a fallback. Normal preference
changes are published to the active input method without reopening clients.

## Ideas to research

- Verify a real password field separately; a working ordinary text field and
  `IsSecure == 1` alone do not establish secure-field typing behavior.
- Check whether the "unrecognized InputMethodConnectionName" refusal is about
  the /Library copy (maybe the name must match a pattern for system IMs).
- Sign with a Developer ID (and notarize) to rule out amfid/taskgated.
- Unregister `build/OpenUnikeyIM.app` from LaunchServices
  (`lsregister -u`) so the bundle ID resolves to one path.
- Even when it works: Telex in password fields turns "matkhau"-style input into
  accented text; consider passing keys through when the client is secure.
