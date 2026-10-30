import Foundation
import VietCore

/// Diagnostic key log, for bugs only reproducible with a real keyboard. Turned
/// on with `defaults write io.github.openunikey keyLogging -bool true` before
/// launch; it records keystrokes, so it switches itself off after 10 minutes.
/// Read it with:
///   /usr/bin/log show --last 10m --predicate 'subsystem == "io.github.openunikey" && category == "keys"'
@MainActor
enum KeyLogSwitch {
    private static let key = "keyLogging"
    private static let duration: TimeInterval = 10 * 60

    static func applyAtLaunch() {
        guard UserDefaults.standard.bool(forKey: key) else { return }
        vk_set_key_logging(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            vk_set_key_logging(false)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
