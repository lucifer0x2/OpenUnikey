import AppKit
import OpenUnikeyShared
import VietCore

/// Tracks the active app and which autocomplete workaround it needs.
@MainActor
final class FrontmostAppObserver {
    private var token: NSObjectProtocol?

    private(set) var currentBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier

    var autocompleteFix: VKAutocompleteFix { Browsers.autocompleteFix(for: currentBundleID) }

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
