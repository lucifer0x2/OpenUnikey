// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OpenUnikey",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "OpenUnikey", targets: ["OpenUnikey"]),
    ],
    targets: [
        // Typing engine (ported from UniKey 3.6) and the system-wide event tap.
        .target(
            name: "VietCore",
            publicHeadersPath: "include",
            cxxSettings: [.headerSearchPath(".")],
            linkerSettings: [.linkedFramework("ApplicationServices")]
        ),
        // Shared by the menu bar app and the input method: settings, input sources.
        .target(
            name: "OpenUnikeyShared",
            dependencies: ["VietCore"],
            linkerSettings: [.linkedFramework("Carbon")]
        ),
        // Menu bar app: V/E status item, menu, preferences, permissions,
        // and the switch key while another input source is selected.
        .executableTarget(
            name: "OpenUnikey",
            dependencies: ["VietCore", "OpenUnikeyShared"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        // Input method (InputMethodKit): gets keys inside the focused app, so
        // keys WindowServer routes past the event taps still get typed.
        .executableTarget(
            name: "OpenUnikeyIM",
            dependencies: ["VietCore", "OpenUnikeyShared"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("Carbon"),
                .linkedFramework("InputMethodKit"),
            ]
        ),
        // Shared by tests and tools: keystroke generation and typing checks.
        .target(name: "TypingKit", dependencies: ["VietCore"]),
        // Headless engine check over long texts: swift run typing-check file...
        .executableTarget(name: "typing-check", dependencies: ["TypingKit", "VietCore"]),
        // End-to-end check through the real event tap (see scripts/run-harness.sh).
        .executableTarget(
            name: "TypingHarness",
            dependencies: ["TypingKit"],
            linkerSettings: [.linkedFramework("AppKit"), .linkedFramework("WebKit")]
        ),
        .testTarget(name: "VietCoreTests", dependencies: ["VietCore", "TypingKit"]),
    ],
    cxxLanguageStandard: .cxx17
)
