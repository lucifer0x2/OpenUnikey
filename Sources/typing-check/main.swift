import Foundation
import TypingKit
import VietCore

// Headless check of the typing engine: types each line of the given texts as
// Telex/VNI keys through the engine and reports words that come out wrong.
//
//   swift run typing-check [options] file...
//     --method telex|vni   keys to generate (default telex)
//     --tone end|vowel     tone key at word end or right after the vowel
//     --compact-horn       type ươ as "uow"
//     --modern             oà, uý tone placement
//     --no-spell           disable spell checking
//     --no-restore         disable restoring non-Vietnamese words
//     --interrupt N        every Nth word: type a space mid-word, delete it, go on
//     --show N             mismatches to list (default 30)

var encoder = KeystrokeEncoder()
var options = VKOptions.standard
var show = 30
var files: [String] = []

var args = CommandLine.arguments.dropFirst().makeIterator()
while let arg = args.next() {
    switch arg {
    case "--method":
        encoder.method = KeystrokeEncoder.Method(rawValue: args.next() ?? "") ?? .telex
    case "--tone":
        encoder.toneStyle = args.next() == "vowel" ? .afterVowel : .endOfWord
    case "--compact-horn": encoder.compactHorn = true
    case "--interrupt": encoder.interruptEvery = Int(args.next() ?? "") ?? 0
    case "--modern": options.modernStyle = true
    case "--no-spell": options.spellCheck = false
    case "--no-restore": options.autoRestore = false
    case "--show": show = Int(args.next() ?? "") ?? show
    default: files.append(arg)
    }
}
options.method = encoder.method == .vni ? VK_VNI : VK_TELEX

guard !files.isEmpty else {
    FileHandle.standardError.write("usage: typing-check [options] file...\n".data(using: .utf8)!)
    exit(2)
}

let typist = EngineTypist(options)
var total = TypingCheck()
for file in files {
    guard let raw = try? String(contentsOfFile: file, encoding: .utf8) else {
        print("cannot read \(file)")
        continue
    }
    var check = TypingCheck()
    for line in CorpusText.lines(from: raw) {
        let keys = encoder.keys(for: line)
        typist.clear()
        check.record(expected: line, actual: typist.type(keys), keys: keys)
    }
    let name = URL(fileURLWithPath: file).lastPathComponent
    print(String(format: "%@: %d words, %d wrong, %.3f%% correct",
                 name, check.words, check.mismatches.count, check.accuracy * 100))
    total.merge(check)
}

print(String(format: "TOTAL: %d lines, %d words, %d wrong, %.3f%% correct",
             total.lines, total.words, total.mismatches.count, total.accuracy * 100))

// Most frequent mistakes first.
var groups: [String: (count: Int, sample: TypingCheck.Mismatch)] = [:]
for m in total.mismatches {
    let key = "\(m.expected) -> \(m.actual)"
    groups[key] = ((groups[key]?.count ?? 0) + 1, m)
}
for (key, value) in groups.sorted(by: { $0.value.count > $1.value.count }).prefix(show) {
    print("  \(value.count)x  \(key)   keys: \(value.sample.keys)")
}
exit(total.mismatches.isEmpty ? 0 : 1)
