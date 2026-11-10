// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "tap/tap_session.hpp"

#include "tap/key_log.hpp"
#include "tap/shared_state.hpp"

namespace vk {
namespace {

constexpr int64_t kBackspaceKey = 51; // kVK_Delete
constexpr int64_t kReturnKey = 36;    // kVK_Return
constexpr int64_t kTabKey = 48;       // kVK_Tab
constexpr int64_t kEnterKey = 76;     // kVK_ANSI_KeypadEnter
constexpr CGEventFlags kShortcutMods =
    kCGEventFlagMaskCommand | kCGEventFlagMaskControl | kCGEventFlagMaskAlternate;

// The printable ASCII char a key produces in the current layout, if any.
bool readPrintableAscii(CGEventRef event, uint8_t& out) {
    UniChar text[4];
    UniCharCount length = 0;
    CGEventKeyboardGetUnicodeString(event, 4, &length, text);
    if (length != 1 || text[0] < 0x20 || text[0] >= 0x7F) return false;
    out = (uint8_t)text[0];
    return true;
}

// Keys typed in E mode never reach the engine, so they stay out of the log.
bool shouldLogKeys() {
    return keyLogEnabled() && sharedState().vietnamese.load(std::memory_order_relaxed);
}

} // namespace

CGEventRef TapSession::handle(CGEventTapProxy proxy, CGEventType type, CGEventRef event) {
    if (sender_.isOwnEvent(event)) {
        if (shouldLogKeys()) logKeyEvent(event, type, "own", 0, nullptr, 0);
        return event;
    }
    switch (type) {
    case kCGEventKeyDown: {
        CGEventRef result = handleKeyDown(proxy, event);
        if (shouldLogKeys())
            logKeyEvent(event, type, result ? "pass" : "rewrite", engine_.backs(),
                        engine_.output(), engine_.outputLength());
        return result;
    }
    case kCGEventFlagsChanged:
        handleFlagsChanged(event);
        return event;
    default:
        return event;
    }
}

CGEventRef TapSession::handleKeyDown(CGEventTapProxy proxy, CGEventRef event) {
    SharedState& state = sharedState();
    const CGEventFlags flags = CGEventGetFlags(event);
    const int64_t keycode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    const auto switchKey = (VKSwitchKey)state.switchKey.load(std::memory_order_relaxed);

    if (hotkey_.onKeyDown(keycode, flags, switchKey)) {
        toggleMode();
        return nullptr;
    }
    if (!state.vietnamese.load(std::memory_order_relaxed)) return event;
    syncWithSharedState();

    if (flags & kShortcutMods) {
        engine_.reset();
        return event;
    }
    if (keycode == kBackspaceKey) return handleBackspace(proxy, event);
    if (keycode == kReturnKey || keycode == kEnterKey || keycode == kTabKey)
        return handleWordEnd(proxy, event);

    uint8_t ch = 0;
    if (!readPrintableAscii(event, ch)) { // arrows, Escape, function keys...
        engine_.reset();
        return event;
    }
    engine_.process(ch, flags & kCGEventFlagMaskShift, flags & kCGEventFlagMaskAlphaShift);
    const int count = engine_.outputLength();
    const bool sameAsKey = count == 1 && engine_.output()[0] == ch;
    if (engine_.backs() == 0 && (count == 0 || sameAsKey))
        return event; // nothing to rewrite: deliver the original key

    sendEngineOutput(proxy);
    return nullptr;
}

CGEventRef TapSession::handleBackspace(CGEventTapProxy proxy, CGEventRef event) {
    engine_.backspace();
    // backs counts the character this Backspace deletes, so 1 means "just let
    // the real key do it".
    if (engine_.outputLength() == 0 && engine_.backs() <= 1) return event;
    sendEngineOutput(proxy);
    return nullptr;
}

CGEventRef TapSession::handleWordEnd(CGEventTapProxy proxy, CGEventRef event) {
    engine_.endWord(); // may restore a non-Vietnamese word
    const bool rewrite = engine_.backs() > 0 || engine_.outputLength() > 0;
    if (rewrite) {
        sendEngineOutput(proxy);
        sender_.repost(proxy, event); // keep Return/Tab after the restored word
    }
    engine_.reset();
    return rewrite ? nullptr : event;
}

void TapSession::sendEngineOutput(CGEventTapProxy proxy) {
    const auto fix = (VKAutocompleteFix)sharedState().autocompleteFix.load(std::memory_order_relaxed);
    sender_.replace(proxy, engine_.backs(), engine_.output(), engine_.outputLength(), fix);
}

void TapSession::handleFlagsChanged(CGEventRef event) {
    const auto switchKey = (VKSwitchKey)sharedState().switchKey.load(std::memory_order_relaxed);
    if (hotkey_.onFlagsChanged(CGEventGetFlags(event), switchKey)) toggleMode();
}

void TapSession::syncWithSharedState() {
    SharedState& state = sharedState();
    const uint32_t version = state.optionVersion.load(std::memory_order_acquire);
    if (version != appliedOptionVersion_) {
        appliedOptionVersion_ = version;
        const uint32_t bits = state.optionBits.load(std::memory_order_acquire);
        engine_.configure(unpackOptions(bits));
        logKeyNote("options " + std::to_string(bits));
    }
    if (state.resetRequested.exchange(false, std::memory_order_acq_rel)) {
        engine_.reset();
        logKeyNote("engine reset (click, app switch or V/E from the menu)");
    }
}

void TapSession::toggleMode() {
    SharedState& state = sharedState();
    if (VKSwitchCallback callback = state.switchCallback.load()) {
        engine_.reset();
        logKeyNote("switch key: input source");
        callback(state.switchContext.load());
        return;
    }
    const bool vietnamese = !state.vietnamese.load();
    state.vietnamese.store(vietnamese);
    engine_.reset();
    logKeyNote(vietnamese ? "mode V (switch key)" : "mode E (switch key)");
    if (VKModeCallback callback = state.modeCallback.load())
        callback(vietnamese, state.modeContext.load());
}

} // namespace vk
