import AppKit

final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: TypingEditor

    init(_ parent: TypingEditor) {
        self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView, textView === parent.typingTextView else { return }

        defer { parent.text = textView.string }

        if let scrollView = textView.superview?.superview as? NSScrollView,
           let cursorPosition = cursorPosition(in: textView),
           !scrollView.visibleRect.contains(cursorPosition) {
            scrollView.scroll(cursorPosition)
        }
    }

    private func cursorPosition(in textView: NSTextView) -> NSPoint? {
        guard let textContainer = textView.textContainer,
              let layoutManager = textView.layoutManager else { return nil }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: textView.selectedRange(), actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        rect.origin.x += textContainer.lineFragmentPadding
        rect.origin.y += textView.textContainerInset.height

        return rect.origin
    }
}
