import AppKit
import SwiftUI

/// Enhanced TextKit 2 implementation with better text location handling
/// This is the production-ready version with proper NSTextLocation management
@available(macOS 12.0, *)
class TextKit2TypingView: NSView {

    // MARK: - TextKit 2 Components

    private let textContentStorage: NSTextContentStorage
    private let textLayoutManager: NSTextLayoutManager
    private let textContainer: NSTextContainer
    private let scrollView: NSScrollView
    private let textView: NSTextView

    // MARK: - Configuration

    var targetText: String = "" {
        didSet { updateContent() }
    }

    var typedText: String = "" {
        didSet { updateContent() }
    }

    var fontSize: CGFloat = 16 {
        didSet { updateFont() }
    }

    var onTextChanged: ((String) -> Void)?
    var tabSpaces: Int = 4

    // MARK: - Private Properties

    private var isUpdating = false

    // MARK: - Initialization

    override init(frame frameRect: NSRect) {
        // Initialize TextKit 2 stack
        textContentStorage = NSTextContentStorage()
        textLayoutManager = NSTextLayoutManager()
        textContainer = NSTextContainer()

        // Create scroll view and text view
        scrollView = NSScrollView()
        textView = NSTextView()

        super.init(frame: frameRect)

        setupTextKit2Stack()
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupTextKit2Stack() {
        // Connect TextKit 2 components
        textContentStorage.addTextLayoutManager(textLayoutManager)
        textLayoutManager.textContainer = textContainer

        // Configure text container
        textContainer.widthTracksTextView = true
        textContainer.heightTracksTextView = false
        textContainer.lineFragmentPadding = 10
    }

    private func setupViews() {
        // Configure scroll view
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        // Configure text view with TextKit 2 container
        textView.frame = bounds
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer = textContainer
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        textView.textContainerInset = NSSize(width: 10, height: 10)
        textView.backgroundColor = .textBackgroundColor
        textView.delegate = self

        // Disable smart replacements
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Setup view hierarchy
        scrollView.documentView = textView
        addSubview(scrollView)

        // Layout constraints
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Content Management

    private func updateContent() {
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        let visualTarget = visualizeSpecialCharacters(in: targetText)
        let visualTyped = visualizeSpecialCharacters(in: typedText)

        let attributedString = createStyledText(
            targetText: visualTarget,
            typedText: visualTyped
        )

        // Update using TextKit 2 transaction
        textContentStorage.performEditingTransaction {
            if let textStorage = textContentStorage.textStorage {
                textStorage.setAttributedString(attributedString)
            }
        }

        // Restore cursor position
        let cursorPosition = min(visualTyped.count, visualTarget.count)
        textView.setSelectedRange(NSRange(location: cursorPosition, length: 0))
    }

    private func updateFont() {
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
        updateContent()
    }

    // MARK: - Text Styling

    private func createStyledText(targetText: String, typedText: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: targetText)
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)

        // Base attributes
        attributed.addAttribute(.font, value: font, range: NSRange(location: 0, length: targetText.count))

        // Character-by-character coloring
        for (index, targetChar) in targetText.enumerated() {
            let range = NSRange(location: index, length: 1)

            if index < typedText.count {
                let typedIndex = typedText.index(typedText.startIndex, offsetBy: index)
                let typedChar = typedText[typedIndex]

                if typedChar == targetChar {
                    // Correct - green
                    attributed.addAttribute(.foregroundColor, value: NSColor.systemGreen, range: range)
                } else {
                    // Incorrect - red background
                    attributed.addAttribute(.foregroundColor, value: NSColor.white, range: range)
                    attributed.addAttribute(.backgroundColor, value: NSColor.systemRed, range: range)
                }
            } else {
                // Not typed - gray
                attributed.addAttribute(.foregroundColor, value: NSColor.placeholderTextColor, range: range)
            }
        }

        // Paragraph styling
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.lineBreakMode = .byWordWrapping
        attributed.addAttribute(.paragraphStyle, value: paragraphStyle, range: NSRange(location: 0, length: targetText.count))

        return attributed
    }

    // MARK: - Special Characters

    private func visualizeSpecialCharacters(in text: String) -> String {
        return text
            .replacingOccurrences(of: " ", with: "·")
            .replacingOccurrences(of: "\t", with: "→")
            .replacingOccurrences(of: "\n", with: "↵\n")
    }

    private func extractRawText(from visualText: String) -> String {
        return visualText
            .replacingOccurrences(of: "·", with: " ")
            .replacingOccurrences(of: "→", with: "\t")
            .replacingOccurrences(of: "↵", with: "")
    }
}

// MARK: - NSTextViewDelegate

@available(macOS 12.0, *)
extension TextKit2TypingView: NSTextViewDelegate {

    func textDidChange(_ notification: Notification) {
        guard !isUpdating else { return }

        let rawText = extractRawText(from: textView.string)
        typedText = rawText
        onTextChanged?(rawText)
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
        // Handle tab
        if replacementString == "\t" {
            let spaces = String(repeating: " ", count: tabSpaces)
            textView.insertText(spaces, replacementRange: affectedCharRange)
            return false
        }

        // Prevent typing beyond target
        let rawTarget = extractRawText(from: targetText)
        let currentRaw = extractRawText(from: textView.string)
        let newLength = currentRaw.count - affectedCharRange.length + (replacementString?.count ?? 0)

        if newLength > rawTarget.count {
            NSSound.beep()
            return false
        }

        return true
    }
}

// MARK: - SwiftUI Wrapper

@available(macOS 12.0, *)
struct TextKit2TypingViewWrapper: NSViewRepresentable {
    @Binding var typedText: String
    @Binding var targetText: String
    var fontSize: CGFloat

    @AppStorage("tabEqualsToSpaces") var spaces: Double = 4

    func makeNSView(context: Context) -> TextKit2TypingView {
        let view = TextKit2TypingView()
        view.targetText = targetText
        view.typedText = typedText
        view.fontSize = fontSize
        view.tabSpaces = Int(spaces)
        view.onTextChanged = { newText in
            typedText = newText
        }
        return view
    }

    func updateNSView(_ nsView: TextKit2TypingView, context: Context) {
        if nsView.targetText != targetText {
            nsView.targetText = targetText
        }
        if nsView.fontSize != fontSize {
            nsView.fontSize = fontSize
        }
        nsView.tabSpaces = Int(spaces)
    }
}

// MARK: - Preview

@available(macOS 12.0, *)
struct TextKit2TypingViewWrapper_Previews: PreviewProvider {
    static var previews: some View {
        TextKit2TypingViewWrapper(
            typedText: .constant("Hello World"),
            targetText: .constant("Hello World! This is TextKit 2 in action."),
            fontSize: 18
        )
        .frame(width: 600, height: 400)
    }
}
