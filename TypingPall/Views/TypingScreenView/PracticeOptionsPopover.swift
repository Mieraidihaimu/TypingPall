import SwiftUI

struct PracticeOptionsPopover: View {
    @ObservedObject var viewModel: TypingScreenViewModel

    var body: some View {
        Form {
            Picker("Mode", selection: Binding(get: { viewModel.mode }, set: { viewModel.setMode($0) })) {
                ForEach(PracticeMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("practiceMode")
            Text(caption(for: viewModel.mode)).font(.caption).foregroundColor(.secondary)
            Toggle("Skip comments", isOn: Binding(get: { viewModel.skipComments }, set: { viewModel.setSkipComments($0) }))
                .disabled(viewModel.mode.isGraded)
                .accessibilityIdentifier("skipComments")
            if viewModel.mode.isGraded {
                Text("Comments stay visible as cues.").font(.caption).foregroundColor(.secondary)
            }
            Picker("Language", selection: Binding(get: { viewModel.language }, set: { viewModel.setLanguage($0) })) {
                ForEach(CodeLanguage.allCases) { Text($0.title).tag($0) }
            }
            Text("Tabs expand to \(viewModel.sessionTabSpaces) spaces. Change this in Settings.")
                .font(.caption).foregroundColor(.secondary)
        }
        .padding(16)
        .frame(width: 320)
    }

    private func caption(for mode: PracticeMode) -> String {
        switch mode {
        case .copy: return "Type every line with the reference in view."
        case .keyLines: return "The key lines are hidden; type them from memory."
        case .recall: return "Every line after the signature is hidden; recall the pattern."
        }
    }
}
