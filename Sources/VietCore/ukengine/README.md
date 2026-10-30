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
