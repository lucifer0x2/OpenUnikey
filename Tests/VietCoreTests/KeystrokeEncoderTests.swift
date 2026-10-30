import Testing
import TypingKit

@Suite("Keystroke encoder")
struct KeystrokeEncoderTests {
    @Test(arguments: [
        ("người", "nguwowif"), ("Đường", "Dduwowngf"), ("VIỆT", "VIEETJ"),
        ("Việt Nam, 2024!", "Vieetj Nam, 2024!"), ("hoà", "hoaf"), ("Windows", "Windows"),
    ])
    func telex(text: String, keys: String) {
        #expect(KeystrokeEncoder().keys(for: text) == keys)
    }

    @Test func styles() {
        #expect(KeystrokeEncoder(toneStyle: .afterVowel).keys(for: "người") == "nguwowfi")
        #expect(KeystrokeEncoder(compactHorn: true).keys(for: "được") == "dduowcj")
        #expect(KeystrokeEncoder(method: .vni).keys(for: "được") == "d9u7o7c5")
    }

    @Test func corpusCleanup() {
        #expect(CorpusText.lines(from: "“Xin chào” – thế giới…\n\n  ok  ") == ["\"Xin chào\" - thế giới...", "ok"])
        #expect(CorpusText.toneInsensitive("hòa") == CorpusText.toneInsensitive("hoà"))
    }
}
