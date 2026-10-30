import AppKit
import VietCore

/// Tracks the active app and which autocomplete workaround it needs.
@MainActor
final class FrontmostAppObserver {
    /// Browsers whose address bar selects an inline suggestion while typing.
    /// They all get the filler character, OpenKey's default workaround (its
    /// Shift+Left variant for Chromium is an opt-in there); one path for all.
    static let browsers: Set<String> = [
        "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.canary",
        "com.microsoft.edgemac", "com.microsoft.edgemac.Beta", "com.microsoft.edgemac.Dev",
        "com.brave.Browser", "company.thebrowser.Browser", "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi", "org.chromium.Chromium",
        "com.apple.Safari", "com.apple.SafariTechnologyPreview", "org.mozilla.firefox",
    ]

    private var token: NSObjectProtocol?

    private(set) var currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

    var autocompleteFix: VKAutocompleteFix {
        guard let id = currentBundleID, Self.browsers.contains(id) else {
            return VK_AUTOCOMPLETE_NONE
        }
        return VK_AUTOCOMPLETE_FILLER
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
