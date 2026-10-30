// OpenUnikey - Vietnamese input for macOS. GPL v2 or later.
#include "engine/unfinished_syllable.hpp"

#include <initializer_list>

namespace vk {
namespace {

// Each row: the toneless lower-case vowel, then its 12 forms (6 tones x 2 cases).
const char16_t* const kVowels[] = {
    u"aaàáảãạAÀÁẢÃẠ", u"âââầấẩẫậÂẦẤẨẪẬ", u"ăăằắẳẵặĂẰẮẲẴẶ", u"eeèéẻẽẹEÈÉẺẼẸ",
    u"êêềếểễệÊỀẾỂỄỆ", u"iiìíỉĩịIÌÍỈĨỊ", u"ooòóỏõọOÒÓỎÕỌ", u"ôôồốổỗộÔỒỐỔỖỘ",
    u"ơơờớởỡợƠỜỚỞỠỢ", u"uuùúủũụUÙÚỦŨỤ", u"ưưừứửữựƯỪỨỬỮỰ", u"yyỳýỷỹỵYỲÝỶỸỴ",
};

char16_t tonelessLower(char16_t ch) {
    for (const char16_t* row : kVowels) {
        for (const char16_t* form = row + 1; *form; form++) {
            if (*form == ch) return row[0];
        }
    }
    return 0; // not a vowel
}

// Vowel endings no Vietnamese syllable can stop at. They need a final
// consonant (â, ăn, iêng, ươc, uân, oăc...) or are steps on the way to a marked
// vowel when typing Telex (ie -> iê, uo -> uô/ươ, eu -> êu, uu -> ưu).
const std::initializer_list<std::u16string> kUnfinishedEndings = {
    u"â", u"ă", u"iê", u"yê", u"uô", u"ươ", u"ưo", u"uâ", u"oă",
    u"ie", u"ye", u"uo", u"eu", u"ue", u"uu",
};

bool endsWith(const std::u16string& text, const std::u16string& suffix) {
    return text.size() >= suffix.size() &&
           text.compare(text.size() - suffix.size(), suffix.size(), suffix) == 0;
}

} // namespace

bool isUnfinishedSyllable(const std::u16string& word) {
    std::u16string vowels; // the vowel run at the end of the word, toneless
    for (auto it = word.rbegin(); it != word.rend(); ++it) {
        const char16_t vowel = tonelessLower(*it);
        if (!vowel) break;
        vowels.insert(vowels.begin(), vowel);
    }
    if (vowels.empty()) return false;
    for (const std::u16string& ending : kUnfinishedEndings) {
        if (endsWith(vowels, ending)) return true;
    }
    return false;
}

} // namespace vk
