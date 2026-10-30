// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#pragma once

#include <cstdint>
#include <string>

namespace vk {

// Mirrors the current word as shown on screen and the keys typed for it, so a
// word ukengine restored at its end can be brought back by Backspace. A
// doubled key is Telex undo and stays undone: "pussh" is "push", as in UniKey.
class WordTracker {
public:
    void reset();
    // A key belonging to the word was typed and the engine answered with
    // `backs` deletions and `output` (nothing at all means the key went through).
    void onKey(uint8_t key, int backs, const uint16_t* output, int count);
    // Stop restoring this word (Backspace makes the keys unreliable).
    void invalidate() { valid_ = false; }

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
