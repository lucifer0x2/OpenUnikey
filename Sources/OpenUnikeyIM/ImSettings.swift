import Foundation
import OpenUnikeyShared
import VietCore

/// Reads the settings the menu bar app keeps in its defaults domain and pushes
/// them into this process's core. Keys and fallbacks mirror Preferences.
enum ImSettings {
    private static let maxLogBytes: UInt64 = 20 << 20

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: InputMethodIdentity.appDefaultsDomain)
    }

    /// Selecting the input method means Vietnamese. The switch key selects
    /// the English layout (ABC); the menu bar app's switch key comes back.
    static func startAtLaunch() {
        startKeyLog()
        apply(clientBundleID: nil)
        vk_set_vietnamese(true)
        vk_set_switch_callback(switchKeyPressed, nil)
    }

    static func apply(clientBundleID: String?) {
        let d = defaults
        func flag(_ key: String, _ fallback: Bool) -> Bool {
            d?.object(forKey: key) as? Bool ?? fallback
        }
        var options = VKOptions(
            method: VKInputMethod(rawValue: UInt32(d?.integer(forKey: "inputMethod") ?? 0)),
            freeMarking: flag("freeMarking", true),
            modernStyle: flag("modernStyle", false),
            spellCheck: flag("spellCheck", true),
            autoRestore: flag("autoRestore", true),
            bracketShortcuts: flag("bracketShortcuts", false)
        )
        vk_set_options(&options)
        vk_set_switch_key(d?.integer(forKey: "switchKey") == 1 ? VK_SWITCH_OPTION_Z : VK_SWITCH_CONTROL_SHIFT)
        let browserFix = flag("browserFix", true)
        vk_set_autocomplete_fix(browserFix ? Browsers.autocompleteFix(for: clientBundleID) : VK_AUTOCOMPLETE_NONE)
    }

    /// Same switch as the app's key log, written to keys-im.log next to keys.log.
    private static func startKeyLog() {
        guard defaults?.bool(forKey: "keyLogging") == true else { return }
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
