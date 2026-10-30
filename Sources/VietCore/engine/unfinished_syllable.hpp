// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#pragma once

#include <string>

namespace vk {

// True when `word` stops at a vowel ending no Vietnamese syllable can end
// with, i.e. a word typed halfway: "nươ" (nước), "đie" (điều), "khuyê"
// (khuyến), "thuậ" (thuận), "hoặ" (hoặc), "bă" (băng).
bool isUnfinishedSyllable(const std::u16string& word);

} // namespace vk
