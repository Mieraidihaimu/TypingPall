import SwiftUI

struct PracticeInputPanel: View {
    @ObservedObject var viewModel: TypingScreenViewModel
    let fontSize: Double
    var isCompact = false
    @State private var notice: String?
    @AppStorage("ux.hasSeenPracticeTip") private var hasSeenTip = false

    var targetText: String { viewModel.visibleTarget }
    var highlightOffset: Int? { viewModel.hintOffset }
    var statusText: String { notice ?? viewModel.learningStatus ?? guidance }
    var primaryTitle: String { viewModel.mode.isGraded ? "Check" : viewModel.isLastPracticeLine ? "Finish Pattern" : "Next Line" }
    var primaryEnabled: Bool { viewModel.mode.isGraded ? viewModel.hasPracticeLines : viewModel.isLineMatched }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !hasSeenTip {
                HStack(alignment: .firstTextBaseline) {
                    Image(systemName: "lightbulb")
                    Text("Type the line shown above the input. Leading indentation is skipped; press Return when it matches.")
                    Spacer()
                    Button("Got It") { hasSeenTip = true }.accessibilityIdentifier("dismissTip")
                }
                .font(.callout).padding(10)
                .background(Color.accentColor.opacity(0.08)).cornerRadius(8)
            }
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.bugHunt == nil {
                    Text(styledTarget)
                        .font(.system(size: min(30, max(12, fontSize)), design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16).padding(.top, 12)
                        .accessibilityIdentifier("targetLine")
                        .accessibilityLabel(stripLabel)
                        .accessibilityHint("The line to type")
                }
                TextKit2TypingEditor(typedText: $viewModel.editorText, targetText: .constant(viewModel.currentLine),
                                     fontSize: fontSize, tabSpaces: viewModel.sessionTabSpaces,
                                     isEnabled: viewModel.hasPracticeLines && !viewModel.isComplete, resetID: viewModel.sessionID,
                                     liveFeedback: viewModel.mode == .copy,
                                     onSubmit: { viewModel.advanceLine() }, onReject: { notice = $0.message })
                    .frame(minHeight: 100, idealHeight: 130, maxHeight: 160)
            }
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25)))
            HStack {
                Label(statusText, systemImage: viewModel.isLineMatched && !viewModel.mode.isGraded ? "checkmark.circle.fill" : "keyboard")
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("lineGuidance")
                Spacer()
                if !viewModel.hasPracticeLines && !viewModel.mode.isGraded {
                    Button("Include Comments") { viewModel.setSkipComments(false) }
                        .accessibilityIdentifier("includeComments")
                }
                Button("Hint") { viewModel.revealHint() }
                    .keyboardShortcut("'", modifiers: .command)
                    .disabled(!viewModel.hasPracticeLines || viewModel.isComplete)
                    .accessibilityIdentifier("hintButton")
                Button("Repeat Line") { viewModel.repeatLine() }
                    .disabled(!viewModel.hasPracticeLines || viewModel.isComplete)
                    .accessibilityIdentifier("repeatLine")
                Button(primaryTitle) { viewModel.advanceLine() }
                    .disabled(!primaryEnabled || viewModel.isComplete)
                    .accessibilityIdentifier("nextLine")
            }
        }
        .onChange(of: viewModel.editorText) { _ in notice = nil }
    }

    private var styledTarget: AttributedString {
        var text = AttributedString(targetText.isEmpty ? " " : targetText)
        if let offset = highlightOffset, offset < targetText.count {
            let start = text.characters.index(text.startIndex, offsetBy: offset)
            text[start..<text.characters.index(after: start)].backgroundColor = Color.accentColor.opacity(0.25)
        }
        return text
    }

    private var stripLabel: String {
        guard viewModel.mode.isGraded else { return targetText }
        let revealed = targetText.filter { $0 != MaskedLine.hidden }.trimmingCharacters(in: .whitespaces)
        return revealed.isEmpty ? "Hidden line" : "Hint: \(revealed)"
    }

    private var guidance: String {
        if !viewModel.hasPracticeLines { return "Only comments remain. Turn off Skip comments to practice them." }
        if viewModel.isComplete { return "Take a moment to recall what each step does." }
        if viewModel.currentLine.isEmpty { return "Blank line — press Return to continue." }
        if viewModel.isLineMatched { return "Line matched. Press Return to continue, or repeat this line." }
        return viewModel.skipComments && viewModel.language != .plainText ? "Type code only. Leading indentation and comments are skipped." : "Leading indentation is skipped. Correct any underlined differences, then press Return."
    }
}
