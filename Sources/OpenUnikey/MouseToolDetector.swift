import AppKit

/// Spots other mouse remapping tools that may also act on buttons 4/5.
@MainActor
enum MouseToolDetector {
    static var isOtherMouseToolRunning: Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            let name = app.localizedName ?? ""
            let id = app.bundleIdentifier ?? ""
            return name.hasPrefix("Mac Mouse Fix") || id.hasPrefix("com.nuebling.mac-mouse-fix")
        }
    }
}
