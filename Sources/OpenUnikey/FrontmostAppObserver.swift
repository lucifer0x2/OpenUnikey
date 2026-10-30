import AppKit
import VietCore

/// Tracks the active app and which autocomplete workaround it needs.
@MainActor
final class FrontmostAppObserver {
    /// Chromium browsers: selecting one character dismisses the inline
    /// suggestion more reliably than typing a filler (as OpenKey does).
    static let chromiumBrowsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev",
        "com.brave.Browser", "company.thebrowser.Browser", "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi", "org.chromium.Chromium",
    ]
    /// Other browsers whose address bar selects a suggestion while typing.
    static let fillerBrowsers: Set<String> = [
        "com.apple.Safari", "com.apple.SafariTechnologyPreview", "org.mozilla.firefox",
    ]

    private var token: NSObjectProtocol?

    private(set) var currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

    var autocompleteFix: VKAutocompleteFix {
        guard let id = currentBundleID else { return VK_AUTOCOMPLETE_NONE }
        if Self.chromiumBrowsers.contains(id) { return VK_AUTOCOMPLETE_SELECT_LEFT }
        if Self.fillerBrowsers.contains(id) { return VK_AUTOCOMPLETE_FILLER }
        return VK_AUTOCOMPLETE_NONE
    }

    func start(onChange: @escaping @MainActor () -> Void) {
        token = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let bundleID = app?.bundleIdentifier
            MainActor.assumeIsolated {
                self?.currentBundleID = bundleID
                onChange()
            }
        }
    }
}
