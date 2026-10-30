// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Posts the synthetic Backspace and Unicode key events that rewrite a word.
// The sending scheme follows OpenKey (github.com/tuyenvm/OpenKey).
#pragma once

#include <ApplicationServices/ApplicationServices.h>
#include <cstdint>

#include "VietCore.h"

namespace vk {

class KeySender {
public:
    KeySender();
    ~KeySender();
    KeySender(const KeySender&) = delete;
    KeySender& operator=(const KeySender&) = delete;

    // True for events this sender posted, so the tap lets them through.
    bool isOwnEvent(CGEventRef event) const;

    // Deletes `backs` characters then types `chars`.
    void replace(CGEventTapProxy proxy, int backs, const uint16_t* chars, int count,
                 VKAutocompleteFix fix);
    // Re-posts a key down the tap swallowed, after the replacement it triggered.
    void repost(CGEventTapProxy proxy, CGEventRef original);

private:
    void post(CGEventTapProxy proxy, CGEventRef event);
    void postKey(CGEventTapProxy proxy, CGKeyCode key, CGEventFlags extraFlags);
    void postText(CGEventTapProxy proxy, const UniChar* text, int length);

    CGEventSourceRef source_;
    int64_t sourceStateId_;
};

} // namespace vk
