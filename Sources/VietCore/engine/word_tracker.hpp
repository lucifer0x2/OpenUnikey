// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#pragma once

#include <cstdint>
#include <string>

namespace vk {

// Mirrors the current word as shown on screen and the keys typed for it, so
// a foreign word whose doubled letter was used as Telex undo can be restored
// at its end: "Kissinger" is shown as "Kisinger" because "ss" undoes the
// tone. ukengine only restores words that still carry a Vietnamese mark.
class WordTracker {
public:
    void reset();
    // A key belonging to the word was typed and the engine answered with
    // `backs` deletions and `output` (nothing at all means the key went through).
    void onKey(uint8_t key, int backs, const uint16_t* output, int count);
    // Stop restoring this word (Backspace makes the keys unreliable).
    void invalidate() { valid_ = false; }

    // True when the word should be replaced by its keys: it is plain ASCII,
    // shorter than the keys, and the undo was not just the last key (typing
    // "ass" to get "as" stays "as").
    bool shouldRestore() const;
    bool isValid() const { return valid_; }
    const std::u16string& shown() const { return shown_; }
    int shownLength() const { return (int)shown_.size(); }
    const std::string& keys() const { return keys_; }

private:
    std::u16string shown_;
    std::string keys_;
    bool valid_ = true;
};

} // namespace vk
