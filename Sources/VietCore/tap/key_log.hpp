// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Opt-in diagnostic log of what the keyboard tap sees and does, written to the
// unified log (subsystem io.github.openunikey, category keys). Off by default:
// it records keystrokes, so the app turns it on only when asked, for a while.
#pragma once

#include <ApplicationServices/ApplicationServices.h>
#include <cstdint>

namespace vk {

bool keyLogEnabled();
void setKeyLogEnabled(bool enabled);

// One line per event: what came in, what the tap did with it, and the engine
// result it acted on (backs, output).
void logKeyEvent(CGEventRef event, CGEventType type, const char* action, int backs,
                 const uint16_t* output, int outputLength);

} // namespace vk
