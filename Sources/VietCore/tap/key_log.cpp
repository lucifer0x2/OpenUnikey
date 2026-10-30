// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "tap/key_log.hpp"

#include <atomic>
#include <os/log.h>
#include <string>

namespace vk {
namespace {

std::atomic<bool> enabled{false};

os_log_t keysLog() {
    static os_log_t log = os_log_create("io.github.openunikey", "keys");
    return log;
}

// UTF-16 to UTF-8, enough for the short strings the tap handles.
std::string toUtf8(const UniChar* text, int length) {
    std::string out;
    for (int i = 0; i < length; i++) {
        const uint32_t c = text[i];
        if (c < 0x80) {
            out += (char)c;
        } else if (c < 0x800) {
            out += (char)(0xC0 | (c >> 6));
            out += (char)(0x80 | (c & 0x3F));
        } else {
            out += (char)(0xE0 | (c >> 12));
            out += (char)(0x80 | ((c >> 6) & 0x3F));
            out += (char)(0x80 | (c & 0x3F));
        }
    }
    return out;
}

} // namespace

bool keyLogEnabled() { return enabled.load(std::memory_order_relaxed); }
void setKeyLogEnabled(bool on) { enabled.store(on, std::memory_order_relaxed); }

void logKeyEvent(CGEventRef event, CGEventType type, const char* action, int backs,
                 const uint16_t* output, int outputLength) {
    if (!keyLogEnabled()) return;
    UniChar text[8];
    UniCharCount length = 0;
    CGEventKeyboardGetUnicodeString(event, 8, &length, text);
    const std::string typed = toUtf8(text, (int)length);
    const std::string out = toUtf8(output, outputLength);
    os_log(keysLog(),
           "type=%{public}d key=%{public}lld char='%{public}s' flags=%{public}llx repeat=%{public}lld "
           "srcpid=%{public}lld state=%{public}lld kbd=%{public}lld ts=%{public}llu "
           "-> %{public}s backs=%{public}d out='%{public}s'",
           (int)type, CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode), typed.c_str(),
           (unsigned long long)CGEventGetFlags(event),
           CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat),
           CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID),
           CGEventGetIntegerValueField(event, kCGEventSourceStateID),
           CGEventGetIntegerValueField(event, kCGKeyboardEventKeyboardType),
           (unsigned long long)CGEventGetTimestamp(event), action, backs, out.c_str());
}

} // namespace vk
