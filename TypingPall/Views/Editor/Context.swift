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

        defer {
            // Map visible markers back to original characters
            let rawText = textView.string
                .replacingOccurrences(of: "·", with: " ") // Convert middle dots back to spaces
                .replacingOccurrences(of: "→", with: "\t") // Convert arrows back to tabs

            parent.text = rawText
        }

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

        // Convert displayed text back to raw for comparison
        let rawTypedText = textView.string
            .replacingOccurrences(of: "·", with: " ")
            .replacingOccurrences(of: "→", with: "\t")

        let rawPlaceholder = placeholderTextView.string
            .replacingOccurrences(of: "·", with: " ")
            .replacingOccurrences(of: "→", with: "\t")

        let numberOfTypedCharacters = textView.string.count
        let numberOfRemainingCharacters = placeholderTextView.string.count - numberOfTypedCharacters

        if numberOfRemainingCharacters >= 0 {
            // Hide the placeholder behind the typed characters
            placeholderTextView.setTextColor(.clear, range: NSMakeRange(0, numberOfTypedCharacters))
            placeholderTextView.setTextColor(.placeholderTextColor, range: NSMakeRange(numberOfTypedCharacters, numberOfRemainingCharacters))
        }

        // Compare raw strings to find mismatches
        guard let mismatchedRange = rawTypedText.extractMismatchedRange(comparedTo: rawPlaceholder) else {
            textView.setTextColor(.systemGreen, range: NSMakeRange(0, numberOfTypedCharacters))
            return
        }

        if mismatchedRange.location > 0 {
            textView.setTextColor(.systemGreen, range: NSMakeRange(0, mismatchedRange.location))
        }

        textView.setTextColor(.red, range: mismatchedRange)
    }
}
