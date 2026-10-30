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
        // Menu bar app: V/E status item, menu, preferences, permissions.
        .executableTarget(
            name: "OpenUnikey",
            dependencies: ["VietCore"],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ServiceManagement"),
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
