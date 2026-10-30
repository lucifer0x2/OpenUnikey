// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Beta: the mouse's side buttons switch Spaces (button 4 right, button 5 left).
// A tap of its own whose mask holds only "other" mouse buttons, so neither key
// presses nor left/right clicks ever wait for it, even if it misbehaves.
#include <ApplicationServices/ApplicationServices.h>

#include "VietCore.h"
#include "tap/managed_tap.hpp"
#include "tap/space_switcher.hpp"

namespace vk {
namespace {

constexpr int64_t kBackButton = 3;    // "button 4" to most mouse software
constexpr int64_t kForwardButton = 4; // "button 5"

CGEventRef handleMouse(void*, CGEventTapProxy, CGEventType type, CGEventRef event) {
    const int64_t button = CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber);
    if (button != kBackButton && button != kForwardButton) return event;
    if (type == kCGEventOtherMouseDown)
        switchSpace(button == kBackButton ? SpaceDirection::Right : SpaceDirection::Left);
    return nullptr; // swallow down and up, so apps do not also go Back/Forward
}

ManagedTap& mouseTap() {
    static ManagedTap tap("OpenUnikey.MouseTap",
                          CGEventMaskBit(kCGEventOtherMouseDown) |
                              CGEventMaskBit(kCGEventOtherMouseUp),
                          handleMouse, nullptr);
    return tap;
}

} // namespace
} // namespace vk

extern "C" bool vk_mouse_tap_start(void) { return vk::mouseTap().start(); }
extern "C" void vk_mouse_tap_stop(void) { vk::mouseTap().stop(); }
extern "C" bool vk_mouse_tap_running(void) { return vk::mouseTap().running(); }
