// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "tap/space_switcher.hpp"

#include <ApplicationServices/ApplicationServices.h>
#include <dispatch/dispatch.h>

namespace vk {
namespace {

constexpr CGKeyCode kControlKey = 59;
constexpr CGKeyCode kLeftArrow = 123;
constexpr CGKeyCode kRightArrow = 124;
// Arrow keys carry these flags from a real keyboard; the Mission Control
// shortcut is registered as Control + (Fn) arrow and matches on them.
constexpr CGEventFlags kArrowFlags =
    kCGEventFlagMaskControl | kCGEventFlagMaskSecondaryFn | kCGEventFlagMaskNumericPad;

void post(CGKeyCode key, bool down, CGEventFlags flags, CGEventType type = kCGEventKeyDown) {
    CGEventRef event = CGEventCreateKeyboardEvent(nullptr, key, down);
    if (!event) return;
    if (type == kCGEventFlagsChanged) CGEventSetType(event, kCGEventFlagsChanged);
    CGEventSetFlags(event, flags);
    CGEventPost(kCGHIDEventTap, event); // through WindowServer, like a real key
    CFRelease(event);
}

void typeShortcut(void* context) {
    const auto arrow = static_cast<CGKeyCode>(reinterpret_cast<uintptr_t>(context));
    post(kControlKey, true, kCGEventFlagMaskControl, kCGEventFlagsChanged);
    post(arrow, true, kArrowFlags);
    post(arrow, false, kArrowFlags);
    post(kControlKey, false, 0, kCGEventFlagsChanged);
}

dispatch_queue_t shortcutQueue() {
    static dispatch_queue_t queue =
        dispatch_queue_create("OpenUnikey.SpaceSwitcher", DISPATCH_QUEUE_SERIAL);
    return queue;
}

} // namespace

void switchSpace(SpaceDirection direction) {
    const CGKeyCode arrow = direction == SpaceDirection::Left ? kLeftArrow : kRightArrow;
    dispatch_async_f(shortcutQueue(), reinterpret_cast<void*>(uintptr_t{arrow}), typeShortcut);
}

} // namespace vk
