// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Opt-in diagnostic log of what the keyboard tap sees and does, one line per
// event, kept and written out by KeyLogFile. Off by default: it records
// keystrokes, so the app turns it on only when asked.
#pragma once

#include <ApplicationServices/ApplicationServices.h>
#include <cstdint>
#include <string>

namespace vk {

bool keyLogEnabled();

// What came in, what the tap did with it, and the engine result it acted on
// (backs, output).
void logKeyEvent(CGEventRef event, CGEventType type, const char* action, int backs,
                 const uint16_t* output, int outputLength);

// A line of context between key events: V/E switches, engine resets, tap
// restarts, the app that became active.
void logKeyNote(const std::string& text);

} // namespace vk
