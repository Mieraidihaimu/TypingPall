import SwiftUI

struct PracticeOptionsPopover: View {
    @ObservedObject var viewModel: TypingScreenViewModel

    var body: some View {
        Form {
            Toggle("Skip comments", isOn: Binding(get: { viewModel.skipComments }, set: { viewModel.setSkipComments($0) }))
                .disabled(viewModel.mode.isGraded)
                .accessibilityIdentifier("skipComments")
            if viewModel.mode.isGraded {
                Text("Comments stay visible as cues.").font(.caption).foregroundColor(.secondary)
            }
            Picker("Spacing", selection: Binding(get: { viewModel.diffTolerance }, set: { viewModel.setDiffTolerance($0) })) {
                Text("Strict").tag(DiffTolerance.strictCharacter)
                Text("Relaxed").tag(DiffTolerance.syntaxAwareTrivia)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("diffTolerancePicker")
            Text(toleranceCaption(for: viewModel.diffTolerance)).font(.caption).foregroundColor(.secondary)
            if viewModel.canEditLanguage {
                Picker("Language", selection: Binding(get: { viewModel.language }, set: { viewModel.setLanguage($0) })) {
                    ForEach(CodeLanguage.allCases) { Text($0.title).tag($0) }
                }
                .accessibilityIdentifier("scriptLanguagePicker")
                .help("Choose the language of your code for highlighting and comment handling.")
            } else {
                LabeledContent("Language", value: viewModel.language.title)
                    .accessibilityIdentifier("lessonLanguage")
            }
            Text("Tabs expand to \(viewModel.sessionTabSpaces) spaces. Change this in Settings.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 320)
    }

    private func toleranceCaption(for tolerance: DiffTolerance) -> String {
        switch tolerance {
        case .strictCharacter: return "Strict: exact character-for-character spacing."
        case .syntaxAwareTrivia: return "Relaxed: flexible spaces around operators."
        }
    }
}
