// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "engine/engine.hpp"

#include <algorithm>
#include <mutex>

#include "engine/unfinished_syllable.hpp"
#include "engine/utf8.hpp"
#include "ukengine/ukengine.h"

namespace vk {
namespace {

UkInputMethod toUkMethod(InputMethod method) {
    switch (method) {
    case InputMethod::Vni:
        return UkVni;
    case InputMethod::SimpleTelex:
        return UkSimpleTelex;
    case InputMethod::Telex:
        break;
    }
    return UkTelex;
}

// ukengine fills process-wide tables when engines and input processors are
// set up, and rewrites them each time; doing it once keeps engines on other
// threads from reading half-built tables.
void setUpGlobalTablesOnce() {
    static std::once_flag once;
    std::call_once(once, [] {
        SetupUnikeyEngine(); // also builds the input classifier table
        UkEngine warmUp;     // the first engine sorts the shared vowel tables
    });
}

// Telex keymap with [ ] { } as plain keys.
void useTelexWithoutBrackets(UkInputProcessor& input) {
    int keyMap[256];
    input.setIM(UkTelex);
    input.getKeyMap(keyMap);
    for (unsigned char key : {'[', ']', '{', '}'}) keyMap[key] = vneNormal;
    input.setIM(keyMap);
}

} // namespace

struct Engine::Impl {
    UkSharedMem shared{};
    UkEngine engine;
    int shiftPressed = 0;
    int capsLockOn = 0;
    unsigned char raw[1024];

    Impl() {
        shared.input.setIM(UkTelex); // init() would rebuild the global tables
        shared.macStore.init();
        shared.vietKey = true;
        shared.usrKeyMapLoaded = false;
        shared.charsetId = CONV_CHARSET_XUTF8;
        engine.setCtrlInfo(&shared);
        engine.setCheckKbCaseFunc([this](int* shift, int* caps) {
            *shift = shiftPressed;
            *caps = capsLockOn;
        });
    }
};

Engine::Engine() {
    setUpGlobalTablesOnce();
    impl_ = std::make_unique<Impl>();
    configure(Options{});
}

Engine::~Engine() = default;

void Engine::configure(const Options& options) {
    UkSharedMem& shared = impl_->shared;
    if (options.method == InputMethod::Telex && !options.bracketShortcuts)
        useTelexWithoutBrackets(shared.input);
    else
        shared.input.setIM(toUkMethod(options.method));

    UnikeyOptions& o = shared.options;
    o = UnikeyOptions{};
    o.freeMarking = options.freeMarking;
    o.modernStyle = options.modernStyle;
    o.spellCheckEnabled = options.spellCheck;
    o.autoNonVnRestore = options.autoRestore;
    restoreForeignWords_ = options.spellCheck && options.autoRestore;
    digitsAreKeys_ = options.method == InputMethod::Vni;
    reset();
}

void Engine::reset() {
    impl_->engine.reset();
    tracker_.reset();
    restored_.armed = false;
    previousWordArmed_ = false;
    backs_ = 0;
    outputLength_ = 0;
}

void Engine::process(uint8_t ch, bool shift, bool capsLock) {
    impl_->shiftPressed = shift;
    impl_->capsLockOn = capsLock;
    restored_.armed = false;
    previousWordArmed_ = false;
    runEngine(ch);
    const bool letter = (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z');
    if (letter || (digitsAreKeys_ && ch >= '0' && ch <= '9')) {
        tracker_.onKey(ch, backs_, output_, outputLength_);
        return;
    }
    restoreForeignWord(ch);
    rememberRestoredWord();
    previousWord_ = tracker_;
    previousWordArmed_ = !restored_.armed;
    tracker_.reset();
}

void Engine::backspace() {
    if (restored_.armed && isUnfinishedSyllable(restored_.shown)) {
        undoRestoredWord();
        return;
    }
    restored_.armed = false;
    int backs = 0;
    int size = sizeof(impl_->raw);
    UkOutputType type;
    impl_->engine.processBackspace(backs, impl_->raw, size, type);
    takeResult(backs, impl_->raw, size);
    if (previousWordArmed_ && backs_ <= 1 && outputLength_ == 0) {
        tracker_ = previousWord_; // only the break char went away
    } else {
        tracker_.invalidate();
    }
    previousWordArmed_ = false;
}

void Engine::endWord() {
    // ukengine treats key code 0 as a word break (as fcitx5-unikey does).
    restored_.armed = false;
    previousWordArmed_ = false;
    runEngine(0);
    restoreForeignWord(0);
    tracker_.reset();
}

void Engine::runEngine(unsigned int keyCode) {
    int backs = 0;
    int size = sizeof(impl_->raw);
    UkOutputType type;
    impl_->engine.process(keyCode, backs, impl_->raw, size, type);
    takeResult(backs, impl_->raw, size);
}

// Called at a word break the engine let through: puts back the typed keys of
// a foreign word that Telex undo shortened, followed by the break char.
void Engine::restoreForeignWord(uint8_t breakChar) {
    if (!restoreForeignWords_ || backs_ != 0 || outputLength_ != 0) return;
    if ((int)tracker_.keys().size() + 1 > kMaxOutput || !tracker_.shouldRestore()) return;
    backs_ = tracker_.shownLength();
    outputLength_ = 0;
    for (char key : tracker_.keys()) output_[outputLength_++] = (uint8_t)key;
    if (breakChar) output_[outputLength_++] = breakChar;
}

// A word break that rewrote the word (ukengine or restoreForeignWord) restored
// it to its keys; remember how to bring the typed form back.
void Engine::rememberRestoredWord() {
    if (backs_ == 0 || !tracker_.isValid()) return;
    restored_ = {true, tracker_.keys(), tracker_.shown(), outputLength_};
}

// Backspace right after the restore of a half-typed word: the space was a slip,
// so put the word back as it was typed and let the engine continue it.
void Engine::undoRestoredWord() {
    const RestoredWord word = restored_;
    restored_.armed = false;
    impl_->engine.reset();
    tracker_.reset();
    for (char key : word.keys) {
        impl_->shiftPressed = key >= 'A' && key <= 'Z';
        impl_->capsLockOn = 0;
        runEngine((uint8_t)key);
        tracker_.onKey((uint8_t)key, backs_, output_, outputLength_);
    }
    backs_ = word.screenLength;
    const std::u16string& shown = tracker_.shown();
    outputLength_ = std::min((int)shown.size(), kMaxOutput);
    std::copy(shown.begin(), shown.begin() + outputLength_, output_);
}

void Engine::takeResult(int backs, const unsigned char* utf8, int size) {
    backs_ = backs;
    outputLength_ = decodeUtf8(utf8, size, output_, kMaxOutput);
}

} // namespace vk
