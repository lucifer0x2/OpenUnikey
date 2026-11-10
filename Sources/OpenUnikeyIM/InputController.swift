import AppKit
import InputMethodKit
import VietCore

/// InputMethodKit makes one controller per client text field. The typing state
/// lives in the core and is shared, as only one field types at a time.
///
/// The keys arrive inside the focused app, after WindowServer has routed them,
/// so a key it delivers past every event tap (ViewBridge remote views) still
/// reaches the engine. No marked text: the rewrite is Backspaces plus text,
/// posted as key events, exactly as with the tap.
@objc(OpenUnikeyInputController)
final class InputController: IMKInputController {
    override func recognizedEvents(_ sender: Any!) -> Int {
        let mask: NSEvent.EventTypeMask = [.keyDown, .flagsChanged, .leftMouseDown]
        return Int(mask.rawValue)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event else { return false }
        switch event.type {
        case .keyDown, .flagsChanged:
            guard let cgEvent = event.cgEvent else { return false }
            // The CGEvent rebuilt from the NSEvent has no text; the engine needs it.
            if event.type == .keyDown, let text = event.characters {
                let units = Array(text.utf16)
                cgEvent.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units)
            }
            return vk_im_handle_event(cgEvent)
        default: // a click in the text moves the caret
            vk_im_reset()
            return false
        }
    }

    override func activateServer(_ sender: Any!) {
        let client = sender as? IMKTextInput
        ImSettings.apply(clientBundleID: client?.bundleIdentifier())
        vk_key_log_note("im client \(client?.bundleIdentifier() ?? "unknown")")
        vk_im_reset()
    }

    override func deactivateServer(_ sender: Any!) {
        vk_im_reset()
    }
}
