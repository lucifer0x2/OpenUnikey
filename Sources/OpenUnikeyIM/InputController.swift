import AppKit
import InputMethodKit
import OpenUnikeyShared
import VietCore

/// InputMethodKit makes one controller per client text field. The typing state
/// lives in the core and is shared, as only one field types at a time.
///
/// The keys arrive inside the focused app, after WindowServer has routed them,
/// so a key it delivers past every event tap (ViewBridge remote views) still
/// reaches the engine. Rewrites commit synchronously through IMKTextInput,
/// with no marked text or synthetic event round trips.
@objc(OpenUnikeyInputController)
final class InputController: IMKInputController {
    private var replacement = CommittedTextReplacement()
    private var currentClient: IMKTextInput?

    override func recognizedEvents(_ sender: Any!) -> Int {
        let mask: NSEvent.EventTypeMask = [.keyDown, .flagsChanged, .leftMouseDown]
        return Int(mask.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event else { return false }
        switch event.type {
        case .keyDown, .flagsChanged:
            let client = sender as? IMKTextInput
            ImSettings.refreshIfChanged(clientBundleID: client?.bundleIdentifier())
            guard let cgEvent = event.cgEvent else { return false }
            // The CGEvent rebuilt from the NSEvent has no text; the engine needs it.
            if event.type == .keyDown, let text = event.characters {
                let units = Array(text.utf16)
                cgEvent.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            }
            let selection = client?.selectedRange() ?? NSRange(location: NSNotFound, length: NSNotFound)
            if event.type == .keyDown, replacement.prepare(selection: selection) { vk_im_reset() }
            if event.type == .keyDown, event.keyCode == 51,
               event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
               replacement.preservesWordForBackspace(selection: selection) {
                replacement.expectNativeCaret(selection.location)
                return false
            }
            currentClient = client
            defer { currentClient = nil }
            let consumed = vk_im_handle_event_with_replacer(cgEvent, { backs, chars, count, context in
                guard let context, let chars, count >= 0 else { return false }
                let controller = Unmanaged<InputController>.fromOpaque(context).takeUnretainedValue()
                return controller.commit(backs: Int(backs), chars: chars, count: Int(count))
            }, Unmanaged.passUnretained(self).toOpaque())
            if !consumed, event.type == .keyDown {
                expectNativeEffect(event, selection: selection)
            }
            return consumed
        default: // a click in the text moves the caret
            vk_im_reset()
            replacement.reset()
            return false
        }
    }

    override func activateServer(_ sender: Any!) {
        let client = sender as? IMKTextInput
        ImSettings.apply(clientBundleID: client?.bundleIdentifier())
        vk_key_log_note("im client \(client?.bundleIdentifier() ?? "unknown")")
        vk_im_reset()
        replacement.reset()
    }

    override func deactivateServer(_ sender: Any!) {
        vk_im_reset()
        replacement.reset()
    }

    private func commit(backs: Int, chars: UnsafePointer<UInt16>, count: Int) -> Bool {
        guard let client = currentClient else { return false }
        let text = String(decoding: UnsafeBufferPointer(start: chars, count: count), as: UTF16.self)
        return replacement.replace(backs: backs, text: text, selection: client.selectedRange()) {
            client.insertText($0, replacementRange: $1)
        }
    }

    private func expectNativeEffect(_ event: NSEvent, selection: NSRange) {
        var caret: Int?
        let shortcuts: NSEvent.ModifierFlags = [.command, .control, .option]
        if selection.location != NSNotFound, selection.length != NSNotFound,
           event.modifierFlags.intersection(shortcuts).isEmpty {
            if event.keyCode == 51 {
                caret = selection.length > 0 ? selection.location : max(0, selection.location - 1)
            } else if let text = event.characters, text.utf16.count == 1,
                      let unit = text.utf16.first, unit >= 0x20, unit < 0x7F {
                caret = selection.location + 1
            }
        }
        replacement.expectNativeCaret(caret)
    }
}
