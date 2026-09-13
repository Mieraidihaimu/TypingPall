import AppKit
import SwiftUI

/// Modern typing editor using a single TextView with AttributedString
/// This is the recommended architecture for better performance and maintainability
struct ModernTypingEditor: NSViewRepresentable {
    @Binding var typedText: String
    @Binding var targetText: String
    var fontSize: CGFloat

    @AppStorage("tabEqualsToSpaces") var spaces: Double = 4

    func makeCoordinator() -> ModernCoordinator {
        ModernCoordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView

        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.backgroundColor = NSColor.textBackgroundColor

        // Disable smart quotes and dashes for code typing
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        // Update font size if changed
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        // Update attributed text
        context.coordinator.updateAttributedText(in: textView)
    }
}

class ModernCoordinator: NSObject, NSTextViewDelegate {
    var parent: ModernTypingEditor

    init(_ parent: ModernTypingEditor) {
        self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }

        // Update parent's typed text
        parent.typedText = textView.string

        // Update visual feedback
        updateAttributedText(in: textView)

        // Auto-scroll to cursor
        scrollToCursor(in: textView)
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        // Handle tab key - convert to spaces
        if replacementString == "\t" {
            let spacesString = String(repeating: " ", count: Int(parent.spaces))
            textView.insertText(spacesString, replacementRange: affectedCharRange)
            return false
        }

        // Prevent typing beyond target text length
        let newLength = textView.string.count - affectedCharRange.length + (replacementString?.count ?? 0)
        if newLength > parent.targetText.count {
            NSSound.beep() // Audio feedback when trying to type too much
            return false
        }

        return true
    }

    /// Update the attributed text with color coding
    func updateAttributedText(in textView: NSTextView) {
        let targetText = visualizeSpecialCharacters(in: parent.targetText)
        let typedText = visualizeSpecialCharacters(in: parent.typedText)

        // Create attributed string from target text
        let attributedString = NSMutableAttributedString(string: targetText)

        // Set base font for all text
        let font = NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .bold)
        attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: targetText.count))

        // Color each character based on typing status
        for (index, targetChar) in targetText.enumerated() {
            let range = NSRange(location: index, length: 1)

            if index < typedText.count {
                // User has typed this character
                let typedIndex = typedText.index(typedText.startIndex, offsetBy: index)
                let typedChar = typedText[typedIndex]

                if typedChar == targetChar {
                    // Correct character - green
                    attributedString.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: range)
                } else {
                    // Incorrect character - red with light background
                    attributedString.addAttribute(.foregroundColor, value: NSColor.white, range: range)
                    attributedString.addAttribute(.backgroundColor, value: NSColor.systemRed, range: range)
                }
            } else {
                // Not yet typed - gray placeholder
                attributedString.addAttribute(.foregroundColor, value: NSColor.placeholderTextColor, range: range)
            }
        }

        // Preserve cursor position
        let selectedRange = textView.selectedRange()

        // Update text view
        textView.textStorage?.setAttributedString(attributedString)

        // Restore cursor position (at the end of typed text)
        let newCursorPosition = min(typedText.count, targetText.count)
        textView.setSelectedRange(NSRange(location: newCursorPosition, length: 0))
    }

    /// Visualize special characters for better typing feedback
    private func visualizeSpecialCharacters(in text: String) -> String {
        return text
            .replacingOccurrences(of: " ", with: "·")   // Space → middle dot
            .replacingOccurrences(of: "\t", with: "→")  // Tab → arrow
            .replacingOccurrences(of: "\n", with: "↵\n") // Newline → return symbol
    }

    /// Auto-scroll to keep cursor visible
    private func scrollToCursor(in textView: NSTextView) {
        guard let scrollView = textView.superview?.superview as? NSScrollView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        let selectedRange = textView.selectedRange()
        let glyphRange = layoutManager.glyphRange(forCharacterRange: selectedRange, actualCharacterRange: nil)
        var rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

        rect.origin.x += textContainer.lineFragmentPadding
        rect.origin.y += textView.textContainerInset.height

        if !scrollView.visibleRect.contains(rect.origin) {
            textView.scrollToVisible(rect)
        }
    }
}

// MARK: - Preview
struct ModernTypingEditor_Previews: PreviewProvider {
    static var previews: some View {
        ModernTypingEditor(
            typedText: .constant("Hello"),
            targetText: .constant("Hello World! This is a typing test."),
            fontSize: 18
        )
        .frame(width: 600, height: 400)
    }
}
