// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "tap/tap_guard.hpp"

namespace vk {

bool TapGuard::allowReenable(Clock::time_point now, bool trusted) {
    if (!trusted) return false; // events would never reach us again

    // The oldest of the last kMaxDisables disables, before recording this one.
    const Clock::time_point oldest = recent_[next_];
    recent_[next_] = now;
    next_ = (next_ + 1) % kMaxDisables;
    const bool storm = oldest != Clock::time_point{} && now - oldest < kWindow;
    return !storm;
}

} // namespace vk
