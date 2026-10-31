// OpenUnikey addition to ukengine. LGPL-2.0-or-later, like the rest of this
// folder.
//
// ukengine keeps the keys typed for the current word next to the chars they
// made, and replays the keys when the word turns out not to be Vietnamese.
// Upstream Backspace drops one key per deleted char, but a char can take
// several keys: "pú" + s (undo) is three chars from four keys, so deleting
// the s left "pus" in the key buffer and "pu" + "sh" came back as "pussh".
#include "ukengine.h"

namespace {

// Bounds the search on a Backspace (about 0.1 ms); past it, or when no keys
// fit (upstream Backspace can leave chars no keys type), the upstream guess
// is kept.
constexpr int kMaxReplays = 256;

} // namespace

bool UkEngine::sameWordAs(const UkEngine &other, int wordStart) const {
    if (other.m_current != m_current - wordStart)
        return false;
    for (int i = 0; i <= other.m_current; i++) {
        const WordInfo &mine = m_buffer[wordStart + i];
        const WordInfo &theirs = other.m_buffer[i];
        if (mine.vnSym != theirs.vnSym || mine.tone != theirs.tone)
            return false;
        if (mine.vnSym == vnl_nonVnChar && mine.keyCode != theirs.keyCode)
            return false;
    }
    return true;
}

// Called by synchKeyStrokeBuffer once Backspace removed m_buffer[m_current + 1].
// Finds the fewest keys to drop from the word, latest first, so that typing
// the rest gives the chars still in the buffer, and keeps those keys.
bool UkEngine::resyncWordKeyStrokes() {
    if (m_current < 0 || m_buffer[m_current].form == vnw_empty ||
        m_buffer[m_current + 1].form == vnw_empty)
        return false; // the word is gone, or a word break was deleted

    int keyStart = m_keyCurrent;
    bool converted = false;
    for (; keyStart >= 0 && m_keyStrokes[keyStart].ev.chType != ukcWordBreak;
         keyStart--) {
        converted = converted || m_keyStrokes[keyStart].converted;
    }
    keyStart++;
    if (!converted)
        return false; // every key typed its own char: drop the last one

    int wordStart = m_current;
    while (wordStart > 0 && m_buffer[wordStart - 1].form != vnw_empty)
        wordStart--;

    const int keyCount = m_keyCurrent - keyStart + 1;
    const int charCount = m_current - wordStart + 1;
    bool dropped[MAX_UK_ENGINE] = {};
    int replays = 0;
    UkEngine scratch;
    scratch.setCtrlInfo(m_pCtrl);
    scratch.setCheckKbCaseFunc(m_keyCheckFunc);

    auto typesTheWord = [&]() {
        replays++;
        scratch.reset();
        unsigned char out[1024];
        for (int i = 0; i < keyCount; i++) {
            if (dropped[i])
                continue;
            int backs = 0, size = sizeof(out);
            UkOutputType type;
            scratch.process(m_keyStrokes[keyStart + i].ev.keyCode, backs, out,
                            size, type);
        }
        return sameWordAs(scratch, wordStart);
    };
    // Drops `left` more keys, all before index `below`, trying later ones first.
    auto dropKeys = [&](auto &self, int left, int below) -> bool {
        if (left == 0)
            return typesTheWord();
        for (int i = below - 1; i >= left - 1 && replays < kMaxReplays; i--) {
            dropped[i] = true;
            if (self(self, left - 1, i))
                return true;
            dropped[i] = false;
        }
        return false;
    };

    // Each char left needs at least one key.
    const int maxDrops = keyCount - charCount;
    for (int drops = 1; drops <= maxDrops; drops++) {
        if (!dropKeys(dropKeys, drops, keyCount))
            continue;
        for (int i = 0; i <= scratch.m_keyCurrent; i++)
            m_keyStrokes[keyStart + i] = scratch.m_keyStrokes[i];
        m_keyCurrent = keyStart + scratch.m_keyCurrent;
        m_telexWMapKey = scratch.m_telexWMapKey < 0
                             ? -1
                             : keyStart + scratch.m_telexWMapKey;
        return true;
    }
    return false;
}
