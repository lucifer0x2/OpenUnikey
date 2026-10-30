// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
// Thin wrapper over ukengine (x-unikey / fcitx5-unikey) that hides its headers
// and turns its UTF-8 output into UTF-16 for the event tap.
#pragma once

#include <cstdint>
#include <memory>
#include <string>

#include "engine/word_tracker.hpp"

namespace vk {

enum class InputMethod : uint8_t { Telex = 0, Vni = 1, SimpleTelex = 2 };

struct Options {
    InputMethod method = InputMethod::Telex;
    bool freeMarking = true;      // allow marks after the word's consonants
    bool modernStyle = false;     // oà, uý instead of òa, úy
    bool spellCheck = true;       // stop converting words that are not Vietnamese
    bool autoRestore = true;      // restore the keys of a non-Vietnamese word at its end
    bool bracketShortcuts = false; // Telex [ ] { } -> ơ ư Ơ Ư
};

// After each call: delete backs() characters, then insert output().
// backs() == 0 && outputLength() == 0 means "let the key through untouched".
class Engine {
public:
    static constexpr int kMaxOutput = 256;

    Engine();
    ~Engine();
    Engine(const Engine&) = delete;
    Engine& operator=(const Engine&) = delete;

    void configure(const Options& options);
    void reset();
    // ch is a printable ASCII char produced by the key.
    void process(uint8_t ch, bool shift, bool capsLock);
    void backspace();
    // Ends the current word (Return, Tab): may restore a non-Vietnamese word.
    void endWord();

    int backs() const { return backs_; }
    int outputLength() const { return outputLength_; }
    const uint16_t* output() const { return output_; }

private:
    struct Impl;
    void runEngine(unsigned int keyCode);
    void restoreForeignWord(uint8_t breakChar);
    void rememberRestoredWord();
    void undoRestoredWord();
    void takeResult(int backs, const unsigned char* utf8, int size);

    std::unique_ptr<Impl> impl_;
    WordTracker tracker_;
    // The word before the last break, in case Backspace deletes the break and
    // the word goes on (ukengine continues it too).
    WordTracker previousWord_;
    bool previousWordArmed_ = false;
    // The word restored to its keys at the last word break, so a Backspace
    // right after can bring it back ("nươ" + Space -> "nuwow ", Backspace -> "nươ").
    struct RestoredWord {
        bool armed = false;
        std::string keys;
        std::u16string shown;
        int screenLength = 0; // restored keys + break char now on screen
    } restored_;
    bool restoreForeignWords_ = true;
    bool digitsAreKeys_ = false;
    int backs_ = 0;
    int outputLength_ = 0;
    uint16_t output_[kMaxOutput];
};

} // namespace vk
