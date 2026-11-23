import Foundation
import OpenUnikeyShared
import VietCore

/// Reads the settings the menu bar app keeps in its defaults domain and pushes
/// them into this process's core. Called only on InputMethodKit's main thread.
@MainActor
enum ImSettings {
    private static let maxLogBytes: UInt64 = 20 << 20

    private static let defaults = UserDefaults(suiteName: InputMethodIdentity.appDefaultsDomain)!
    private static var settings: TypingSettings?
    private static var cache = TypingSettingsCache()
    private static var needsReload = true
    private static var observer: NSObjectProtocol?

    /// Selecting the input method means Vietnamese. The switch key selects
    /// the English layout (ABC); the menu bar app's switch key comes back.
    static func startAtLaunch() {
        observer = DistributedNotificationCenter.default().addObserver(
            forName: TypingSettings.changedNotification, object: nil, queue: .main
        ) { _ in MainActor.assumeIsolated { needsReload = true } }
        startKeyLog()
        apply(clientBundleID: nil)
        vk_set_vietnamese(true)
        vk_set_switch_callback(switchKeyPressed, nil)
    }

    nonisolated static func apply(clientBundleID: String?) {
        MainActor.assumeIsolated {
            needsReload = true // Activation also catches edits made with the defaults CLI.
            refreshOnMainThread(clientBundleID: clientBundleID)
        }
    }

    /// Before each key, pick up a published change even if this client stays active.
    /// No defaults I/O or engine reset on the ordinary unchanged-key path.
    nonisolated static func refreshIfChanged(clientBundleID: String?) {
        MainActor.assumeIsolated { refreshOnMainThread(clientBundleID: clientBundleID) }
    }

    private static func refreshOnMainThread(clientBundleID: String?) {
        if needsReload {
            defaults.synchronize()
            settings = TypingSettings(defaults: defaults)
            needsReload = false
        }
        guard let settings else { return }
        let changes = cache.update(settings, clientBundleID: clientBundleID)
        if let engine = changes.engine {
            var options = engine.coreOptions
            vk_set_options(&options)
        }
        if let key = changes.switchKey { vk_set_switch_key(key.core) }
        if let fix = changes.autocomplete { vk_set_autocomplete_fix(fix) }
    }

    /// Same switch as the app's key log, written to keys-im.log next to keys.log.
    private static func startKeyLog() {
        guard defaults.bool(forKey: "keyLogging") else { return }
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let folder = library.appending(path: "Logs/OpenUnikey")
        try? FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        vk_key_log_start(folder.appending(path: "keys-im.log").path, maxLogBytes)
        vk_key_log_note("input method started")
    }
}

/// The core's C switch callback; InputMethodKit calls in on the main thread.
private func switchKeyPressed(_ context: UnsafeMutableRawPointer?) {
    DispatchQueue.main.async { InputSources.selectEnglish() }
}
