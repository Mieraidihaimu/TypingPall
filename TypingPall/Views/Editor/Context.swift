import AppKit

final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: TypingEditor

    private var textView: NSTextView { parent.typingTextView }
    private var placeholderTextView: NSTextView { parent.placeholderTextView }

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

        changeTextColorIfNeeded()
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        if replacementString == "\t" {
            textView.insertText(Array(repeating: " ", count: Int(parent.spaces)).joined(), replacementRange: affectedCharRange)
            return false
        }

        return true
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

    func changeTextColorIfNeeded() {
        guard !textView.string.isEmpty else {
            placeholderTextView.textColor = .placeholderTextColor
            return
        }

        let numberOfTypedCharacters = textView.string.count
        let numberOfRemainingCharacters = placeholderTextView.string.count - numberOfTypedCharacters

        if numberOfRemainingCharacters >= 0 {
            // Hide the placeholder behind the typed characters
            placeholderTextView.setTextColor(.clear, range: NSMakeRange(0, numberOfTypedCharacters))
            placeholderTextView.setTextColor(.placeholderTextColor, range: NSMakeRange(numberOfTypedCharacters, numberOfRemainingCharacters))
        }

        guard let mismatchedRange = textView.string.extractMismatchedRange(comparedTo: placeholderTextView.string) else {
            textView.setTextColor(.systemGreen, range: NSMakeRange(0, numberOfTypedCharacters))
            return
        }

        if mismatchedRange.location > 1 {
            textView.setTextColor(.systemGreen, range: NSMakeRange(0,  mismatchedRange.location - 1))
        }

        textView.setTextColor(.red, range: mismatchedRange)
    }
}
