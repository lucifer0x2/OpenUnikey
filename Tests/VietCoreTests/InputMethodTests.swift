import Foundation
import Testing
import TypingKit
import VietCore

@Suite("Input method", .serialized)
struct InputMethodTests {
    static let sentences: [(String, String)] = [
        ("tieengs vieejt ", "tiếng việt "),
        ("ddaay laf tieesng Vieejt ", "đây là tiếng Việt "),
        ("dduocwj khoong ", "được không "),
        ("nguwowif ", "người "),
        ("asz as ", "a á "),
        ("asb", "áb"),
    ]

    @Test(arguments: sentences)
    func immediateConsecutivePhysicalKeys(keys: (String, String)) {
        let app = InputMethodClient()
        app.type(keys.0)
        #expect(app.string == keys.1)
        #expect(app.posts == 0)
    }

    // No queue or matching survives: waiting beyond the former 500 ms timeout
    // makes no difference, and physical A/Backspace cannot be mistaken for echo.
    @Test func physicalKeysAfterFormerTimeout() async throws {
        let app = InputMethodClient()
        app.type("asz ")
        try await Task.sleep(for: .milliseconds(550))
        app.type("as ")
        #expect(app.string == "a á ")
        #expect(app.posts == 0)
    }

    @Test(arguments: ["as\u{8}s ", "tieengs\u{8}\u{8}ts ", "ddaay\u{8}\u{8} ",
                      "vieejt\u{8}\u{8}\u{8}\u{8}eejt ",
                      "Tooi ddang khoong theer gox tieengs vieejt nafy ",
                      "Mootj hai ba boons, nguwowif ddi trc. "])
    func matchesStandaloneEngine(keys: String) {
        let app = InputMethodClient()
        app.type(keys)
        #expect(app.string == EngineTypist(.standard).type(keys))
        #expect(app.posts == 0)
    }

    @Test func replacementFinishesBeforeNextPhysicalKey() {
        let app = InputMethodClient()
        app.type("a")
        #expect(app.press("s"))
        #expect(app.string == "á") // no Backspace-only intermediate state
        #expect(!app.press("b"))
        #expect(app.string == "áb")
    }

    @Test(arguments: ["\n", "\t"])
    func nativeWordEndFollowsSynchronousRestore(ending: String) {
        let app = InputMethodClient()
        app.type("vieejtx")
        let before = app.replacements
        #expect(!app.press(ending.first!))
        #expect(app.string == "vieejtx" + ending)
        #expect(app.replacements == before + 1)
        #expect(app.posts == 0)
    }

    @Test func unsupportedClientPassesOriginalKeyAndForgetsWord() {
        let app = InputMethodClient()
        app.type("a")
        app.acceptsReplacement = false
        #expect(!app.press("s"))
        #expect(app.string == "as")
        app.acceptsReplacement = true
        app.type("as ")
        #expect(app.string == "asá ")
        #expect(app.posts == 0)
    }

    @Test func absentCallbackCannotPostFallbackKeys() {
        let app = InputMethodClient()
        #expect(!app.press("a", withClient: false))
        #expect(!app.press("s", withClient: false))
        #expect(app.string == "as")
        #expect(app.posts == 0)
    }

    @Test func resetCannotLeaveAnInFlightRewrite() {
        let app = InputMethodClient()
        app.type("as")
        vk_im_reset()
        app.type("as ")
        #expect(app.string == "áá ")
        #expect(app.posts == 0)
    }

    @Test func physicalShortcutCannotMatchBackspaceOrTextEcho() {
        let app = InputMethodClient()
        app.type("as")
        #expect(!app.press("\u{8}", flags: .maskCommand))
        #expect(!app.press("a", flags: .maskCommand))
        app.type("as ")
        #expect(app.string == "áá ")
    }

    @Test func switchKeyAsksForTheOtherSource() {
        let app = InputMethodClient()
        vk_set_switch_key(VK_SWITCH_CONTROL_SHIFT)
        switchPresses = 0
        vk_set_switch_callback({ _ in switchPresses += 1 }, nil)
        defer { vk_set_switch_callback(nil, nil) }
        app.pressSwitchKey()
        app.type("vieejt ")
        #expect(switchPresses == 1)
        #expect(vk_is_vietnamese())
        #expect(app.string == "việt ")
    }

    @Test func switchKeyWorksWhileNotTyping() {
        let app = InputMethodClient()
        vk_set_vietnamese(false)
        switchPresses = 0
        vk_set_switch_callback({ _ in switchPresses += 1 }, nil)
        defer { vk_set_switch_callback(nil, nil) }
        app.type("vieejt ")
        app.pressSwitchKey()
        #expect(switchPresses == 1)
        #expect(app.string == "vieejt ")
    }

    @Test func backspaceDeletesOnlyOwnedSuggestionBeforeToneKey() {
        let app = InputMethodClient()
        app.type("a")
        app.suggest("pple.com")
        #expect(!app.press("\u{8}"))
        #expect(app.string == "a")
        app.type("s")
        #expect(app.string == "á")
    }

    @Test func selectedSuggestionBackspacePreservesPreviousWordHistory() {
        let app = InputMethodClient()
        app.type("nuwow ")
        #expect(app.string == "nươ ")
        app.suggest("suggestion")
        #expect(!app.press("\u{8}"))
        #expect(app.string == "nươ ")
        app.press("\u{8}")
        #expect(app.string == "nươ")
        app.type("cs")
        #expect(app.string == "nước")
    }

    @Test func toneKeyReplacesOwnedSuggestionAndTypedPrefix() {
        let app = InputMethodClient()
        app.type("a")
        app.suggest("pple.com")
        app.type("s")
        #expect(app.string == "á")
    }
}

nonisolated(unsafe) private var switchPresses = 0
