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

    let placeholderTextView: NSTextView = {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        return textView
    }()

    let typingTextView: NSTextView = {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        return textView
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func updatePlaceholder(_ placeholderText: String) {
        placeholderTextView.string = placeholderText
        text = ""
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
        typingTextView.isRichText = true
        typingTextView.font = NSFont.monospacedSystemFont(ofSize: 25, weight: .bold)
        typingTextView.textContainerInset = NSMakeSize(0, containerView.frame.size.height / 2)

        guard let placeholderTextScrollView = placeholderTextView.superview?.superview,
              let typingTextScrollView = typingTextView.superview?.superview else { return containerView}

        containerView.addSubview(placeholderTextScrollView)
        containerView.addSubview(typingTextScrollView)

        placeholderTextScrollView.translatesAutoresizingMaskIntoConstraints = false
        typingTextScrollView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            placeholderTextScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            placeholderTextScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            placeholderTextScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            placeholderTextScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            typingTextScrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            typingTextScrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            typingTextScrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            typingTextScrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let placeholderTextView = nsView.subviews.first as? NSTextView,
              let typingTextView = nsView.subviews.last as? NSTextView else { return }

        typingTextView.string = text
        placeholderTextView.string = placeholder
    }
}

class Coordinator: NSObject, NSTextViewDelegate {
    var parent: TypingEditor

    init(_ parent: TypingEditor) {
        self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView, textView === parent.typingTextView else { return }

        defer {
            if let cursorPosition = cursorPosition(in: textView),
                let scrollView = textView.superview?.superview as? NSScrollView {
                scrollView.scroll(cursorPosition)
            }
        }

        defer { parent.text = textView.string }

        changeTypingTextColorIfNeeded(textView, placeholder: parent.placeholder)
    }

    func changeTypingTextColorIfNeeded(_ textView: NSTextView, placeholder: String) {
        guard !textView.string.isEmpty else { return }

        guard let range = textView.string.extractMismatchedRange(comparedTo: placeholder) else {
            textView.setTextColor(.systemGreen, range: NSMakeRange(0, textView.string.count))
            return
        }

        textView.setTextColor(.red, range: range)
        textView.setTextColor(.systemGreen, range: NSMakeRange(0,  range.location - 1))
    }

    func cursorPosition(in textView: NSTextView) -> NSPoint? {
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
