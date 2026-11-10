// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "tap/switch_hotkey.hpp"

namespace vk {
namespace {

constexpr CGEventFlags kModifierMask = kCGEventFlagMaskControl | kCGEventFlagMaskShift |
                                       kCGEventFlagMaskAlternate | kCGEventFlagMaskCommand;
constexpr CGEventFlags kControlShift = kCGEventFlagMaskControl | kCGEventFlagMaskShift;
constexpr int64_t kZKey = 6; // kVK_ANSI_Z

} // namespace

bool SwitchHotkey::onFlagsChanged(CGEventFlags flags, VKSwitchKey key) {
    if (key != VK_SWITCH_CONTROL_SHIFT) return false;
    const CGEventFlags mods = flags & kModifierMask;
    if (mods & ~kControlShift) spoiled_ = true; // e.g. Command for a screenshot
    if (mods == kControlShift) {
        // Not when Control+Shift is what is left of a bigger chord.
        armed_ = !spoiled_;
        return false;
    }
    // Fire on the first release.
    const bool fire = armed_ && (mods & ~kControlShift) == 0;
    armed_ = false;
    if (mods == 0) spoiled_ = false;
    return fire;
}

bool SwitchHotkey::onKeyDown(int64_t keycode, CGEventFlags flags, VKSwitchKey key) {
    armed_ = false; // Control+Shift+<key> is an app shortcut, not a switch
    // A key held with modifiers spoils the chord until they are all released;
    // a plain key also clears a chord whose release went unseen.
    spoiled_ = (flags & kModifierMask) != 0;
    return key == VK_SWITCH_OPTION_Z && keycode == kZKey &&
           (flags & kModifierMask) == kCGEventFlagMaskAlternate;
}

} // namespace vk
