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
    let typingTextView = NSTextView()

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

        containerView.addSubview(placeholderTextView)
        containerView.addSubview(typingTextView)

        placeholderTextView.translatesAutoresizingMaskIntoConstraints = false
        typingTextView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            placeholderTextView.topAnchor.constraint(equalTo: containerView.topAnchor),
            placeholderTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            placeholderTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            placeholderTextView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            typingTextView.topAnchor.constraint(equalTo: containerView.topAnchor),
            typingTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            typingTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            typingTextView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
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

        defer { parent.text = textView.string }

        changeTypingTextColorIfNeeded(textView, placeholder: parent.placeholder)
    }

    func changeTypingTextColorIfNeeded(_ textView: NSTextView, placeholder: String) {
        guard !textView.string.isEmpty else { return }

        guard let range = textView.string.extractMismatchedRange(comparedTo: placeholder) else {
            textView.setTextColor(.systemGreen, range: NSMakeRange(0, textView.string.count - 1))
            return
        }

        textView.setTextColor(.red, range: NSMakeRange(range.location, textView.string.count - 1))
        textView.setTextColor(.systemGreen, range: NSMakeRange(0, range.location - 1))
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        TypingEditor(text: .constant("Hello Wa"), placeholder: .constant("Hello World"))
    }
}
