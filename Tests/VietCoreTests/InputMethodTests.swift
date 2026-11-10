import CoreGraphics
import Testing
import TypingKit
import VietCore

/// A text field in an app with OpenUnikey's input method selected. Keys go
/// through the input method first; what it consumes is replaced by the key
/// events it posts, which reach the app later (WindowServer round trip) and
/// pass through the input method again, as on a real Mac. Posted text keys can
/// be set to skip the input method: in ReClaude they did not come back to it.
final class SimulatedApp {
    private(set) var text: [UInt16] = []
    private var inTransit: [CGEvent] = []
    let postedTextReturns: Bool

    init(postedTextReturns: Bool) {
        self.postedTextReturns = postedTextReturns
        var options = VKOptions.standard
        vk_set_options(&options)
        vk_set_vietnamese(true)
        vk_set_autocomplete_fix(VK_AUTOCOMPLETE_NONE)
        vk_im_reset()
        vk_im_set_poster({ event, context in
            guard let event, let context, event.type == .keyDown else { return }
            let app = Unmanaged<SimulatedApp>.fromOpaque(context).takeUnretainedValue()
            app.inTransit.append(event.copy()!)
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit { vk_im_set_poster(nil, nil) }

    var string: String { String(decoding: text, as: UTF16.self) }

    /// Types `keys` one by one; `settleEvery` keys, the posted keys arrive.
    /// 1 is slow typing; larger values are keys pressed before the rewrite
    /// of the previous ones has come back (about 10 ms on a real Mac). The
    /// same key cannot be pressed twice that fast, so a key still on its way
    /// back arrives first.
    func type(_ keys: String, settleEvery: Int = 1) {
        for (index, ch) in keys.enumerated() {
            if isInTransit(ch) { settle() }
            press(ch)
            if (index + 1) % settleEvery == 0 { settle() }
        }
        settle()
    }

    private func isInTransit(_ ch: Character) -> Bool {
        let code = ch == "\u{8}" ? KeyboardLayout.backspaceKey.code : KeyboardLayout.key(for: ch)?.code
        return inTransit.contains { $0.getIntegerValueField(.keyboardEventKeycode) == Int64(code ?? 0xFFFF) }
    }

    func press(_ ch: Character) {
        let key = ch == "\u{8}" ? KeyboardLayout.backspaceKey : KeyboardLayout.key(for: ch)!
        let event = CGEvent(keyboardEventSource: nil, virtualKey: key.code, keyDown: true)!
        event.flags = key.shift ? .maskShift : []
        let units = ch == "\u{8}" ? [UInt16(8)] : Array(String(ch).utf16)
        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        deliver(event, posted: false)
    }

    /// A lone Control+Shift, pressed and released one key at a time.
    func pressSwitchKey() {
        let steps: [(CGKeyCode, CGEventFlags)] = [
            (59, .maskControl), (56, [.maskControl, .maskShift]), (56, .maskControl), (59, []),
        ]
        for (code, flags) in steps {
            let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)!
            event.type = .flagsChanged
            event.flags = flags
            _ = vk_im_handle_event(event)
        }
    }

    /// Delivers what the input method posted so far, in order.
    func settle() {
        var deliveries = 0
        while !inTransit.isEmpty {
            deliveries += 1
            guard deliveries < 500 else {
                Issue.record("the input method keeps posting: \(string)")
                inTransit.removeAll()
                return
            }
            deliver(inTransit.removeFirst(), posted: true)
        }
    }

    private func deliver(_ event: CGEvent, posted: Bool) {
        // Text rides on key code 0 (A); a retyped A key is an ordinary key.
        let isText = posted && event.getIntegerValueField(.keyboardEventKeycode) == 0
            && unicode(of: event) != Array("a".utf16)
        let throughInputMethod = !isText || postedTextReturns
        if throughInputMethod && vk_im_handle_event(event) { return }
        apply(event)
    }

    private func apply(_ event: CGEvent) {
        if event.getIntegerValueField(.keyboardEventKeycode) == 51 {
            if !text.isEmpty { text.removeLast() }
        } else {
            text += unicode(of: event)
        }
    }

    private func unicode(of event: CGEvent) -> [UInt16] {
        var buffer = [UniChar](repeating: 0, count: 32)
        var length = 0
        event.keyboardGetUnicodeString(maxStringLength: 32, actualStringLength: &length,
                                       unicodeString: &buffer)
        return Array(buffer.prefix(length))
    }
}

@Suite("Input method", .serialized)
struct InputMethodTests {
    static let sentences: [(String, String)] = [
        ("tieengs vieejt ", "tiếng việt "),
        ("ddaay laf tieesng Vieejt ", "đây là tiếng Việt "),
        ("dduocwj khoong ", "được không "),
        ("nguwowif ", "người "),
    ]

    @Test(arguments: sentences, [true, false])
    func slowTyping(keys: (String, String), postedTextReturns: Bool) {
        let app = SimulatedApp(postedTextReturns: postedTextReturns)
        app.type(keys.0)
        #expect(app.string == keys.1)
    }

    /// Several keys pressed before the rewrite comes back (fast typing,
    /// rollover): they must not overtake it.
    @Test(arguments: sentences, [2, 3, 5])
    func fastTyping(keys: (String, String), settleEvery: Int) {
        let app = SimulatedApp(postedTextReturns: false)
        app.type(keys.0, settleEvery: settleEvery)
        #expect(app.string == keys.1)
    }

    /// Reported: at the end of a word Space had to be pressed twice.
    @Test(arguments: [true, false])
    func oneSpaceEndsTheWord(postedTextReturns: Bool) {
        let app = SimulatedApp(postedTextReturns: postedTextReturns)
        app.type("ddeen")
        app.press(" ")
        app.settle()
        #expect(app.string == "đên ")
    }

    /// Whatever the engine makes of Backspace, the app must show the same.
    @Test(arguments: ["tieengs\u{8}\u{8}ts ", "ddaay\u{8}\u{8} ", "vieejt\u{8}\u{8}\u{8}\u{8}eejt "],
          [true, false])
    func backspaceMatchesTheEngine(keys: String, postedTextReturns: Bool) {
        let app = SimulatedApp(postedTextReturns: postedTextReturns)
        app.type(keys)
        #expect(app.string == EngineTypist(.standard).type(keys))
    }

    @Test(arguments: ["Tooi ddang khoong theer gox tieengs vieejt nafy ",
                      "Mootj hai ba boons, nguwowif ddi trc. "], [1, 2, 4])
    func longerTextMatchesTheEngine(keys: String, settleEvery: Int) {
        let app = SimulatedApp(postedTextReturns: false)
        app.type(keys, settleEvery: settleEvery)
        #expect(app.string == EngineTypist(.standard).type(keys))
    }

    /// The switch key selects the other input source and leaves V/E alone:
    /// the input method keeps typing Vietnamese (it was once left in English
    /// with nothing showing it).
    @Test func switchKeyAsksForTheOtherSource() {
        let app = SimulatedApp(postedTextReturns: false)
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

    /// The menu bar app's tap types nothing but still sees the switch key.
    @Test func switchKeyWorksWhileNotTyping() {
        let app = SimulatedApp(postedTextReturns: false)
        vk_set_vietnamese(false)
        switchPresses = 0
        vk_set_switch_callback({ _ in switchPresses += 1 }, nil)
        defer { vk_set_switch_callback(nil, nil) }

        app.type("vieejt ")
        app.pressSwitchKey()
        #expect(switchPresses == 1)
        #expect(app.string == "vieejt ")
    }
}

nonisolated(unsafe) private var switchPresses = 0
