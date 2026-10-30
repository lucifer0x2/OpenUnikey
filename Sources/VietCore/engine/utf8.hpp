// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#pragma once

#include <cstdint>

namespace vk {

// Decodes UTF-8 into UTF-16, dropping NUL and malformed bytes.
// Returns the number of UTF-16 units written (at most `capacity`).
inline int decodeUtf8(const unsigned char* in, int size, uint16_t* out, int capacity) {
    int count = 0;
    int i = 0;
    while (i < size) {
        const unsigned char lead = in[i];
        int extra;
        uint32_t cp;
        if (lead < 0x80) {
            extra = 0, cp = lead;
        } else if ((lead & 0xE0) == 0xC0) {
            extra = 1, cp = lead & 0x1F;
        } else if ((lead & 0xF0) == 0xE0) {
            extra = 2, cp = lead & 0x0F;
        } else if ((lead & 0xF8) == 0xF0) {
            extra = 3, cp = lead & 0x07;
        } else {
            i++;
            continue;
        }
        if (i + extra >= size) break; // truncated sequence
        bool valid = true;
        for (int k = 1; k <= extra; k++) {
            if ((in[i + k] & 0xC0) != 0x80) valid = false;
            cp = (cp << 6) | (in[i + k] & 0x3F);
        }
        i += valid ? extra + 1 : 1;
        if (!valid || cp == 0) continue;

        const int units = cp >= 0x10000 ? 2 : 1;
        if (count + units > capacity) break;
        if (units == 2) {
            cp -= 0x10000;
            out[count++] = (uint16_t)(0xD800 + (cp >> 10));
            out[count++] = (uint16_t)(0xDC00 + (cp & 0x3FF));
        } else {
            out[count++] = (uint16_t)cp;
        }
    }
    return count;
}

} // namespace vk
