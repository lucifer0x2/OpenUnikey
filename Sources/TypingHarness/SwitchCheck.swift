import AppKit

/// Checks the V/E switch key end to end: Vietnamese, Control+Shift to English,
/// Control+Shift back, and OpenUnikey still running afterwards.
@MainActor
struct SwitchCheck {
    let surface: TypingSurface
    let window: NSWindow
    let poster: KeyPoster

    func run() async -> [String] {
        let steps: [(switchFirst: Bool, expected: String)] = [
            (false, "việt"), (true, "vieetj"), (true, "việt"),
        ]
        var report: [String] = []
        for (index, step) in steps.enumerated() {
            guard surface.isFrontmost(window) else { return report + ["ABORTED: target lost focus"] }
            surface.clear()
            surface.focus(in: window)
            if step.switchFirst {
                await Task.detached { [poster] in poster.pressControlShift() }.value
                try? await Task.sleep(for: .seconds(0.3))
            }
            await Task.detached { [poster] in poster.type("vieetj ") }.value
            try? await Task.sleep(for: .seconds(0.4))
            let typed = await surface.read().trimmingCharacters(in: .whitespaces)
            let verdict = typed == step.expected ? "PASS" : "FAIL"
            report.append("\(verdict) step \(index + 1): expected \(step.expected), got \(typed)")
        }
        let alive = !NSRunningApplication
            .runningApplications(withBundleIdentifier: "io.github.openunikey").isEmpty
        report.append(alive ? "PASS OpenUnikey still running" : "FAIL OpenUnikey is not running")
        return report
    }
}
