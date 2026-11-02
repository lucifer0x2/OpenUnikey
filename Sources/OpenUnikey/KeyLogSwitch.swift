import Foundation
import VietCore

/// Diagnostic key log, for bugs only reproducible with a real keyboard. It
/// records keystrokes (Vietnamese mode only), so it is off unless turned on with
/// `defaults write io.github.openunikey keyLogging -bool true` before launch; it
/// then stays on until `defaults delete io.github.openunikey keyLogging` and a
/// relaunch. Lines are kept in memory and appended to
/// ~/Library/Logs/OpenUnikey/keys.log every 10 minutes and on Quit.
@MainActor
enum KeyLogSwitch {
    private static let key = "keyLogging"
    private static let maxBytes: UInt64 = 20 << 20 // then keys.log.1 takes over

    static func applyAtLaunch() {
        guard UserDefaults.standard.bool(forKey: key) else { return }
        let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let folder = library.appending(path: "Logs/OpenUnikey")
        do {
            try FileManager.default.createDirectory(
                at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        } catch {
            return
        }
        vk_key_log_start(folder.appending(path: "keys.log").path, maxBytes)
        vk_key_log_note("started")
    }

    static func noteActiveApp(_ bundleID: String?) {
        vk_key_log_note("app \(bundleID ?? "unknown")")
    }

    static func stop() {
        vk_key_log_stop()
    }
}
