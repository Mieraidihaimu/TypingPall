import SwiftUI

struct CompletionCard<Accessory: View>: View {
    let title: String
    let nextLesson: PracticeLesson?
    let isUserScript: Bool
    var accessoryOwnsDefaultAction = false
    let onNext: () -> Void
    let onRepeat: () -> Void
    let onLibrary: () -> Void
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            accessory()
            Label("\(title) · complete", systemImage: "checkmark.circle")
                .font(.headline)
            Text("Take a moment to recall what each step does.")
                .foregroundColor(.secondary)
            HStack(spacing: 12) {
                if let nextLesson {
                    repeatButton
                    libraryButton
                    Spacer()
                    mainButton("Next: \(nextLesson.title)", id: "completionNext", action: onNext)
                } else if isUserScript {
                    libraryButton
                    Spacer()
                    mainButton("Repeat Pattern", id: "completionRepeat", action: onRepeat)
                } else {
                    repeatButton
                    Spacer()
                    mainButton("Open Library", id: "completionLibrary", action: onLibrary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TypingPalette.codeCanvas)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TypingPalette.subtleBorder, lineWidth: 1)
        )
    }

    @ViewBuilder private func mainButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        if accessoryOwnsDefaultAction {
            Button(title, action: action)
                .buttonStyle(.bordered)
                .accessibilityIdentifier(id)
        } else {
            Button(title, action: action)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(id)
        }
    }

    private var repeatButton: some View {
        Button("Repeat Pattern", action: onRepeat)
            .buttonStyle(.bordered)
            .accessibilityIdentifier("completionRepeat")
    }

    private var libraryButton: some View {
        Button("Library", action: onLibrary)
            .buttonStyle(.borderless)
            .foregroundColor(.secondary)
            .accessibilityIdentifier("completionLibrary")
    }
}

extension CompletionCard where Accessory == EmptyView {
    init(title: String, nextLesson: PracticeLesson?, isUserScript: Bool,
         onNext: @escaping () -> Void, onRepeat: @escaping () -> Void, onLibrary: @escaping () -> Void) {
        self.init(title: title, nextLesson: nextLesson, isUserScript: isUserScript,
                  onNext: onNext, onRepeat: onRepeat, onLibrary: onLibrary) { EmptyView() }
    }
}
