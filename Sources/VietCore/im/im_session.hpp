// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Key handling for the input method: the same TapSession as the event tap,
// fed by the keys InputMethodKit hands over inside the focused app.
//
// The rewrite is still Backspaces plus Unicode text posted as key events, but
// without a tap they are posted at the session level and come back to the app
// (and to this session) some time later. A key the user types meanwhile must
// not overtake them, so while any are on the way every key is posted too, in
// order behind them, instead of being handed straight to the app.
#pragma once

#include <ApplicationServices/ApplicationServices.h>
#include <cstdint>
#include <deque>

#include "tap/tap_session.hpp"

namespace vk {

class ImSession {
public:
    ImSession();
    // True when the event was consumed: its effect has been posted instead.
    // Key downs must carry their text (the input method copies it from the
    // NSEvent, whose CGEvent comes without it).
    bool handle(CGEventRef event);
    // Focus left or the caret moved: forget the word and what is on the way.
    void reset();

private:
    bool takeOwnKey(CGEventRef event);
    bool waitingForOwnKeys(uint64_t now);

    TapSession session_;
    std::deque<PostedKey> inFlight_; // posted key downs not seen back yet
    uint64_t lastPostAt_ = 0;        // ns, mach clock
};

} // namespace vk
