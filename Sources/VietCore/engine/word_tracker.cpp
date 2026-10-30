// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "engine/word_tracker.hpp"

namespace vk {

void WordTracker::reset() {
    shown_.clear();
    keys_.clear();
    valid_ = true;
}

void WordTracker::onKey(uint8_t key, int backs, const uint16_t* output, int count) {
    keys_.push_back((char)key);
    if (backs == 0 && count == 0) {
        shown_.push_back(key);
        return;
    }
    if (backs > (int)shown_.size()) { // the engine reached past this word
        valid_ = false;
        return;
    }
    shown_.resize(shown_.size() - backs);
    shown_.append(output, output + count);
}

bool WordTracker::shouldRestore() const {
    if (!valid_ || shown_.size() < 2 || keys_.size() <= shown_.size()) return false;
    for (char16_t ch : shown_) {
        const bool asciiLetter = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
        if (!asciiLetter) return false; // still Vietnamese, or not a word
    }
    const std::u16string allButLastKey(keys_.begin(), keys_.end() - 1);
    return allButLastKey != shown_;
}

} // namespace vk
