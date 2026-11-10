// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Per-event logic of the keyboard taps: owns the engine. Not thread-safe: the
// taps take turns under a lock (see event_tap.cpp).
#pragma once

#include <ApplicationServices/ApplicationServices.h>
#include <cstdint>

#include "engine/engine.hpp"
#include "tap/key_sender.hpp"
#include "tap/switch_hotkey.hpp"

namespace vk {

class TapSession {
public:
    // Returns the event to deliver, or nullptr to swallow it. A null proxy
    // posts the rewrite at the session level (the input method has no tap).
    CGEventRef handle(CGEventTapProxy proxy, CGEventType type, CGEventRef event);
    // Safe without the lock: reads nothing that changes.
    bool isOwnEvent(CGEventRef event) const { return sender_.isOwnEvent(event); }
    void setJournaling(bool on) { sender_.setJournaling(on); }
    std::vector<PostedKey> takePostedKeys() { return sender_.takeJournal(); }
    // Types a key again at the session level, marked as our own.
    void retypeKey(CGEventRef event) { sender_.retype(event); }

private:
    CGEventRef handleKeyDown(CGEventTapProxy proxy, CGEventRef event);
    CGEventRef handleBackspace(CGEventTapProxy proxy, CGEventRef event);
    CGEventRef handleWordEnd(CGEventTapProxy proxy, CGEventRef event);
    void handleFlagsChanged(CGEventRef event);
    void sendEngineOutput(CGEventTapProxy proxy);
    void syncWithSharedState();
    void toggleMode();

    Engine engine_;
    KeySender sender_;
    SwitchHotkey hotkey_;
    uint32_t appliedOptionVersion_ = 0;
};

} // namespace vk
