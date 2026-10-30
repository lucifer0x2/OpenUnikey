// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// An active event tap on its own high-priority thread that can never keep
// stalling input.
//
// An active tap sits in the path of every event its mask matches. If it stops
// answering (typically when the Accessibility permission changes), WindowServer
// waits for its timeout on each such event. So when macOS disables the tap,
// it is only re-enabled while trusted and not timing out repeatedly; otherwise
// it stops, and may not start again for a cooldown that doubles each time.
// Each tap only delays the events of its own mask: keep masks narrow.
#pragma once

#include <ApplicationServices/ApplicationServices.h>

#include <mutex>

#include "tap/tap_guard.hpp"

namespace vk {

class ManagedTap {
public:
    // Called on the tap thread for every event of the mask. Returns the event
    // to deliver, or nullptr to swallow it.
    using Handler = CGEventRef (*)(void* context, CGEventTapProxy proxy, CGEventType type,
                                   CGEventRef event);

    // `name` names the thread and the log lines; both must outlive the tap.
    ManagedTap(const char* name, CGEventMask mask, Handler handler, void* context);

    bool start(); // false without permission, during a cooldown or on failure
    void stop();
    bool running();

private:
    struct Runtime;
    static CGEventRef callback(CGEventTapProxy proxy, CGEventType type, CGEventRef event,
                               void* user);
    static void giveUpOnMainQueue(void* self);

    const char* name_;
    CGEventMask mask_;
    Handler handler_;
    void* context_;

    std::mutex mutex_;
    Runtime* runtime_ = nullptr;
    TapGuard::Clock::time_point cooldownUntil_{};
    TapGuard::Clock::time_point lastGiveUp_{};
    int giveUps_ = 0;
};

} // namespace vk
