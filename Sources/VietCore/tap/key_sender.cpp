// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "tap/key_sender.hpp"

#include <algorithm>
#include <initializer_list>

namespace vk {
namespace {

constexpr CGKeyCode kBackspaceKey = 51;  // kVK_Delete
constexpr CGKeyCode kTextKey = 0;        // any key; the Unicode payload wins
constexpr UniChar kAutocompleteFiller = 0x202F; // narrow no-break space
constexpr int kMaxCharsPerEvent = 16;   // longer strings are split
constexpr int64_t kSyntheticMarker = 0x564B4F55; // "VKOU"

// Where events posted without a tap go; tests swap in a recorder.
VKEventPoster untappedPoster = nullptr;
void* untappedPosterContext = nullptr;

} // namespace

void setUntappedPoster(VKEventPoster poster, void* context) {
    untappedPoster = poster;
    untappedPosterContext = context;
}

KeySender::KeySender()
    : source_(CGEventSourceCreate(kCGEventSourceStatePrivate)),
      sourceStateId_(source_ ? CGEventSourceGetSourceStateID(source_) : -1) {}

KeySender::~KeySender() {
    if (source_) CFRelease(source_);
}

bool KeySender::isOwnEvent(CGEventRef event) const {
    return CGEventGetIntegerValueField(event, kCGEventSourceUserData) == kSyntheticMarker ||
           CGEventGetIntegerValueField(event, kCGEventSourceStateID) == sourceStateId_;
}

void KeySender::post(CGEventTapProxy proxy, CGEventRef event) {
    CGEventSetIntegerValueField(event, kCGEventSourceUserData, kSyntheticMarker);
    if (journaling_ && CGEventGetType(event) == kCGEventKeyDown) {
        UniChar text[kMaxCharsPerEvent];
        UniCharCount length = 0;
        CGEventKeyboardGetUnicodeString(event, kMaxCharsPerEvent, &length, text);
        journal_.push_back({CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode),
                            std::u16string(reinterpret_cast<const char16_t*>(text), length)});
    }
    if (proxy)
        CGEventTapPostEvent(proxy, event);
    else if (untappedPoster)
        untappedPoster(event, untappedPosterContext);
    else
        CGEventPost(kCGSessionEventTap, event);
    CFRelease(event);
}

// Keeps the event's default flags (non-coalesced); clearing them made some
// apps drop or reorder the synthetic keys.
void KeySender::postKey(CGEventTapProxy proxy, CGKeyCode key, CGEventFlags extraFlags) {
    for (bool down : {true, false}) {
        CGEventRef event = CGEventCreateKeyboardEvent(source_, key, down);
        if (!event) return;
        if (extraFlags) CGEventSetFlags(event, CGEventGetFlags(event) | extraFlags);
        post(proxy, event);
    }
}

// The whole string travels in one key down/up pair, as OpenKey does: fewer
// events means less chance for an app to interleave them wrongly.
void KeySender::postText(CGEventTapProxy proxy, const UniChar* text, int length) {
    for (int start = 0; start < length; start += kMaxCharsPerEvent) {
        const int chunk = std::min(kMaxCharsPerEvent, length - start);
        for (bool down : {true, false}) {
            CGEventRef event = CGEventCreateKeyboardEvent(source_, kTextKey, down);
            if (!event) return;
            CGEventKeyboardSetUnicodeString(event, chunk, text + start);
            post(proxy, event);
        }
    }
}

void KeySender::replace(CGEventTapProxy proxy, int backs, const uint16_t* chars, int count,
                        VKAutocompleteFix fix) {
    if (backs > 0 && fix == VK_AUTOCOMPLETE_FILLER) {
        // Replaces a selected suggestion, then gets deleted with the word.
        postText(proxy, &kAutocompleteFiller, 1);
        backs++;
    }
    for (int i = 0; i < backs; i++) postKey(proxy, kBackspaceKey, 0);
    if (count > 0) postText(proxy, chars, count);
}

// A fresh key down/up with the key's code, flags and text. A copy of the
// event the input method got (rebuilt from an NSEvent) can get lost on the way.
void KeySender::retype(CGEventRef original) {
    UniChar text[kMaxCharsPerEvent];
    UniCharCount length = 0;
    CGEventKeyboardGetUnicodeString(original, kMaxCharsPerEvent, &length, text);
    const auto key = (CGKeyCode)CGEventGetIntegerValueField(original, kCGKeyboardEventKeycode);
    for (bool down : {true, false}) {
        CGEventRef event = CGEventCreateKeyboardEvent(source_, key, down);
        if (!event) return;
        CGEventSetFlags(event, CGEventGetFlags(original));
        if (length > 0) CGEventKeyboardSetUnicodeString(event, length, text);
        post(nullptr, event);
    }
}

// Only the key down is swallowed, so only the key down is re-posted; the real
// key up still follows.
void KeySender::repost(CGEventTapProxy proxy, CGEventRef original) {
    if (CGEventRef event = CGEventCreateCopy(original)) post(proxy, event);
}

} // namespace vk
