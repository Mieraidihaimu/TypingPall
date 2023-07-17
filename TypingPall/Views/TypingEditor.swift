//
//  TypingEditor.swift
//  TypingPall
//
//  Created by Mieraidihaimu Mieraisan on 13/07/2023.
//

import AppKit
import SwiftUI

struct TypingEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var placeholder: String

    let placeholderTextView = NSTextView()
    let typingTextView: NSTextView = {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        return textView
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()
        placeholderTextView.string = placeholder
        placeholderTextView.textColor = NSColor.placeholderTextColor
        placeholderTextView.font = NSFont.monospacedSystemFont(ofSize: 25, weight: .bold)
        placeholderTextView.isEditable = false
        placeholderTextView.isSelectable = false

        typingTextView.delegate = context.coordinator
        typingTextView.backgroundColor = NSColor.clear
        typingTextView.textColor = NSColor.systemGreen
        typingTextView.font = NSFont.monospacedSystemFont(ofSize: 25, weight: .bold)

        guard let typingTextScrollView = typingTextView.superview?.superview else { return containerView }

        containerView.addSubview(typingTextScrollView)

        typingTextScrollView.translatesAutoresizingMaskIntoConstraints = false
        typingTextScrollView.subviews.first?.subviews.insert(placeholderTextView, at: 0)

        placeholderTextView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            placeholderTextView.topAnchor.constraint(equalTo: typingTextView.topAnchor),
            placeholderTextView.leadingAnchor.constraint(equalTo: typingTextView.leadingAnchor),
            placeholderTextView.trailingAnchor.constraint(equalTo: typingTextView.trailingAnchor),
            placeholderTextView.bottomAnchor.constraint(equalTo: typingTextView.bottomAnchor),
            typingTextScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            typingTextScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            typingTextScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            typingTextScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let typingTextView = nsView.subviews.first?.subviews.first?.subviews.last as? NSTextView,
              let placeholderTextView = typingTextView.superview?.subviews.first as? NSTextView
        else { return }

        typingTextView.string = text
        placeholderTextView.string = placeholder

        changeTypingTextColorIfNeeded(typingTextView, placeholder: placeholder)
    }

    func changeTypingTextColorIfNeeded(_ textView: NSTextView, placeholder: String) {
        guard !textView.string.isEmpty else { return }

        guard let range = textView.string.extractMismatchedRange(comparedTo: placeholder) else {
            textView.setTextColor(.systemGreen, range: NSMakeRange(0, textView.string.count))
            return
        }

        textView.setTextColor(.systemGreen, range: NSMakeRange(0,  range.location - 1))
        textView.setTextColor(.red, range: range)
    }
}

class Coordinator: NSObject, NSTextViewDelegate {
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

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        TypingEditor(text: .constant("Hello Wa"), placeholder: .constant("Hello World"))
    }
}
