import CoreGraphics
import Foundation
import TypingKit

/// Types keystrokes as if they came from the keyboard: events enter at the
/// HID level, so they pass through OpenUnikey's event tap like real typing.
struct KeyPoster: @unchecked Sendable { // only used from one thread at a time
    private static let shiftKey: CGKeyCode = 56
    private let source = CGEventSource(stateID: .hidSystemState)
    let delay: TimeInterval

    static var hasPermission: Bool { CGPreflightPostEventAccess() }
    static func requestPermission() { _ = CGRequestPostEventAccess() }

    /// Types `keys` ("\n" = Return, "\u{8}" = Backspace). Blocks the calling
    /// thread, so call it off the main thread.
    func type(_ keys: String) {
        for ch in keys {
            guard let key = KeyboardLayout.key(for: ch) else { continue }
            if key.shift { post(Self.shiftKey, down: true, flags: .maskShift) }
            let text = (ch == "\n" || ch == "\u{8}") ? nil : String(ch)
            let flags: CGEventFlags = key.shift ? .maskShift : []
            post(CGKeyCode(key.code), down: true, flags: flags, text: text)
            post(CGKeyCode(key.code), down: false, flags: flags, text: text)
            if key.shift { post(Self.shiftKey, down: false, flags: []) }
            Thread.sleep(forTimeInterval: delay)
        }
    }

    /// Presses and releases Control+Shift with nothing else, like a person
    /// switching OpenUnikey between V and E.
    func pressControlShift() {
        let control: CGKeyCode = 59
        let steps: [(CGKeyCode, CGEventFlags)] = [
            (control, .maskControl), (Self.shiftKey, [.maskControl, .maskShift]),
            (Self.shiftKey, .maskControl), (control, []),
        ]
        for (code, flags) in steps {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: true)
            else { continue }
            event.type = .flagsChanged
            event.flags = flags
            event.post(tap: .cghidEventTap)
            Thread.sleep(forTimeInterval: 0.03)
        }
    }

    private func post(_ code: CGKeyCode, down: Bool, flags: CGEventFlags, text: String? = nil) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
        else { return }
        event.flags = flags
        if let text {
            let units = Array(text.utf16)
            event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
        }
        event.post(tap: .cghidEventTap)
    }
}
