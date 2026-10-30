import AppKit
import WebKit

/// A text field the harness types into and reads back.
@MainActor
protocol TypingSurface {
    var view: NSView { get }
    func focus(in window: NSWindow)
    func clear()
    func read() async -> String
}

/// Plain AppKit text view with every automatic substitution turned off, so
/// only OpenUnikey changes what is typed.
@MainActor
final class NativeSurface: TypingSurface {
    private let scroll = NSTextView.scrollableTextView()
    private var textView: NSTextView { scroll.documentView as! NSTextView }

    var view: NSView { scroll }

    init() {
        let text = textView
        text.isRichText = false
        text.font = .systemFont(ofSize: 15)
        text.isAutomaticQuoteSubstitutionEnabled = false
        text.isAutomaticDashSubstitutionEnabled = false
        text.isAutomaticTextReplacementEnabled = false
        text.isAutomaticSpellingCorrectionEnabled = false
        text.isContinuousSpellCheckingEnabled = false
        text.isGrammarCheckingEnabled = false
        text.isAutomaticTextCompletionEnabled = false
        text.isAutomaticLinkDetectionEnabled = false
        text.isAutomaticDataDetectionEnabled = false
        text.smartInsertDeleteEnabled = false
    }

    func focus(in window: NSWindow) { window.makeFirstResponder(textView) }
    func clear() { textView.string = "" }
    func read() async -> String { textView.string }
}

/// A <textarea> in WebKit, to check web content as well.
@MainActor
final class WebSurface: TypingSurface {
    private let webView = WKWebView()
    var view: NSView { webView }

    init() {
        webView.loadHTMLString("""
            <textarea id="t" style="width:100%;height:95vh;font-size:15px"
              spellcheck="false" autocomplete="off" autocorrect="off"></textarea>
            """, baseURL: nil)
    }

    func focus(in window: NSWindow) {
        window.makeFirstResponder(webView)
        webView.evaluateJavaScript("document.getElementById('t').focus()")
    }

    func clear() {
        webView.evaluateJavaScript("document.getElementById('t').value = ''")
    }

    func read() async -> String {
        let value = try? await webView.evaluateJavaScript("document.getElementById('t').value")
        return value as? String ?? ""
    }
}
