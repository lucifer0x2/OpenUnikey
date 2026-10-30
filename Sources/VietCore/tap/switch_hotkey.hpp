// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Detects the V/E switch key: a lone Control+Shift press, or Option+Z.
#pragma once

#include <ApplicationServices/ApplicationServices.h>

#include "VietCore.h"

namespace vk {

class SwitchHotkey {
public:
    // True when releasing a lone Control+Shift chord should toggle the mode.
    bool onFlagsChanged(CGEventFlags flags, VKSwitchKey key);
    // True when this key down is the switch key itself and must be swallowed.
    bool onKeyDown(int64_t keycode, CGEventFlags flags, VKSwitchKey key);

private:
    bool armed_ = false;
};

} // namespace vk
