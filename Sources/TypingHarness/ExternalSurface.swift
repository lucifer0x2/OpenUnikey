import AppKit
import ApplicationServices

/// A text field in another process: a Chromium page that copies its field into
/// the window title ("OU:" + value), or any app's focused text field (e.g. an
/// Electron chat box). Both are read through Accessibility.
@MainActor
final class ExternalSurface: TypingSurface {
    private static let titlePrefix = "OU:"
    private let pid: pid_t
    private let poster = KeyPoster(delay: 0.01)
    private var observer: NSObjectProtocol?

    let view = NSView()

    init(pid: pid_t) {
        self.pid = pid
        // Electron builds its accessibility tree only when asked to.
        AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid),
                                     "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }

    /// A freshly activated Chrome window drops the first key or two (seen with
    /// OpenUnikey stopped too), so type and clear a throwaway word first.
    func bringToFront(_ window: NSWindow) async {
        NSRunningApplication(processIdentifier: pid)?.activate()
        try? await Task.sleep(for: .seconds(1.5))
        guard isFrontmost(window) else { return }
        poster.type("warmup")
        try? await Task.sleep(for: .seconds(0.3))
        clear()
        try? await Task.sleep(for: .seconds(0.3))
    }

    func isFrontmost(_ window: NSWindow) -> Bool {
        NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
    }

    func watchFocusLoss(_ guard: FocusGuard) {
        let target = pid
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: nil
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.processIdentifier != target { `guard`.markLost() }
        }
    }

    func focus(in window: NSWindow) {} // the page keeps its field focused

    /// Command+A then Backspace, typed into the target like a person would.
    func clear() {
        poster.press(0, flags: .maskCommand) // A
        poster.press(51, flags: [])          // Backspace
    }

    func read() async -> String {
        let app = AXUIElementCreateApplication(pid)
        if let window = attribute(app, kAXFocusedWindowAttribute),
           let title = attribute(window as! AXUIElement, kAXTitleAttribute) as? String,
           title.hasPrefix(Self.titlePrefix) {
            return String(title.dropFirst(Self.titlePrefix.count))
        }
        guard let field = attribute(app, kAXFocusedUIElementAttribute) else { return "" }
        return attribute(field as! AXUIElement, kAXValueAttribute) as? String ?? ""
    }

    private func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success
        else { return nil }
        return value
    }
}
