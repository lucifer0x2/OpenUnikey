// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "im/im_session.hpp"

#include <mach/mach_time.h>

#include "VietCore.h"

namespace vk {
namespace {

// Posted keys normally come back within a few milliseconds. Past this they
// went to another app (focus moved), so stop waiting for them.
constexpr uint64_t kGiveUpNs = 500 * 1000 * 1000;
constexpr int64_t kTextKey = 0; // KeySender types text on this key code

uint64_t nowNs() {
    static mach_timebase_info_data_t timebase = [] {
        mach_timebase_info_data_t info;
        mach_timebase_info(&info);
        return info;
    }();
    return mach_absolute_time() * timebase.numer / timebase.denom;
}

std::u16string textOf(CGEventRef event) {
    UniChar text[16];
    UniCharCount length = 0;
    CGEventKeyboardGetUnicodeString(event, 16, &length, text);
    return std::u16string(reinterpret_cast<const char16_t*>(text), length);
}

} // namespace

ImSession::ImSession() { session_.setJournaling(true); }

bool ImSession::handle(CGEventRef event) {
    const CGEventType type = CGEventGetType(event);
    if (type == kCGEventKeyDown && takeOwnKey(event))
        return false; // our own rewrite: the app types it
    const uint64_t now = nowNs();
    const bool mustQueue = type == kCGEventKeyDown && waitingForOwnKeys(now);
    CGEventRef result = session_.handle(nullptr, type, event);
    if (result && mustQueue) {
        // The engine let the key through, but it would overtake the rewrite.
        session_.retypeKey(event);
        result = nullptr;
    }
    std::vector<PostedKey> posted = session_.takePostedKeys();
    if (!posted.empty()) {
        inFlight_.insert(inFlight_.end(), posted.begin(), posted.end());
        lastPostAt_ = now;
    }
    return result == nullptr;
}

void ImSession::reset() {
    inFlight_.clear();
    vk_reset();
}

// Not only the oldest: some apps hand the input method the posted Backspaces
// but not the posted text, which then never comes back. Text keys share key
// code 0 with the A key, so those are told apart by their text.
bool ImSession::takeOwnKey(CGEventRef event) {
    const int64_t keycode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    for (auto it = inFlight_.begin(); it != inFlight_.end(); ++it) {
        if (it->keycode != keycode) continue;
        if (keycode == kTextKey && textOf(event) != it->text) continue;
        inFlight_.erase(it);
        return true;
    }
    return false;
}

// Only keys sure to come back count: a key that waits on posted text that
// never returns would wait for nothing.
bool ImSession::waitingForOwnKeys(uint64_t now) {
    if (!inFlight_.empty() && now - lastPostAt_ > kGiveUpNs) inFlight_.clear();
    for (const PostedKey& key : inFlight_)
        if (key.keycode != kTextKey) return true;
    return false;
}

} // namespace vk
