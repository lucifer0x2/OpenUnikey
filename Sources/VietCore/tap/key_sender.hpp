// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Posts the synthetic Backspace and Unicode key events that rewrite a word.
// With a tap proxy they go in right after the tapped key; without one (the
// input method) they are posted at the session level.
// The sending scheme follows OpenKey (github.com/tuyenvm/OpenKey).
#pragma once

#include <ApplicationServices/ApplicationServices.h>
#include <cstdint>
#include <string>
#include <vector>

#include "VietCore.h"

namespace vk {

// A key down as posted: what the input method expects to see come back.
struct PostedKey {
    int64_t keycode;
    std::u16string text;
};

// Replaces CGEventPost for events posted without a tap (tests).
void setUntappedPoster(VKEventPoster poster, void* context);

class KeySender {
public:
    KeySender();
    ~KeySender();
    KeySender(const KeySender&) = delete;
    KeySender& operator=(const KeySender&) = delete;

    // True for events this sender posted, so the tap lets them through.
    bool isOwnEvent(CGEventRef event) const;
    // The input method cannot see the marker on keys that come back (the app
    // hands it a rebuilt NSEvent), so it keeps a list of what was posted.
    void setJournaling(bool on) { journaling_ = on; }
    std::vector<PostedKey> takeJournal() { return std::move(journal_); }

    // Deletes `backs` characters then types `chars`.
    void replace(CGEventTapProxy proxy, int backs, const uint16_t* chars, int count,
                 VKAutocompleteFix fix);
    // Re-posts a key down the tap swallowed, after the replacement it triggered.
    void repost(CGEventTapProxy proxy, CGEventRef original);
    // Types a key again without a tap (the input method), as a new event.
    void retype(CGEventRef original);

private:
    void post(CGEventTapProxy proxy, CGEventRef event);
    void postKey(CGEventTapProxy proxy, CGKeyCode key, CGEventFlags extraFlags);
    void postText(CGEventTapProxy proxy, const UniChar* text, int length);

    CGEventSourceRef source_;
    int64_t sourceStateId_;
    bool journaling_ = false;
    std::vector<PostedKey> journal_;
};

} // namespace vk
