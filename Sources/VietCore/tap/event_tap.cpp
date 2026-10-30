// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// The keyboard tap: every key press system-wide waits for it, so it listens to
// key events only. Mouse clicks are watched by the app with a passive monitor.
#include <ApplicationServices/ApplicationServices.h>

#include "VietCore.h"
#include "tap/managed_tap.hpp"
#include "tap/tap_session.hpp"

namespace vk {
namespace {

// Built on first use, not as a global: the engine reads ukengine tables that
// are themselves globals, and globals of different files have no set order.
// Only the tap thread uses it after vk_tap_start, one thread at a time.
TapSession& session() {
    static TapSession instance;
    return instance;
}

CGEventRef handleKey(void*, CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
    return session().handle(proxy, type, event);
}

ManagedTap& keyboardTap() {
    static ManagedTap tap("OpenUnikey.KeyboardTap",
                          CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged),
                          handleKey, nullptr);
    return tap;
}

} // namespace
} // namespace vk

extern "C" bool vk_tap_start(void) {
    vk::session(); // build the engine here, not on the first key press
    return vk::keyboardTap().start();
}
extern "C" void vk_tap_stop(void) { vk::keyboardTap().stop(); }
extern "C" bool vk_tap_running(void) { return vk::keyboardTap().running(); }
