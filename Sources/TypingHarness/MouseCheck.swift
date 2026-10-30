import AppKit

/// Checks the beta mouse feature end to end: button 5 must move to the Space
/// on the right (the harness window leaves the screen), button 4 must come
/// back. Tries the other direction first when there is no Space on the right.
@MainActor
struct MouseCheck {
    private static let left: Int64 = 3  // "button 4"
    private static let right: Int64 = 4 // "button 5"

    let window: NSWindow
    let poster: KeyPoster

    func run() async -> [String] {
        guard window.isOnActiveSpace else { return ["FAIL harness window not on the current Space"] }
        var report: [String] = []
        for (away, back) in [(Self.right, Self.left), (Self.left, Self.right)] {
            await click(away)
            guard !window.isOnActiveSpace else {
                report.append("no Space reached with button \(away + 1), trying the other side")
                continue
            }
            report.append("PASS button \(away + 1) switched Space")
            await click(back)
            report.append(window.isOnActiveSpace
                ? "PASS button \(back + 1) switched back"
                : "FAIL button \(back + 1) did not come back")
            return report
        }
        report.append("FAIL neither button switched Space (is the beta option on? 2+ Spaces?)")
        return report
    }

    private func click(_ button: Int64) async {
        await Task.detached { [poster] in poster.clickMouseButton(button) }.value
        try? await Task.sleep(for: .seconds(1.2)) // the Space animation
    }
}
