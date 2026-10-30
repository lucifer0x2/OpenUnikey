// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Decides whether the keyboard tap may be re-enabled after macOS disabled it.
//
// An active tap sits in the path of every key press. When it stops answering
// (typically because the Accessibility permission was revoked or changed while
// it ran), WindowServer waits for its timeout on each event and the whole
// system's input stalls. Re-enabling it blindly repeats the stall forever, so
// the tap gives up instead and the app restarts it once things are healthy.
#pragma once

#include <chrono>

namespace vk {

class TapGuard {
public:
    using Clock = std::chrono::steady_clock;

    // Called for kCGEventTapDisabledByTimeout / ByUserInput with the current
    // Accessibility trust. True means "re-enable"; false means "stop the tap now".
    bool allowReenable(Clock::time_point now, bool trusted);

    // How long vk_tap_start refuses to run after the tap gave up.
    static constexpr std::chrono::seconds kCooldown{15};

private:
    static constexpr int kMaxDisables = 2;                // within kWindow
    static constexpr std::chrono::seconds kWindow{10};

    Clock::time_point recent_[kMaxDisables] = {};
    int next_ = 0;
};

} // namespace vk
