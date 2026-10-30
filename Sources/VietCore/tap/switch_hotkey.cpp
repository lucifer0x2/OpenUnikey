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
    if (mods == kControlShift) {
        armed_ = true;
        return false;
    }
    // Fire on the first release, as long as nothing else joined the chord.
    const bool fire = armed_ && (mods & ~kControlShift) == 0;
    armed_ = false;
    return fire;
}

bool SwitchHotkey::onKeyDown(int64_t keycode, CGEventFlags flags, VKSwitchKey key) {
    armed_ = false; // Control+Shift+<key> is an app shortcut, not a switch
    return key == VK_SWITCH_OPTION_Z && keycode == kZKey &&
           (flags & kModifierMask) == kCGEventFlagMaskAlternate;
}

} // namespace vk
