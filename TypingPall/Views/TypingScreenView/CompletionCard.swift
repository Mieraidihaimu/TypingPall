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
                    mainButton("Next: \(nextLesson.title)", id: "completionNext", action: onNext)
                    repeatButton
                    libraryButton
                } else if isUserScript {
                    mainButton("Repeat Pattern", id: "completionRepeat", action: onRepeat)
                    libraryButton
                } else {
                    mainButton("Open Library", id: "completionLibrary", action: onLibrary)
                    repeatButton
                }
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    @ViewBuilder private func mainButton(_ title: String, id: String, action: @escaping () -> Void) -> some View {
        if accessoryOwnsDefaultAction {
            Button(title, action: action).accessibilityIdentifier(id)
        } else {
            Button(title, action: action)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(id)
        }
    }

    private var repeatButton: some View {
        Button("Repeat Pattern", action: onRepeat).accessibilityIdentifier("completionRepeat")
    }

    private var libraryButton: some View {
        Button("Library", action: onLibrary).accessibilityIdentifier("completionLibrary")
    }
}

extension CompletionCard where Accessory == EmptyView {
    init(title: String, nextLesson: PracticeLesson?, isUserScript: Bool,
         onNext: @escaping () -> Void, onRepeat: @escaping () -> Void, onLibrary: @escaping () -> Void) {
        self.init(title: title, nextLesson: nextLesson, isUserScript: isUserScript,
                  onNext: onNext, onRepeat: onRepeat, onLibrary: onLibrary) { EmptyView() }
    }
}
