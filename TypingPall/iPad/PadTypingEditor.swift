import SwiftUI
import UIKit

struct PadTypingEditor: UIViewRepresentable {
    @Binding var text: String
    let target: String
    let fontSize: CGFloat
    let tabSpaces: Int
    let tolerance: DiffTolerance
    let canEdit: Bool
    let isActive: Bool
    let resetID: UUID
    let focusRequest: UUID
    let submitRequest: UUID?
    let liveFeedback: Bool
    let onSubmit: () -> Bool
    let onReject: (PracticeText.InputRejection) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PracticeTextView {
        // The designated initializer also initializes our Swift keyboard state.
        let field = PracticeTextView(frame: .zero, textContainer: nil)
        let coordinator = context.coordinator
        field.delegate = coordinator
        field.pasteDelegate = coordinator
        field.backgroundColor = .clear
        field.textContainerInset = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
        field.textContainer.lineFragmentPadding = 0
        field.allowsEditingTextAttributes = false
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.inlinePredictionType = .no
        field.returnKeyType = .done
        field.accessibilityIdentifier = "practiceInput"
        field.accessibilityLabel = "Practice input"
        field.onAttach = { [weak coordinator, weak field] in
            if let field { coordinator?.requestFocus(in: field) }
        }
        field.onReturn = { [weak coordinator, weak field] in
            if let field { coordinator?.submit(in: field) }
        }
        return field
    }

    func updateUIView(_ field: PracticeTextView, context: Context) {
        let coordinator = context.coordinator
        let previous = coordinator.parent
        coordinator.parent = self
        if previous.isActive && !isActive {
            coordinator.restoreFocus = field.isFirstResponder
        }
        if field.isEditable != canEdit { field.isEditable = canEdit }
        let font = UIFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        if field.font != font { field.font = font }
        if previous.resetID != resetID {
            coordinator.reset(field, to: text)
        } else if field.markedTextRange == nil, field.text != text {
            coordinator.reset(field, to: text)
        }

        if let submitRequest, previous.submitRequest != submitRequest {
            // A SwiftUI update cannot publish a new attempt synchronously.
            Task { @MainActor [weak coordinator, weak field] in
                guard let coordinator, let field, coordinator.parent.resetID == resetID,
                      coordinator.parent.submitRequest == submitRequest else { return }
                coordinator.submit(in: field)
            }
        }
        coordinator.updateFeedback(in: field)
        coordinator.requestFocus(in: field)
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UITextPasteDelegate {
        var parent: PadTypingEditor
        var restoreFocus = false
        private var focusedRequest: UUID?
        private var synchronizing = false
        private var submittedMismatch: NSRange?
        private var displayedMismatch: NSRange?

        init(_ parent: PadTypingEditor) { self.parent = parent }

        func reset(_ field: PracticeTextView, to text: String) {
            synchronizing = true
            field.unmarkText()
            field.text = text
            field.selectedRange = NSRange(location: text.utf16.count, length: 0)
            field.undoManager?.removeAllActions()
            submittedMismatch = nil
            displayedMismatch = nil
            synchronizing = false
        }

        func requestFocus(in field: PracticeTextView) {
            guard parent.isActive, parent.canEdit, field.window != nil,
                  restoreFocus || focusedRequest != parent.focusRequest else { return }
            let request = parent.focusRequest
            Task { @MainActor [weak self, weak field] in
                guard let self, let field, parent.focusRequest == request,
                      parent.isActive, parent.canEdit, field.window != nil,
                      restoreFocus || focusedRequest != request else { return }
                if field.becomeFirstResponder() {
                    focusedRequest = request
                    restoreFocus = false
                }
            }
        }

        func submit(in field: PracticeTextView) {
            guard parent.isActive, parent.canEdit, field.window != nil,
                  field.markedTextRange == nil, field.text == parent.text else { return }
            let stayedOnLine = parent.onSubmit()
            submittedMismatch = stayedOnLine && !parent.liveFeedback
                ? LineDiff(typed: field.text, target: parent.target).mismatchRange : nil
            updateFeedback(in: field)
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            guard let field = textView as? PracticeTextView, parent.isActive, !synchronizing else { return false }
            if text == "\n" || text == "\r" || text == "\r\n" {
                if !field.isHandlingPhysicalReturn, field.markedTextRange == nil {
                    submit(in: field)
                }
                return false
            }
            guard field.markedTextRange == nil else { return true }
            guard let replacement = validated(text, replacing: range, in: field.text) else { return false }
            if replacement == text { return true }
            if let start = field.position(from: field.beginningOfDocument, offset: range.location),
               let end = field.position(from: start, offset: range.length),
               let textRange = field.textRange(from: start, to: end) {
                field.replace(textRange, withText: replacement)
            }
            return false
        }

        // UIKit calls this for paste and drop. A pasted newline is never a submit.
        func textPasteConfigurationSupporting(_ supporting: UITextPasteConfigurationSupporting,
                                              performPasteOf attributedString: NSAttributedString,
                                              to textRange: UITextRange) -> UITextRange {
            guard let field = supporting as? PracticeTextView, parent.isActive, parent.canEdit else { return textRange }
            let start = field.offset(from: field.beginningOfDocument, to: textRange.start)
            let length = field.offset(from: textRange.start, to: textRange.end)
            guard let replacement = validated(attributedString.string,
                                              replacing: NSRange(location: start, length: length), in: field.text) else {
                return field.selectedTextRange ?? textRange
            }
            field.replace(textRange, withText: replacement)
            return field.selectedTextRange ?? textRange
        }

        private func validated(_ text: String, replacing range: NSRange, in original: String) -> String? {
            guard let range = Range(range, in: original) else {
                parent.onReject(.invalidRange)
                return nil
            }
            let normalized = PracticeText.normalize(text, tabSpaces: parent.tabSpaces)
            guard !normalized.contains(where: \.isNewline) else {
                parent.onReject(.multipleLines)
                return nil
            }
            guard original.replacingCharacters(in: range, with: normalized).count <= PracticeText.maximumCharacters else {
                parent.onReject(.tooLong)
                return nil
            }
            return normalized
        }

        func textViewDidChange(_ textView: UITextView) {
            guard let field = textView as? PracticeTextView, !synchronizing, field.markedTextRange == nil else { return }
            // An input method can commit a replacement without asking the delegate.
            guard let text = validated(field.text, replacing: NSRange(location: 0, length: 0), in: "") else {
                reset(field, to: parent.text)
                return
            }
            if text != field.text { reset(field, to: text) }
            submittedMismatch = nil
            if parent.text != text { parent.text = text }
            updateFeedback(in: field, afterEdit: true)
        }

        func updateFeedback(in field: PracticeTextView, afterEdit: Bool = false) {
            guard field.markedTextRange == nil, let manager = field.textLayoutManager,
                  let storage = manager.textContentManager else { return }
            let text = field.text ?? ""
            let mismatch = parent.liveFeedback
                ? LineDiff.evaluate(target: PreparedTargetLine(rawLine: parent.target),
                                    typed: text, tolerance: parent.tolerance).errorUTF16Range : submittedMismatch
            guard afterEdit || mismatch != displayedMismatch else { return }
            displayedMismatch = mismatch

            // Rendering attributes live in TextKit's layout, outside the text and undo history.
            let document = manager.documentRange
            manager.removeRenderingAttribute(.underlineStyle, for: document)
            manager.removeRenderingAttribute(.underlineColor, for: document)
            guard let mismatch, mismatch.location < text.utf16.count else { return }
            let first = (text as NSString).rangeOfComposedCharacterSequence(at: mismatch.location)
            guard let start = storage.location(document.location, offsetBy: first.location),
                  let end = storage.location(start, offsetBy: first.length),
                  let range = NSTextRange(location: start, end: end) else { return }
            manager.addRenderingAttribute(.underlineStyle, value: NSUnderlineStyle.thick.rawValue, for: range)
            manager.addRenderingAttribute(.underlineColor, value: UIColor.systemRed, for: range)
        }
    }
}

final class PracticeTextView: UITextView {
    var onAttach: (() -> Void)?
    var onReturn: (() -> Void)?
    private var heldReturns: Set<UIKeyboardHIDUsage> = []
    private var composingReturns: Set<UIKeyboardHIDUsage> = []
    var isHandlingPhysicalReturn: Bool { !heldReturns.isEmpty || !composingReturns.isEmpty }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { onAttach?() }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let forwarded = presses.filter { press in
            guard let key = plainReturn(in: press) else { return true }
            if composingReturns.contains(key) || (heldReturns.isEmpty && markedTextRange != nil) {
                composingReturns.insert(key)
                return true
            }
            heldReturns.insert(key)
            return false
        }
        if !forwarded.isEmpty { super.pressesBegan(forwarded, with: event) }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var submit = false
        let forwarded = presses.filter { press in
            guard let key = press.key?.keyCode, heldReturns.remove(key) != nil else { return true }
            submit = true
            return false
        }
        if !forwarded.isEmpty { super.pressesEnded(forwarded, with: event) }
        for press in forwarded {
            if let key = press.key?.keyCode { composingReturns.remove(key) }
        }
        // Submit on release so holding Return can't advance into a newly focused completion action.
        if submit && isFirstResponder { onReturn?() }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let forwarded = presses.filter { press in
            guard let key = press.key?.keyCode else { return true }
            composingReturns.remove(key)
            return heldReturns.remove(key) == nil
        }
        if !forwarded.isEmpty { super.pressesCancelled(forwarded, with: event) }
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            heldReturns.removeAll()
            composingReturns.removeAll()
        }
        return resigned
    }

    private func plainReturn(in press: UIPress) -> UIKeyboardHIDUsage? {
        guard let key = press.key,
              [.keyboardReturnOrEnter, .keyboardReturn, .keypadEnter].contains(key.keyCode),
              key.modifierFlags.intersection([.command, .control, .alternate, .shift]).isEmpty else { return nil }
        return key.keyCode
    }
}
