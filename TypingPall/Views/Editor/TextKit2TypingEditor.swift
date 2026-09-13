import AppKit
import SwiftUI

/// Native plain-text input. The reference is rendered separately so it can never
/// enter the user's input or undo history. Uses the macOS 12 NSTextView API.
struct TextKit2TypingEditor: NSViewRepresentable {
    @Binding var typedText: String
    @Binding var targetText: String
    var fontSize: CGFloat
    var tabSpaces: Int = 4
    var isEnabled = true
    var resetID: UUID? = nil
    var onSubmit: (() -> Void)? = nil

    func makeCoordinator() -> TextKit2Coordinator { TextKit2Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.setAccessibilityIdentifier("practiceInput")
        textView.setAccessibilityLabel("Type the highlighted line here")
        context.coordinator.textView = textView
        updateNSView(scrollView, context: context)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        let targetChanged = coordinator.parent.targetText != targetText
        let resetChanged = coordinator.parent.resetID != resetID
        coordinator.parent = self
        guard let textView = coordinator.textView else { return }
        textView.isEditable = isEnabled
        // SwiftUI refreshes must not replace an unfinished IME composition.
        guard !textView.hasMarkedText() else { return }
        if resetChanged || textView.string != typedText {
            textView.string = typedText
            textView.setSelectedRange(NSRange(location: typedText.utf16.count, length: 0))
            textView.undoManager?.removeAllActions()
        } else if targetChanged {
            textView.undoManager?.removeAllActions()
        }
        coordinator.applyStyle()
    }

    static func dismantleNSView(_ nsView: NSScrollView, coordinator: TextKit2Coordinator) {
        coordinator.textView?.delegate = nil
    }
}

final class TextKit2Coordinator: NSObject, NSTextViewDelegate {
    var parent: TextKit2TypingEditor
    weak var textView: NSTextView?

    init(_ parent: TextKit2TypingEditor) { self.parent = parent }

    func textDidChange(_ notification: Notification) {
        guard let view = notification.object as? NSTextView, view === textView else { return }
        // Let input methods finish composing before comparing or restyling.
        guard !view.hasMarkedText() else { return }
        parent.typedText = view.string
        applyStyle()
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSTextView.insertNewline(_:)),
              !textView.hasMarkedText(), let onSubmit = parent.onSubmit else { return false }
        onSubmit()
        return true
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange,
                  replacementString: String?) -> Bool {
        guard let replacementString else { return true }
        guard let range = Range(affectedCharRange, in: textView.string) else { return false }
        let replacement = PracticeText.normalize(replacementString, tabSpaces: parent.tabSpaces)
        // Keep pastes and other text services within the current exercise line.
        if parent.onSubmit != nil && replacement.contains("\n") { NSSound.beep(); return false }
        let proposed = textView.string.replacingCharacters(in: range, with: replacement)
        guard proposed.count <= PracticeText.maximumCharacters else { NSSound.beep(); return false }
        if replacement != replacementString {
            textView.insertText(replacement, replacementRange: affectedCharRange)
            return false
        }
        return true
    }

    func applyStyle() {
        guard let textView, !textView.hasMarkedText(), let storage = textView.textStorage else { return }
        let font = NSFont.monospacedSystemFont(ofSize: min(30, max(12, parent.fontSize)), weight: .regular)
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.beginEditing()
        storage.setAttributes([.font: font, .foregroundColor: NSColor.labelColor], range: fullRange)
        var target = parent.targetText.makeIterator()
        var offset = 0
        for character in textView.string {
            let length = String(character).utf16.count
            let correct = character == target.next()
            let range = NSRange(location: offset, length: length)
            storage.addAttribute(.foregroundColor, value: correct ? NSColor.systemGreen : NSColor.systemRed, range: range)
            if !correct {
                storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            offset += length
        }
        storage.endEditing()
        textView.typingAttributes = [.font: font, .foregroundColor: NSColor.labelColor]
    }
}
