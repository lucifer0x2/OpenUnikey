// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// The keyboard taps: every key press system-wide waits for them, so they listen
// to key events only. Mouse clicks are watched by the app with a passive monitor.
//
// The main tap sits at the HID level, where key presses enter WindowServer.
// A session-level tap misses some of them: WindowServer sometimes hands a key
// straight to the app without passing it and without disabling it (seen while
// keyboard focus is deferred to another process, e.g. a ViewBridge remote
// view), and the engine then marks the wrong letters. Gõ Nhanh and XKey sit at
// the HID level for the same reason.
//
// Keys posted at the session level never pass the HID tap: remote desktop
// apps, the Accessibility Keyboard, test tools. A second tap at the session
// level takes those; the HID tap marks every key it handled so the second tap
// lets it through. If the HID tap is down, the session tap takes every key.
#include <ApplicationServices/ApplicationServices.h>

#include <mutex>

#include "VietCore.h"
#include "tap/managed_tap.hpp"
#include "tap/shared_state.hpp"
#include "tap/tap_session.hpp"

namespace vk {
namespace {

constexpr int64_t kSeenAtHid = 0x564B4844; // "VKHD", in kCGEventSourceUserData
constexpr CGEventMask kKeyMask =
    CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventFlagsChanged);

// Built on first use, not as a global: the engine reads ukengine tables that
// are themselves globals, and globals of different files have no set order.
TapSession& session() {
    static TapSession instance;
    return instance;
}

// The two taps run on their own threads; the session is used by one at a time.
std::mutex& sessionMutex() {
    static std::mutex mutex;
    return mutex;
}

CGEventRef handleKey(CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
    if (sharedState().inputMethodActive.load(std::memory_order_relaxed)) return event;
    std::lock_guard<std::mutex> lock(sessionMutex());
    return session().handle(proxy, type, event);
}

CGEventRef handleHidKey(void*, CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
    CGEventRef result = handleKey(proxy, type, event);
    if (result) CGEventSetIntegerValueField(result, kCGEventSourceUserData, kSeenAtHid);
    return result;
}

CGEventRef handleSessionKey(void*, CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
    // The fix-ups the session posts come through here too.
    if (CGEventGetIntegerValueField(event, kCGEventSourceUserData) == kSeenAtHid ||
        session().isOwnEvent(event))
        return event;
    return handleKey(proxy, type, event);
}

ManagedTap& hidTap() {
    static ManagedTap tap("OpenUnikey.KeyboardTap", kCGHIDEventTap, kCGEventTapOptionDefault,
                          kKeyMask, handleHidKey, nullptr);
    return tap;
}

ManagedTap& sessionTap() {
    static ManagedTap tap("OpenUnikey.SessionKeyTap", kCGSessionEventTap,
                          kCGEventTapOptionDefault, kKeyMask, handleSessionKey, nullptr);
    return tap;
}

} // namespace
} // namespace vk

// Both taps or none count as running, so the app retries the one that is down
// (the HID tap after it gave up on timeouts, say) while the other types alone.
extern "C" bool vk_tap_start(void) {
    vk::session(); // build the engine here, not on the first key press
    const bool hid = vk::hidTap().start();
    const bool session = vk::sessionTap().start();
    return hid && session;
}
extern "C" void vk_tap_stop(void) {
    vk::hidTap().stop();
    vk::sessionTap().stop();
}
extern "C" bool vk_tap_running(void) {
    return vk::hidTap().running() && vk::sessionTap().running();
}
