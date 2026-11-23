import Foundation

/// Guards document-relative committed replacements; never guesses a range for
/// clients without document access. All positions/counts are UTF-16 units.
public struct CommittedTextReplacement {
    private var expectedCaret: Int?
    private var selectedSuffix: NSRange?
    private var preparedSelection: NSRange?

    public init() {}

    public mutating func reset() {
        expectedCaret = nil
        selectedSuffix = nil
        preparedSelection = nil
    }

    /// Call before processing each physical key. A moved caret or selection
    /// invalidates the engine's remembered word, even without a mouse event.
    public mutating func prepare(selection: NSRange) -> Bool {
        preparedSelection = selection
        // Address bars select their suggested suffix at the caret we own.
        // Include that selection in a rewrite, as the next native key would.
        selectedSuffix = selection.length > 0 && selection.length != NSNotFound
            && expectedCaret == selection.location ? selection : nil
        let invalid = selection.location == NSNotFound
            || (selection.length != 0 && selectedSuffix == nil)
            || expectedCaret.map { $0 != selection.location } == true
        expectedCaret = nil
        return invalid
    }

    /// The commit closure must synchronously send insertText:replacementRange:.
    /// A false result guarantees the closure was not invoked.
    public mutating func replace(backs: Int, text: String, selection: NSRange,
                                 commit: (String, NSRange) -> Void) -> Bool {
        guard backs >= 0, selection.location != NSNotFound,
              selection == preparedSelection,
              selection.length != NSNotFound, selection.location >= backs,
              selection.length <= Int.max - backs,
              selection.location <= Int.max - selection.length,
              backs == 0 || selection.length == 0 || selection == selectedSuffix else { return false }
        let range = NSRange(location: selection.location - backs,
                            length: backs + selection.length)
        guard range.location <= Int.max - text.utf16.count else { return false }
        commit(text, range)
        expectedCaret = range.location + text.utf16.count
        return true
    }

    /// Predict only plain ASCII insertion/deletion, whose native effect is
    /// known. Navigation, shortcuts, Return and Tab clear this expectation.
    public mutating func expectNativeCaret(_ caret: Int?) { expectedCaret = caret }

    /// Deleting an owned inline suggestion changes no typed prefix. Keep the
    /// engine's word intact; native Backspace removes only the selection.
    public func preservesWordForBackspace(selection: NSRange) -> Bool {
        selection.length > 0 && selection == selectedSuffix
    }
}
