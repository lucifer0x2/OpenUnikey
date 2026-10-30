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

} // namespace vk
