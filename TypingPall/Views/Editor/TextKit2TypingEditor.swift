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
    var liveFeedback = true
    var onSubmit: (() -> Void)? = nil
    var onReject: ((PracticeText.InputRejection) -> Void)? = nil

    func makeCoordinator() -> TextKit2Coordinator { TextKit2Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        guard let textView = scrollView.documentView as? NSTextView else { return scrollView }
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.textContainerInset = NSSize(width: 16, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
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
        DispatchQueue.main.async { textView.window?.makeFirstResponder(textView) }
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
        if resetChanged { coordinator.submittedMismatch = nil }
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
    /// Without live feedback, the first difference is shown only after Return, until the next edit.
    var submittedMismatch: NSRange?

    init(_ parent: TextKit2TypingEditor) { self.parent = parent }

    func textDidChange(_ notification: Notification) {
        guard let view = notification.object as? NSTextView, view === textView else { return }
        // Let input methods finish composing before comparing or restyling.
        guard !view.hasMarkedText() else { return }
        submittedMismatch = nil
        parent.typedText = view.string
        applyStyle()
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSTextView.insertNewline(_:)),
              !textView.hasMarkedText(), let onSubmit = parent.onSubmit else { return false }
        onSubmit()
        if !parent.liveFeedback {
            submittedMismatch = LineDiff(typed: textView.string, target: parent.targetText).mismatchRange
            applyStyle()
        }
        return true
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange,
                  replacementString: String?) -> Bool {
        guard let replacementString else { return true }
        guard let range = Range(affectedCharRange, in: textView.string) else { parent.onReject?(.invalidRange); return false }
        let replacement = PracticeText.normalize(replacementString, tabSpaces: parent.tabSpaces)
        // Keep pastes and other text services within the current exercise line.
        if parent.onSubmit != nil && replacement.contains("\n") { NSSound.beep(); parent.onReject?(.multipleLines); return false }
        let proposed = textView.string.replacingCharacters(in: range, with: replacement)
        guard proposed.count <= PracticeText.maximumCharacters else { NSSound.beep(); parent.onReject?(.tooLong); return false }
        if replacement != replacementString {
            textView.insertText(replacement, replacementRange: affectedCharRange)
            return false
        }
        return true
    }

    func applyStyle() {
        guard let textView, !textView.hasMarkedText(), let storage = textView.textStorage else { return }
        let font = NSFont.monospacedSystemFont(ofSize: min(30, max(12, parent.fontSize)), weight: .regular)
        let base: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
        storage.beginEditing()
        storage.setAttributes(base, range: NSRange(location: 0, length: storage.length))
        let mismatch = parent.liveFeedback ? LineDiff(typed: storage.string, target: parent.targetText).mismatchRange : submittedMismatch
        if let rest = mismatch, NSMaxRange(rest) <= storage.length {
            storage.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: rest)
            let first = (storage.string as NSString).rangeOfComposedCharacterSequence(at: rest.location)
            storage.addAttributes([.foregroundColor: NSColor.labelColor,
                                   .underlineStyle: NSUnderlineStyle.thick.rawValue,
                                   .underlineColor: NSColor.systemRed,
                                   .backgroundColor: NSColor.systemRed.withAlphaComponent(0.15)], range: first)
        }
        storage.endEditing()
        textView.typingAttributes = base
    }
}
