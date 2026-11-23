import Foundation
import OpenUnikeyShared
import Testing

@Suite("Committed text replacement")
struct CommittedTextReplacementTests {
    @Test func replacesOnlyKnownUTF16RangeSynchronously() {
        var replacement = CommittedTextReplacement()
        var document = "😀a" as NSString
        var calls = 0
        let firstReset = replacement.prepare(selection: NSRange(location: 3, length: 0))
        #expect(!firstReset)
        #expect(replacement.replace(backs: 1, text: "á", selection: NSRange(location: 3, length: 0)) {
            document = document.replacingCharacters(in: $1, with: $0) as NSString
            calls += 1
        })
        #expect(document == "😀á")
        #expect(calls == 1)
        let secondReset = replacement.prepare(selection: NSRange(location: 3, length: 0))
        #expect(!secondReset)
    }

    @Test(arguments: [NSRange(location: NSNotFound, length: NSNotFound),
                      NSRange(location: 0, length: 0), NSRange(location: 4, length: 3)])
    func unsupportedOrUnownedRangeNeverCommits(selection: NSRange) {
        var replacement = CommittedTextReplacement()
        _ = replacement.prepare(selection: selection)
        #expect(!replacement.replace(backs: 1, text: "á", selection: selection) { _, _ in
            Issue.record("must not commit an unsupported or guessed range")
        })
    }

    @Test func caretMovementAndSelectionResetTheEngine() {
        var replacement = CommittedTextReplacement()
        replacement.expectNativeCaret(7)
        let moved = replacement.prepare(selection: NSRange(location: 2, length: 0))
        #expect(moved)
        replacement.expectNativeCaret(7)
        let selected = replacement.prepare(selection: NSRange(location: 2, length: 5))
        #expect(selected)
        replacement.reset()
        let unowned = replacement.prepare(selection: NSRange(location: 7, length: 2))
        #expect(unowned)
    }

    @Test func selectedInlineSuggestionIsReplacedWithOwnedPrefix() {
        var replacement = CommittedTextReplacement()
        var document = "apple.com" as NSString
        // Native A inserted at 0, client selected its inline suggestion.
        replacement.expectNativeCaret(1)
        let suggestion = NSRange(location: 1, length: 8)
        let needsReset = replacement.prepare(selection: suggestion)
        #expect(!needsReset)
        let replaced = replacement.replace(backs: 1, text: "á", selection: suggestion) {
            #expect($1 == NSRange(location: 0, length: 9))
            document = document.replacingCharacters(in: $1, with: $0) as NSString
        }
        #expect(replaced)
        #expect(document == "á")
        let nextReset = replacement.prepare(selection: NSRange(location: 1, length: 0))
        #expect(!nextReset)
    }

    @Test func selectionChangesDuringCallbackCannotExpandDeletion() {
        var replacement = CommittedTextReplacement()
        replacement.expectNativeCaret(1)
        let needsReset = replacement.prepare(selection: NSRange(location: 1, length: 8))
        #expect(!needsReset)
        #expect(!replacement.replace(backs: 1, text: "á", selection: NSRange(location: 1, length: 9)) {
            _, _ in Issue.record("changed selection is not the owned suggestion")
        })
    }

    @Test func caretMovesBetweenPrepareAndCommit() {
        var replacement = CommittedTextReplacement()
        _ = replacement.prepare(selection: NSRange(location: 3, length: 0))
        #expect(!replacement.replace(backs: 1, text: "á", selection: NSRange(location: 10, length: 0)) {
            _, _ in Issue.record("client moved after preflight")
        })
    }
}
