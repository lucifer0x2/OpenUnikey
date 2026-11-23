// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "tap/key_log.hpp"

#include <chrono>
#include <cstdio>
#include <ctime>

#include "tap/key_log_file.hpp"

namespace vk {
namespace {

// UTF-16 to UTF-8, enough for the short strings the tap handles. Control chars
// (Return, Backspace...) become \xNN so each event stays on one line.
std::string printable(const UniChar* text, int length) {
    std::string out;
    for (int i = 0; i < length; i++) {
        const uint32_t c = text[i];
        if (c < 0x20 || c == 0x7F) {
            char escaped[8];
            std::snprintf(escaped, sizeof(escaped), "\\x%02x", (unsigned)c);
            out += escaped;
        } else if (c < 0x80) {
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

// Local wall-clock time with milliseconds, to match a bug to the moment seen.
std::string wallClock() {
    using namespace std::chrono;
    const auto now = system_clock::now();
    const std::time_t seconds = system_clock::to_time_t(now);
    const int millis = (int)(duration_cast<milliseconds>(now.time_since_epoch()).count() % 1000);
    std::tm local{};
    localtime_r(&seconds, &local);
    char text[32];
    const size_t length = std::strftime(text, sizeof(text), "%Y-%m-%d %H:%M:%S", &local);
    std::snprintf(text + length, sizeof(text) - length, ".%03d", millis);
    return text;
}

} // namespace

bool keyLogEnabled() { return keyLogFile().running(); }

void logKeyEvent(CGEventRef event, CGEventType type, const char* action, int backs,
                 const uint16_t* output, int outputLength) {
    if (!keyLogEnabled()) return;
    UniChar text[8];
    UniCharCount length = 0;
    CGEventKeyboardGetUnicodeString(event, 8, &length, text);
    char fields[256];
    std::snprintf(fields, sizeof(fields),
                  "' flags=%llx repeat=%lld srcpid=%lld state=%lld kbd=%lld ts=%llu -> %s backs=%d",
                  (unsigned long long)CGEventGetFlags(event),
                  CGEventGetIntegerValueField(event, kCGKeyboardEventAutorepeat),
                  CGEventGetIntegerValueField(event, kCGEventSourceUnixProcessID),
                  CGEventGetIntegerValueField(event, kCGEventSourceStateID),
                  CGEventGetIntegerValueField(event, kCGKeyboardEventKeyboardType),
                  (unsigned long long)CGEventGetTimestamp(event), action, backs);
    keyLogFile().append(wallClock() + " type=" + std::to_string((int)type) +
                        " key=" + std::to_string(CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode)) +
                        " char='" + printable(text, (int)length) + fields + " out='" +
                        printable(output, outputLength) + "'");
}

void logKeyNote(const std::string& text) {
    if (!keyLogEnabled()) return;
    std::string line = wallClock() + " note ";
    for (char c : text) {
        if ((unsigned char)c < 0x20) {
            char escaped[8];
            std::snprintf(escaped, sizeof(escaped), "\\x%02x", (unsigned)(unsigned char)c);
            line += escaped;
        } else {
            line += c;
        }
    }
    keyLogFile().append(line);
}

} // namespace vk
