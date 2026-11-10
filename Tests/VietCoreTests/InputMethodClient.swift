import CoreGraphics
import Foundation
import OpenUnikeyShared
import Testing
import TypingKit
import VietCore

/// A committed client. No synthetic keys are returned to the core, regardless
/// of whether a real client would echo all, some, or none of them. Any post is
/// a test failure, so source markers cannot conceal a second processing pass.
final class InputMethodClient {
    private(set) var text: [UInt16] = []
    private(set) var posts = 0
    private(set) var replacements = 0
    var acceptsReplacement = true
    private var selection = NSRange(location: 0, length: 0)
    private var replacement = CommittedTextReplacement()

    init() {
        var options = VKOptions.standard
        vk_set_options(&options)
        vk_set_vietnamese(true)
        vk_set_autocomplete_fix(VK_AUTOCOMPLETE_NONE)
        vk_im_reset()
        vk_im_set_poster({ _, context in
            let client = Unmanaged<InputMethodClient>.fromOpaque(context!).takeUnretainedValue()
            client.posts += 1
            Issue.record("IMK must never post a rewrite key")
        }, Unmanaged.passUnretained(self).toOpaque())
    }

    deinit { vk_im_set_poster(nil, nil) }

    var string: String { String(decoding: text, as: UTF16.self) }

    func type(_ keys: String) {
        for key in keys { _ = press(key) }
    }

    func suggest(_ suffix: String) {
        selection = NSRange(location: text.count, length: suffix.utf16.count)
        text += suffix.utf16
    }

    @discardableResult
    func press(_ ch: Character, flags: CGEventFlags = [], withClient: Bool = true) -> Bool {
        let code: CGKeyCode
        switch ch {
        case "\u{8}": code = 51
        case "\n": code = 36
        case "\t": code = 48
        default: code = KeyboardLayout.key(for: ch)!.code
        }
        let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true)!
        let keyShift = KeyboardLayout.key(for: ch)?.shift ?? false
        event.flags = keyShift ? flags.union(.maskShift) : flags
        let units = Array(String(ch).utf16)
        event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        if replacement.prepare(selection: selection) { vk_im_reset() }
        let consumed: Bool
        let shortcut = !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty
        if code == 51, !shortcut, replacement.preservesWordForBackspace(selection: selection) {
            consumed = false // native deletion of the suggestion leaves the engine's word intact
        } else if withClient {
            consumed = vk_im_handle_event_with_replacer(event, { backs, chars, count, context in
                let client = Unmanaged<InputMethodClient>.fromOpaque(context!).takeUnretainedValue()
                guard client.acceptsReplacement, backs >= 0, Int(backs) <= client.text.count else {
                    return false
                }
                let output = String(decoding: UnsafeBufferPointer(start: chars, count: Int(count)), as: UTF16.self)
                return client.replacement.replace(backs: Int(backs), text: output, selection: client.selection) {
                    client.apply($0, range: $1)
                    client.replacements += 1
                }
            }, Unmanaged.passUnretained(self).toOpaque())
        } else {
            consumed = vk_im_handle_event(event)
        }
        if !consumed, !shortcut {
            if code == 51 {
                let range = selection.length > 0 ? selection
                    : NSRange(location: max(0, selection.location - 1), length: min(1, selection.location))
                apply("", range: range)
            } else {
                apply(String(ch), range: selection)
            }
            replacement.expectNativeCaret(selection.location)
        } else if !consumed {
            replacement.reset()
        }
        return consumed
    }

    private func apply(_ string: String, range: NSRange) {
        text.replaceSubrange(range.location..<(range.location + range.length), with: string.utf16)
        selection = NSRange(location: range.location + string.utf16.count, length: 0)
    }

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
}
