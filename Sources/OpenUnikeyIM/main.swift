import AppKit
import InputMethodKit
import VietCore

// `OpenUnikeyIM --install` registers and enables the bundle it runs from
// (scripts/build-input-method.sh calls it after copying the bundle).
if CommandLine.arguments.contains("--install") {
    exit(InputSourceInstaller.install(bundleURL: Bundle.main.bundleURL) ? 0 : 1)
}

let connectionName = Bundle.main.object(forInfoDictionaryKey: "InputMethodConnectionName") as? String
guard let connectionName,
      let server = IMKServer(name: connectionName, bundleIdentifier: Bundle.main.bundleIdentifier)
else {
    fatalError("OpenUnikeyIM: cannot start the input method server")
}

ImSettings.startAtLaunch()
// The rewrite is posted as key events, which needs the Accessibility permission.
if !CGPreflightPostEventAccess() { _ = CGRequestPostEventAccess() }
// Clicks move the caret; a passive global monitor needs no permission.
let clickMonitor = NSEvent.addGlobalMonitorForEvents(
    matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
) { _ in vk_im_reset() }

withExtendedLifetime((server, clickMonitor)) {
    NSApplication.shared.run()
}
