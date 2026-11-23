import Carbon
import Foundation
import OpenUnikeyShared

/// Registers the input method bundle with the Text Input Sources system,
/// enables it and selects it, so it types right away without logging out.
/// Reinstalling stops the running input method, which drops macOS back to ABC.
enum InputSourceInstaller {
    static func install(bundleURL: URL) -> Bool {
        let status = TISRegisterInputSource(bundleURL as CFURL)
        guard status == noErr else {
            print("TISRegisterInputSource failed: \(status)")
            return false
        }
        let filter = [kTISPropertyBundleID as String: Bundle.main.bundleIdentifier ?? ""] as CFDictionary
        let sources = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource] ?? []
        guard !sources.isEmpty else {
            print("Registered, but no input source found for \(Bundle.main.bundleIdentifier ?? "?")")
            return false
        }
        for source in sources { TISEnableInputSource(source) }
        print("Registered and enabled \(sources.count) input source(s).")
        guard InputSources.selectVietnamese() else {
            print("Enabled, but could not select \(InputMethodIdentity.sourceID)")
            return false
        }
        print("Selected \(InputMethodIdentity.sourceID).")
        return true
    }
}
