/// Compares what was typed with what was meant, word by word.
public struct TypingCheck: Sendable {
    public struct Mismatch: Sendable {
        public let expected: String
        public let actual: String
        public let keys: String
        public let line: Int
    }

    public private(set) var words = 0
    public private(set) var lines = 0
    public private(set) var mismatches: [Mismatch] = []

    public init() {}

    public var accuracy: Double {
        words == 0 ? 1 : Double(words - mismatches.count) / Double(words)
    }

    /// Records one line. Words are compared ignoring tone placement (hòa = hoà).
    public mutating func record(expected: String, actual: String, keys: String) {
        lines += 1
        let want = expected.split(separator: " ")
        let got = actual.split(separator: " ")
        // An interrupted word types " ⌫" inside its keys; keep it as one word.
        let keyWords = keys.replacingOccurrences(of: " \u{8}", with: "⌫").split(separator: " ")
        words += want.count
        guard want.count == got.count else {
            // Words merged or split: report the whole line once per word.
            for word in want {
                mismatches.append(Mismatch(expected: String(word), actual: actual,
                                           keys: keys, line: lines))
            }
            return
        }
        for (index, word) in want.enumerated()
        where CorpusText.toneInsensitive(word) != CorpusText.toneInsensitive(got[index]) {
            let key = index < keyWords.count ? String(keyWords[index]) : ""
            mismatches.append(Mismatch(expected: String(word), actual: String(got[index]),
                                       keys: key, line: lines))
        }
    }

    public mutating func merge(_ other: TypingCheck) {
        let offset = lines
        words += other.words
        lines += other.lines
        mismatches += other.mismatches.map {
            Mismatch(expected: $0.expected, actual: $0.actual, keys: $0.keys, line: $0.line + offset)
        }
    }
}
