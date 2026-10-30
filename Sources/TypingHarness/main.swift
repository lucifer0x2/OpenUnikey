import AppKit
import TypingKit

// End-to-end typing check: types corpus lines with real key events (through
// OpenUnikey's event tap) into its own window and writes a report.
//
//   open -W -n build/TypingHarness.app --args [options] --corpus FILE...
//     --limit N          lines per file (default 15)
//     --delay MS         pause between keys (default 8)
//     --hold MS          how long each key stays down (default 0)
//     --hid              post keys through the HID system like a keyboard
//     --web              type into a WebKit <textarea> instead of AppKit
//     --method telex|vni --tone end|vowel --compact-horn
//     --interrupt N      every Nth word: type a space mid-word, delete it, go on
//     --switch-check     only test the Control+Shift V/E switch (no corpus needed)
//     --mouse-check      only test mouse buttons 4/5 switching Spaces (beta feature
//                        must be on; needs a Space on at least one side)
//     --external PID     type into another app's focused field instead (e.g. a
//                        Chromium page that mirrors its field into the window
//                        title, see scripts/chromium-test-page.sh)
//     --out PATH         report file (default $TMPDIR/typing-harness.txt)
//
// OpenUnikey must be running in V mode with the same input method.

var config = HarnessConfig()
var args = CommandLine.arguments.dropFirst().makeIterator()
var readingCorpus = false
while let arg = args.next() {
    switch arg {
    case "--corpus": readingCorpus = true; continue
    case "--limit": config.limit = Int(args.next() ?? "") ?? config.limit
    case "--delay": config.delay = (Double(args.next() ?? "") ?? 8) / 1000
    case "--hold": config.hold = (Double(args.next() ?? "") ?? 0) / 1000
    case "--hid": config.hid = true
    case "--web": config.web = true
    case "--switch-check": config.switchCheck = true
    case "--mouse-check": config.mouseCheck = true
    case "--external": config.externalPID = pid_t(args.next() ?? "")
    case "--method": config.encoder.method = .init(rawValue: args.next() ?? "") ?? .telex
    case "--tone": config.encoder.toneStyle = args.next() == "vowel" ? .afterVowel : .endOfWord
    case "--compact-horn": config.encoder.compactHorn = true
    case "--interrupt": config.encoder.interruptEvery = Int(args.next() ?? "") ?? 0
    case "--out": config.out = args.next() ?? config.out
    default:
        if readingCorpus { config.corpus.append(arg); continue }
    }
    readingCorpus = false
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)
let runner = HarnessRunner(config: config)
Task { @MainActor in await runner.run() }
app.run()
