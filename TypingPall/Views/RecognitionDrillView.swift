import SwiftUI

/// "Which pattern?": read an original scenario, pick the pattern, then see the cues that identify it.
struct RecognitionDrillView: View {
    let lessons: [PracticeLesson]
    let onPractice: (PracticeLesson) -> Void
    @State private var drill: RecognitionDrill
    @AccessibilityFocusState private var feedbackFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(lessons: [PracticeLesson] = PracticeCatalog.lessons, seed: UInt64 = .random(in: .min ... .max),
         onPractice: @escaping (PracticeLesson) -> Void) {
        self.lessons = lessons
        self.onPractice = onPractice
        _drill = State(initialValue: RecognitionDrill(lessons: lessons, seed: seed))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Which pattern?").font(.title2).fontWeight(.semibold)
                if drill.current != nil {
                    Text("\(drill.position + 1) of \(drill.questions.count)").foregroundColor(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            if drill.questions.isEmpty {
                Text("No lessons have recognition prompts yet.").foregroundColor(.secondary)
            } else if let question = drill.current {
                questionView(question)
            } else {
                summary
            }
            Spacer(minLength: 0)
        }
        .padding(24)
    }

    @ViewBuilder private func questionView(_ question: RecognitionDrill.Question) -> some View {
        Text(question.prompt)
            .font(.title3)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("drillPrompt")
        VStack(spacing: 8) {
            ForEach(Array(question.options.enumerated()), id: \.element) { index, id in
                Button { choose(id) } label: {
                    HStack {
                        Text(lesson(id)?.title ?? id)
                        Spacer()
                        if drill.currentChoice != nil && id == question.lessonID {
                            Image(systemName: "checkmark.circle").accessibilityLabel("Answer")
                        } else if drill.currentChoice == id {
                            Image(systemName: "xmark.circle").accessibilityLabel("Your choice")
                        }
                        Text("\(index + 1)").foregroundColor(.secondary).accessibilityHidden(true)
                    }
                    .frame(maxWidth: .infinity)
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
                .disabled(drill.currentChoice != nil)
                .accessibilityIdentifier("drillOption\(index)")
            }
        }
        if let choice = drill.currentChoice, let answer = lesson(question.lessonID) {
            feedback(answer: answer, chosen: lesson(choice))
        }
    }

    private func feedback(answer: PracticeLesson, chosen: PracticeLesson?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(chosen?.id == answer.id ? "Recognized: \(answer.title)" : "This one is \(answer.title)")
                .font(.headline)
                .accessibilityFocused($feedbackFocused)
            if let chosen, chosen.id != answer.id, let cue = chosen.triggers?.first {
                Text("\(chosen.title) fits when: \(cue)").foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            if let triggers = answer.triggers, !triggers.isEmpty {
                Text("CUES TO NOTICE").font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                ForEach(triggers, id: \.self) { Text("• \($0)").fixedSize(horizontal: false, vertical: true) }
            }
            if let mantra = answer.mantra {
                Text(mantra).font(.headline).accessibilityIdentifier("drillMantra")
            }
            HStack {
                Button("Practice from Memory") { onPractice(answer); dismiss() }.accessibilityIdentifier("drillPractice")
                Spacer()
                Button("Next") { drill.advance() }.keyboardShortcut(.defaultAction).accessibilityIdentifier("drillNext")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("drillFeedback")
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recognized \(drill.recognizedCount) of \(drill.questions.count).").font(.title3).accessibilityIdentifier("drillSummary")
            ForEach(drill.missedLessonIDs, id: \.self) { id in
                if let missed = lesson(id) {
                    HStack {
                        Text(missed.title)
                        Spacer()
                        Button("Practice") { onPractice(missed); dismiss() }
                    }
                }
            }
            Button("New Round") { drill = RecognitionDrill(lessons: lessons, seed: .random(in: .min ... .max)) }
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("drillNewRound")
        }
    }

    private func lesson(_ id: String) -> PracticeLesson? { lessons.first { $0.id == id } }

    private func choose(_ id: String) {
        drill.choose(id)
        feedbackFocused = true
    }
}
