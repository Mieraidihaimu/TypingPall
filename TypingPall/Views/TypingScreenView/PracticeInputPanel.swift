import SwiftUI

struct PracticeInputPanel: View {
    @ObservedObject var viewModel: TypingScreenViewModel
    let fontSize: Double
    #if os(iOS)
    let editorActive: Bool
    let focusRequest: UUID
    @State private var submitRequest: UUID?
    #endif
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
                        #if os(iOS)
                        .lineLimit(3)
                        #endif
                }
                editor
            }
            .background(TypingPalette.practiceInputBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(viewModel.isLineMatched && !viewModel.mode.isGraded ? Color.accentColor.opacity(0.6) : Color.secondary.opacity(0.25),
                            lineWidth: viewModel.isLineMatched && !viewModel.mode.isGraded ? 1.5 : 1)
            )
            .animation(.easeInOut(duration: 0.15), value: viewModel.isLineMatched)
            #if os(iOS)
            VStack(alignment: .leading, spacing: 6) {
                status
                ViewThatFits(in: .horizontal) {
                    HStack { actions }
                    VStack(alignment: .leading) { actions }
                }
                .buttonStyle(.bordered)
            }
            #else
            HStack {
                status
                Spacer()
                actions
            }
            #endif
        }
        .onChange(of: viewModel.editorText) { notice = nil }
        .onChange(of: viewModel.sessionID) { notice = nil }
    }

    @ViewBuilder private var editor: some View {
        #if os(iOS)
        PadTypingEditor(text: $viewModel.editorText, target: viewModel.currentLine, fontSize: fontSize,
                        tabSpaces: viewModel.sessionTabSpaces, tolerance: viewModel.diffTolerance,
                        canEdit: viewModel.hasPracticeLines, isActive: editorActive, resetID: viewModel.sessionID,
                        focusRequest: focusRequest, submitRequest: submitRequest, liveFeedback: !viewModel.mode.isGraded,
                        onSubmit: {
                            let session = viewModel.sessionID
                            viewModel.send(.commitLineOnReturn)
                            return viewModel.sessionID == session && !viewModel.isComplete
                        }, onReject: { notice = $0.message })
            .frame(height: max(48, fontSize * 2 + 12))
        #else
        TextKit2TypingEditor(typedText: $viewModel.editorText, targetText: .constant(viewModel.currentLine),
                             fontSize: fontSize, tabSpaces: viewModel.sessionTabSpaces,
                             diffTolerance: viewModel.diffTolerance,
                             isEnabled: viewModel.hasPracticeLines, resetID: viewModel.sessionID,
                             liveFeedback: !viewModel.mode.isGraded,
                             onSubmit: { viewModel.send(.commitLineOnReturn) }, onReject: { notice = $0.message })
            .frame(minHeight: 100, idealHeight: 130, maxHeight: 160)
        #endif
    }

    private var status: some View {
        Label(statusText, systemImage: viewModel.isLineMatched && !viewModel.mode.isGraded ? "checkmark.circle.fill" : "keyboard")
            .foregroundColor(viewModel.isLineMatched && !viewModel.mode.isGraded ? .primary : .secondary)
            .accessibilityIdentifier("lineGuidance")
    }

    @ViewBuilder private var actions: some View {
        if !viewModel.hasPracticeLines && !viewModel.mode.isGraded {
            Button("Include Comments") { viewModel.setSkipComments(false) }
                .accessibilityIdentifier("includeComments")
        }
        Button {
            viewModel.revealHint()
        } label: {
            HStack(spacing: 3) {
                Text("Hint")
                Text("⌘'").font(.caption2).foregroundColor(.secondary)
            }
        }
        .keyboardShortcut("'", modifiers: .command)
        .disabled(!viewModel.hasPracticeLines || viewModel.isComplete)
        .accessibilityIdentifier("hintButton")
        Button {
            viewModel.repeatLine()
        } label: {
            HStack(spacing: 3) {
                Text("Repeat Line")
            }
        }
        .disabled(!viewModel.hasPracticeLines || viewModel.isComplete)
        .accessibilityIdentifier("repeatLine")
        if primaryEnabled && !viewModel.isComplete {
            Button {
                submit()
            } label: {
                HStack(spacing: 4) {
                    Text(primaryTitle)
                    Text("↵").font(.caption).fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!primaryEnabled || viewModel.isComplete)
            .accessibilityIdentifier("nextLine")
        } else {
            Button {
                submit()
            } label: {
                Text(primaryTitle)
            }
            .disabled(!primaryEnabled || viewModel.isComplete)
            .accessibilityIdentifier("nextLine")
        }
    }

    private func submit() {
        #if os(iOS)
        submitRequest = UUID()
        #else
        viewModel.advanceLine()
        #endif
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
