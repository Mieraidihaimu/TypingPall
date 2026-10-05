import SwiftUI

/// The graded outcome, retention line strip, and self-rating shown on the completion card.
struct AttemptOutcomeView: View {
    @ObservedObject var viewModel: TypingScreenViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let summary = viewModel.lastSummary, summary.mode.isGraded, let grade = viewModel.grade {
                VStack(alignment: .leading, spacing: 8) {
                    Text("\(summary.cleanLines.count) of ^[\(summary.lines.count) line](inflect: true) right on the first try · \(grade.title)")
                        .font(.headline)
                        .accessibilityIdentifier("attemptSummary")
                    Text("How did that feel?").foregroundColor(.secondary)
                    HStack {
                        ForEach(SelfRating.allCases) { rating in
                            Button { viewModel.rate(rating) } label: {
                                if viewModel.selfRating == rating { Label(rating.title, systemImage: "checkmark") } else { Text(rating.title) }
                            }
                            .accessibilityIdentifier("rate\(rating.title)")
                            .accessibilityAddTraits(viewModel.selfRating == rating ? .isSelected : [])
                        }
                    }
                }
            }

            if !viewModel.practiceLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("LINE RETENTION")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cleanLineCountText)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 3) {
                        ForEach(viewModel.practiceLines, id: \.sourceIndex) { line in
                            let attempt = viewModel.lineAttempts[line.sourceIndex]
                            let isClean = (attempt?.hints ?? 0) == 0 && (attempt?.wrongSubmits ?? 0) == 0 && !(attempt?.repeated ?? false)
                            let usedHint = (attempt?.hints ?? 0) > 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isClean ? Color.green.opacity(0.8) : (usedHint ? Color.orange.opacity(0.8) : Color.yellow.opacity(0.8)))
                                .frame(height: 6)
                                .frame(maxWidth: 32)
                                .help("Line \(line.sourceIndex + 1): \(isClean ? "Clean" : usedHint ? "Hint used" : "Needed correction")")
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            if viewModel.mode == .copy {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.accentColor)
                    Text("Ready to test recall? Key lines will be hidden.")
                        .font(.callout)
                    Spacer()
                    Button("Practice Key Lines (⌘2)") {
                        viewModel.setMode(.keyLines)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("levelUpKeyLines")
                }
                .padding(10)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(8)
            } else if viewModel.mode == .keyLines {
                HStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.accentColor)
                    Text("Take the final step: Recall the full pattern.")
                        .font(.callout)
                    Spacer()
                    Button("Practice Recall (⌘3)") {
                        viewModel.setMode(.recall)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("levelUpRecall")
                }
                .padding(10)
                .background(Color.accentColor.opacity(0.08))
                .cornerRadius(8)
            }
        }
    }

    private var cleanLineCountText: String {
        let clean = viewModel.practiceLines.filter { line in
            let att = viewModel.lineAttempts[line.sourceIndex]
            return (att?.hints ?? 0) == 0 && (att?.wrongSubmits ?? 0) == 0 && !(att?.repeated ?? false)
        }.count
        return "\(clean)/\(viewModel.practiceLines.count) clean"
    }
}
