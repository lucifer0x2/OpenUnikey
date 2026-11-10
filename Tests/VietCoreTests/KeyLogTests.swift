import Foundation
import Testing
import VietCore

/// The key log is one per process, so these run one at a time.
@Suite("Key log", .serialized)
struct KeyLogTests {
    private let url = FileManager.default.temporaryDirectory
        .appending(path: "openunikey-keys-\(UUID().uuidString).log")
    private var rolledURL: URL { URL(fileURLWithPath: url.path + ".1") }

    private func cleanUp() {
        vk_key_log_stop()
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.removeItem(at: rolledURL)
    }

    @Test func linesStayInMemoryUntilWritten() throws {
        defer { cleanUp() }
        vk_key_log_start(url.path, 1 << 20)
        vk_key_log_note("first\nsecond")
        #expect(!FileManager.default.fileExists(atPath: url.path))

        vk_key_log_flush()
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.hasSuffix(" note first\\x0asecond\n")) // one event, one line
        let mode = try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions]
        #expect(mode as? Int == 0o600)
    }

    @Test func stopWritesWhatIsLeftAndEndsTheLog() throws {
        defer { cleanUp() }
        vk_key_log_start(url.path, 1 << 20)
        vk_key_log_note("before stop")
        vk_key_log_stop()
        vk_key_log_note("after stop")
        vk_key_log_flush()
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("before stop") && !text.contains("after stop"))
    }

    @Test func aFullFileRollsOver() throws {
        defer { cleanUp() }
        vk_key_log_start(url.path, 64)
        vk_key_log_note(String(repeating: "a", count: 80))
        vk_key_log_flush()
        vk_key_log_note("next")
        vk_key_log_flush()
        #expect(try String(contentsOf: rolledURL, encoding: .utf8).contains("aaaa"))
        #expect(try String(contentsOf: url, encoding: .utf8).hasSuffix(" note next\n"))
    }
}
