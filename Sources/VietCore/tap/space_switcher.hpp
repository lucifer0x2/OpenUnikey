// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#pragma once

namespace vk {

enum class SpaceDirection { Left, Right };

// Types Control+Left/Right arrow, the default shortcuts of macOS'
// "Move left/right a space" (System Settings > Keyboard > Shortcuts > Mission
// Control). Returns at once; the keys are posted on a background queue.
void switchSpace(SpaceDirection direction);

} // namespace vk
