import AppKit
import TypingKit

struct HarnessConfig {
    var corpus: [String] = []
    var limit = 15
    var delay: TimeInterval = 0.008
    var settle: TimeInterval = 0.4
    var web = false
    var switchCheck = false
    var mouseCheck = false
    var encoder = KeystrokeEncoder()
    var out = FileManager.default.temporaryDirectory.appendingPathComponent("typing-harness.txt").path
}

/// Stops typing as soon as the harness loses focus, so keys never land in
/// another app.
final class FocusGuard: @unchecked Sendable {
    private let lock = NSLock()
    private var lost = false
    var isLost: Bool { lock.withLock { lost } }
    func markLost() { lock.withLock { lost = true } }
}

/// Types each corpus line into its own window through the real keyboard
/// event path, then compares what appeared with the original text.
@MainActor
final class HarnessRunner {
    private let config: HarnessConfig
    private let surface: TypingSurface
    private let window: NSWindow
    private let focus = FocusGuard()
    private var report: [String] = []

    init(config: HarnessConfig) {
        self.config = config
        surface = config.web ? WebSurface() : NativeSurface()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 600),
                          styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.title = "OpenUnikey typing harness - do not touch the keyboard"
        window.contentView = surface.view
        window.center()
    }

    func run() async {
        guard KeyPoster.hasPermission else {
            KeyPoster.requestPermission()
            finish("NO PERMISSION: allow TypingHarness in Privacy & Security > Accessibility, then run again.")
            return
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: nil
        ) { [focus] _ in focus.markLost() }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        try? await Task.sleep(for: .seconds(1.5)) // window, web page and focus settle
        // Key events go to whatever app is in front: never type unless it is us.
        guard NSApp.isActive, window.isKeyWindow else {
            let front = NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
            return finish("ABORTED: harness is not the active app (front: \(front)); nothing typed.")
        }

        let poster = KeyPoster(delay: config.delay)
        if config.mouseCheck { // switching Spaces takes focus away, so no focus guard
            report = await MouseCheck(window: window, poster: poster).run()
            return finish("DONE")
        }
        if config.switchCheck {
            report = await SwitchCheck(surface: surface, window: window, poster: poster).run()
            return finish(focus.isLost ? "ABORTED: harness lost focus." : "DONE")
        }
        var total = TypingCheck()
        for file in config.corpus {
            let raw = (try? String(contentsOfFile: file, encoding: .utf8)) ?? ""
            var check = TypingCheck()
            for line in CorpusText.lines(from: raw).prefix(config.limit) {
                guard !focus.isLost, NSApp.isActive else { return finish("ABORTED: harness lost focus.") }
                surface.clear()
                surface.focus(in: window)
                let keys = config.encoder.keys(for: line) + " " // the space ends the last word
                await Task.detached { [focus] in
                    for chunk in keys.chunked(into: 32) where !focus.isLost { poster.type(chunk) }
                }.value
                try? await Task.sleep(for: .seconds(config.settle))
                let typed = await surface.read().trimmingCharacters(in: .whitespacesAndNewlines)
                check.record(expected: line, actual: typed, keys: keys)
            }
            report.append(summary(URL(fileURLWithPath: file).lastPathComponent, check))
            total.merge(check)
        }
        report.append(summary("TOTAL", total))
        for m in total.mismatches.prefix(80) {
            report.append("  line \(m.line): \(m.expected) -> \(m.actual)   keys: \(m.keys)")
        }
        finish(focus.isLost ? "ABORTED: harness lost focus." : "DONE")
    }

    private func summary(_ name: String, _ check: TypingCheck) -> String {
        String(format: "%@: %d lines, %d words, %d wrong, %.3f%% correct",
               name, check.lines, check.words, check.mismatches.count, check.accuracy * 100)
    }

    private func finish(_ status: String) {
        let surfaceName = config.web ? "web" : "native"
        let header = "surface=\(surfaceName) method=\(config.encoder.method.rawValue) "
            + "tone=\(config.encoder.toneStyle.rawValue) delay=\(Int(config.delay * 1000))ms"
        let text = ([status, header] + report).joined(separator: "\n") + "\n"
        try? text.write(toFile: config.out, atomically: true, encoding: .utf8)
        NSApp.terminate(nil)
    }
}

private extension String {
    func chunked(into size: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for ch in self {
            current.append(ch)
            if current.count == size {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
