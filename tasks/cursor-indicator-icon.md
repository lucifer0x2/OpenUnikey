# Cursor indicator icon: bare "V" like ABC's "A"

Status: parked (2026-11-10).

## Goal

ABC shows a filled badge with "A" cut out in the menu bar, and the bare "A"
(no badge) in the indicator next to the text cursor and in the fn/🌐
switcher. OpenUnikey should do the same: badge in the menu bar, bare "V" in
the cursor indicator.

## Current state

- Menu bar: `InputMethodIcon.tiff` from `scripts/make-im-icon.swift`, 22×16 pt
  badge with 5 pt corners, `TISIconIsTemplate`. Matches ABC.
- Cursor indicator: shows the same badge as the menu bar.
- fn/🌐 switcher: shows "Vi" (unselected) and an empty blue circle (selected).

## Findings (lldb on macOS 26)

- `CursorUIViewService` draws both the switcher and the indicator through
  `KLInputSourceIconManager` (KeyboardLayouts.framework):
  `imageForInputSource:` (switcher) and `indicatorImageForInputSource:`.
- `labelEntryForInputSource:` reads labels only from the built-in
  `KLDynamicInputSourceIconTable`, with a `com.apple.` prefix check and an
  `IsPluginIM` / `com.apple.inputmethod.PluginIM` path. A third-party IMK
  input method gets no label entry, so `imageForInputSource:` returns nil.
- `indicatorImageForInputSource:`
  - with a label: fills black and draws the label badge with
    `destinationOut`, so the indicator is the inverse of the menu badge;
  - without one: copies `TSMInputSourcePropertyIconImage` (the menu icon,
    `tsInputMethodIconFileKey`) as is, template per
    `TSMInputSourcePropertyIconShouldBeTemplate`.
- The switcher falls back to `abbreviationsForLanguages:` on
  `TISIntendedLanguage` ("vi" → "Vi").
- `TextInputMenuAgent` (menu bar) uses `imageForTISInputSource:`, then
  `InputSource icon` / `alternateIcon` / `originalIcon`. Same file.

## Tried, no effect

- `TISIconLabels` → `Primary` = "V": TIS reports it
  (`TISPropertyInputSourceIconLabels`), but the KL label table ignores it.
- `TISIconLabels` → `CustomIcon` = a bare "V" PDF (as Apple's AinuIM does):
  `-[InputSource customIcon]` loads it, but neither `CursorUIViewService` nor
  `TextInputMenuAgent` calls `customIcon`.
- Restarting `TextInputSwitcher` and `CursorUIViewService` (they need
  `kill -KILL`; plain `killall` leaves them running).

## Ideas to research

- An IMK input method with one input mode (`tsInputModeListKey`) carrying
  `TISIconLabels`, `tsInputModeMenuIconFileKey` and
  `tsInputModePaletteIconFileKey`: do modes of third-party IMs get labels or a
  separate indicator icon? Changes the selected source ID, so
  `InputSources.swift` and the installer would follow.
- Packaging as an input method app extension (how Apple's PluginIM-hosted
  IMs get `TISIconLabels`), if that is open to third parties.
- Whether `TSMInputSourcePropertyIconImage` can come from a different key
  than the one the menu bar reads.

## Tools

The probes lived in the session scratchpad; to rebuild them:
- dump `KLInputSourceIconManager` output: `initWithEnableInputSources:` with
  the source IDs, then `indicatorImageForInputSource:`;
- lldb on a process that `dlopen`s KeyboardLayouts.framework and stops, then
  `disassemble -n '-[KLInputSourceIconManager …]'`.
