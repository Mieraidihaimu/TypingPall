import AppKit
import SwiftUI

struct TypingEditor: NSViewRepresentable {
    @Binding var text: String
    @Binding var placeholder: String
    var fontSize: CGFloat

    @AppStorage("tabEqualsToSpaces") var spaces: Double = 4

    let placeholderTextView: NSTextView = {
        let textView = NSTextView()
        textView.textColor = NSColor.placeholderTextColor

        textView.isEditable = false
        textView.isSelectable = false
        return textView
    }()

    let typingTextView: NSTextView = {
        let scrollView = NSTextView.scrollableTextView()
        let textView = scrollView.documentView as! NSTextView
        textView.backgroundColor = NSColor.clear
        textView.textColor = NSColor.systemGreen
        return textView
    }()

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSView {
        let containerView = NSView()

        placeholderTextView.string = placeholder
        typingTextView.delegate = context.coordinator

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

        typingTextView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        placeholderTextView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        return containerView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard let typingTextView = nsView.subviews.first?.subviews.first?.subviews.last as? NSTextView,
              let placeholderTextView = typingTextView.superview?.subviews.first as? NSTextView
        else { return }

        if placeholderTextView.string != placeholder {
            // Reset the input text after updating the placeholder
            placeholderTextView.textColor = .placeholderTextColor
            placeholderTextView.string = placeholder
            typingTextView.string = ""
        }

        typingTextView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        placeholderTextView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
    }
}

struct SwiftUIView_Previews: PreviewProvider {
    static var previews: some View {
        TypingEditor(text: .constant("Hello Wa"), placeholder: .constant("Hello World"), fontSize: 16)
    }
}
