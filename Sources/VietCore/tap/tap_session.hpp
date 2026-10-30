// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Per-event logic of the tap: owns the engine and runs only on the tap thread.
#pragma once

#include <ApplicationServices/ApplicationServices.h>
#include <cstdint>

#include "engine/engine.hpp"
#include "tap/key_sender.hpp"
#include "tap/switch_hotkey.hpp"

namespace vk {

class TapSession {
public:
    // Returns the event to deliver, or nullptr to swallow it.
    CGEventRef handle(CGEventTapProxy proxy, CGEventType type, CGEventRef event);

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
