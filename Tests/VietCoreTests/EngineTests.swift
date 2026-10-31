import Testing
import TypingKit
import VietCore

func typed(_ keys: String, _ options: VKOptions = .standard) -> String {
    EngineTypist(options).type(keys)
}

let vni = VKOptions.standard.with { $0.method = VK_VNI }

// Each engine is independent now; .serialized only keeps the output readable.
@Suite("Telex", .serialized)
struct TelexTests {
    @Test(arguments: [
        ("aa", "â"), ("aw", "ă"), ("ee", "ê"), ("oo", "ô"), ("ow", "ơ"), ("uw", "ư"),
        ("dd", "đ"), ("w", "ư"), ("W", "Ư"),
        ("as", "á"), ("af", "à"), ("ar", "ả"), ("ax", "ã"), ("aj", "ạ"),
    ])
    func singleMarks(keys: String, expected: String) {
        #expect(typed(keys) == expected)
    }

    @Test(arguments: [
        ("vieetj", "việt"), ("vieejt", "việt"), ("tieengs", "tiếng"),
        ("Vieejt Nam", "Việt Nam"), ("VIEEJT", "VIỆT"), ("tooi", "tôi"),
        ("dduwowngf", "đường"), ("nguwowif", "người"), ("quas", "quá"), ("gias", "giá"),
        ("hoaf", "hòa"), ("thuyr", "thủy"), ("hoanf", "hoàn"), ("khuyeens", "khuyến"),
        ("Ddaay laf tieesng Vieejt", "Đây là tiếng Việt"),
    ])
    func words(keys: String, expected: String) {
        #expect(typed(keys) == expected)
    }

    /// Typing styles that broke the UniKey 3.6 engine.
    @Test(arguments: [
        ("ddoans xem nhuw naof", "đoán xem như nào"), ("ddoans xem nhuw nafo", "đoán xem như nào"),
        ("dduowcj", "được"), ("dduocwj", "được"), ("dduwocj", "được"),
        ("nguowif", "người"), ("nguoiwf", "người"), ("truowngf", "trường"),
        ("thuowr", "thuở"), ("khoer", "khỏe"),
    ])
    func hornOnUoAndFreeOrder(keys: String, expected: String) {
        #expect(typed(keys) == expected)
    }

    /// Upstream kept "the last w became ư" in a static, so a lone w leaked
    /// into later words and turned "ow" into "oư".
    @Test func loneWDoesNotLeakIntoLaterWords() {
        #expect(typed("w ow") == "ư ơ")
        #expect(typed("w") == "ư")
        #expect(typed("ow") == "ơ")
        #expect(typed("nhw cow") == "như cơ")
    }

    @Test(arguments: [("aaa", "aa"), ("ddd", "dd"), ("ass", "as"), ("ww", "w"), ("asz", "a")])
    func repeatingAKeyUndoesTheMark(keys: String, expected: String) {
        #expect(typed(keys) == expected)
    }

    @Test func modernStylePutsToneOnLastVowel() {
        let modern = VKOptions.standard.with { $0.modernStyle = true }
        #expect(typed("hoaf", modern) == "hoà")
        #expect(typed("thuyr", modern) == "thuỷ")
    }

    @Test func backspaceEditsTheBufferedWord() {
        #expect(typed("vieet\u{8}j") == "việ")
        #expect(typed("as\u{8}") == "")
        #expect(typed("hoaf\u{8}") == "hò") // the tone moves to the remaining vowel
    }

    /// Typing part of a word, a space, deleting the space and going on must
    /// keep editing the same word.
    @Test(arguments: [
        ("hoajc \u{8}w", "hoặc"), ("hoajc  \u{8}\u{8}w", "hoặc"),
        ("vieet \u{8}j", "việt"), ("nguowi \u{8}f", "người"), ("dduowc \u{8}j", "được"),
        ("tie \u{8}engs", "tiếng"), ("ddu \u{8}owngf", "đường"), ("Vie \u{8}ejt", "Việt"),
        ("tieengs \u{8}", "tiếng"), ("hoaf \u{8}n", "hoàn"),
        // Half-typed words are restored to their keys at the space; Backspace undoes that.
        ("nuwow \u{8}cs", "nước"), ("ddieef \u{8}u", "điều"), ("truwowf \u{8}ng", "trường"),
        ("khuyee \u{8}ns", "khuyến"), ("cuoo \u{8}cj", "cuộc"),
        ("ddie \u{8}euf", "điều"), ("thuaa \u{8}nj", "thuận"), ("hoaw \u{8}cj", "hoặc"),
        ("baw \u{8}ng", "băng"), ("nuwow \u{8}\u{8}", "nư"),
    ])
    func continueAWordAfterDeletingTheSpace(keys: String, expected: String) {
        #expect(typed(keys) == expected)
    }

    @Test func bracketShortcutsAreOptional() {
        #expect(typed("a[]") == "a[]")
        let brackets = VKOptions.standard.with { $0.bracketShortcuts = true }
        #expect(typed("[ ]", brackets) == "ơ ư")
    }

    @Test func englishWordsAreRestoredAtWordEnd() {
        #expect(typed("windows ") == "windows ")
        #expect(typed("text ") == "text ")
        #expect(typed("text\n") == "text\n")
    }

    /// A doubled tone key is Telex undo: the letter stays once and the word
    /// keeps what the screen shows at its end, as in UniKey ("pussh" is "push").
    @Test(arguments: [
        ("pussh ", "push "), ("urrl ", "url "), ("tesst ", "test "), ("urrl\n", "url\n"),
        ("pussh,", "push,"), ("ass ", "as "), ("tooo ", "too "), ("Kissinger ", "Kisinger "),
        // deleting the word must not glue the next one to the word before
        ("vaf pussh \u{8}\u{8}\u{8}\u{8}\u{8}push ", "và push "),
        ("vaf pussh \u{8}\u{8}\u{8}\u{8}\u{8}\u{8}\u{8}af ", "và "),
    ])
    func doubledToneKeyStaysUndone(keys: String, expected: String) {
        #expect(typed(keys) == expected)
    }

    /// Backspace must drop every key of the deleted char, not one key per
    /// char, or the extra keys come back when the word is restored.
    @Test(arguments: [
        ("hayx push\u{8}sh\u{8}\u{8}sh ", "hãy push "),
        ("hayx push\u{8}sh\u{8}\u{8}\u{8}pus\u{8}\u{8}\u{8}ush ", "hãy push "),
        ("pussh\u{8}\u{8}\u{8}\u{8}push ", "push "),
        ("push\u{8}sh\u{8}\u{8}\u{8}\u{8}push ", "push "),
        ("raaxsr\u{8}eesh ", "reesh "), ("tieengs\u{8}k ", "tieensk "),
        // still Vietnamese: the buffer edits are unchanged
        ("tieengs\u{8}\u{8}n ", "tiến "),
        ("vieetj\u{8}\u{8}eetj ", "việt "), ("aaa\u{8}a ", "â "),
    ])
    func backspaceKeepsTheKeysOfTheWord(keys: String, expected: String) {
        #expect(typed(keys) == expected)
    }

    @Test func separatorsStartANewWord() {
        #expect(typed("as.") == "á.")
        #expect(typed("as\ns") == "á\ns")
    }
}

@Suite("VNI", .serialized)
struct VniTests {
    @Test(arguments: [
        ("a6", "â"), ("a8", "ă"), ("o7", "ơ"), ("u7", "ư"), ("d9", "đ"),
        ("a1", "á"), ("a2", "à"), ("a3", "ả"), ("a4", "ã"), ("a5", "ạ"),
        ("vie65t", "việt"), ("d9u7o7ng2", "đường"), ("d9uo7c5", "được"),
        ("Vie65t Nam", "Việt Nam"), ("a11", "a1"), ("a66", "a6"),
    ])
    func typing(keys: String, expected: String) {
        #expect(typed(keys, vni) == expected)
    }
}
