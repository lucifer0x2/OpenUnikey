# ukengine (vendored)

Vietnamese typing engine by Pham Kim Long, from x-unikey, as maintained in
[fcitx5-unikey](https://github.com/fcitx/fcitx5-unikey) (`unikey/` folder,
commit `ed9170c35c1a6275d105e03d7f9bc4f674c1469c`). License: LGPL-2.0-or-later
(`LICENSE.LGPL-2.0-or-later.txt`).

Not copied: `usrkeymap.*` and `unikeyinputcontext.*`, which depend on fcitx.
OpenUnikey talks to the engine through `../engine/engine.hpp`.

These files are large on purpose: they are kept as close to upstream as possible
so fixes can be merged back and forth.

## Local changes

- `ukengine.h`, `ukengine.cpp`: `processTelexW` kept "the last w became ư" in a
  function-level `static` that never expired, so a lone `w` (ư) made a later
  `ow` produce `oư` in another word, or even in another engine. It is now the
  member `m_telexWMapKey` and only applies to the key typed right before.
- `ukengine.h`, `ukengine.cpp`, `keystroke_sync.cpp`: Backspace dropped one
  key from the key buffer per deleted char, but a char can take several keys
  (`aa`, `dd`, a tone key and the key that undid it). The stray keys came
  back when a non-Vietnamese word was restored at its end: `pussh`, two
  Backspaces, `sh`, Space gave `pussh`; deleting the whole word left keys that
  were glued to the next one (`ppush`). `synchKeyStrokeBuffer` now asks
  `resyncWordKeyStrokes`, which keeps the keys that still type the word
  (checked by typing them in a scratch engine), and clears the key buffer when
  the char buffer is empty.
