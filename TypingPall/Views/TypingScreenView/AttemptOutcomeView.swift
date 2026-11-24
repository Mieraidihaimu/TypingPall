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
                    HStack(spacing: 8) {
                        ForEach(SelfRating.allCases) { rating in
                            let isSelected = viewModel.selfRating == rating
                            let tint = ratingTint(for: rating)
                            Button { viewModel.rate(rating) } label: {
                                Group {
                                    if isSelected {
                                        Label(rating.title, systemImage: "checkmark")
                                    } else {
                                        Text(rating.title)
                                    }
                                }
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundColor(isSelected ? tint : .primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(tint.opacity(isSelected ? 0.20 : 0.08))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(tint.opacity(isSelected ? 0.9 : 0.28), lineWidth: isSelected ? 1.5 : 1)
                                )
                                .contentShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("rate\(rating.title)")
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
            }

            if !viewModel.practiceLines.isEmpty {
                let allClean = cleanLineCount == viewModel.practiceLines.count
                let pillColor = allClean ? TypingPalette.statusClean : TypingPalette.statusCorrected
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("LINE RETENTION")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(cleanLineCountText)
                            .font(.caption2.weight(.medium))
                            .foregroundColor(pillColor)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(pillColor.opacity(0.14))
                            .cornerRadius(6)
                    }
                    HStack(spacing: 3) {
                        ForEach(viewModel.practiceLines, id: \.sourceIndex) { line in
                            let attempt = viewModel.lineAttempts[line.sourceIndex]
                            let isClean = isLineClean(line)
                            let usedHint = (attempt?.hints ?? 0) > 0
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isClean ? TypingPalette.statusClean : (usedHint ? TypingPalette.statusHinted : TypingPalette.statusCorrected))
                                .frame(height: 6)
                                .frame(maxWidth: 32)
                                .help("Line \(line.sourceIndex + 1): \(isClean ? "Clean" : usedHint ? "Hint used" : "Needed correction")")
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            if viewModel.mode == .copy {
                levelUpCard(
                    icon: "arrow.up.circle.fill",
                    message: "Ready to test recall? Key lines will be hidden.",
                    buttonTitle: "Practice Key Lines (⌘2)",
                    id: "levelUpKeyLines"
                ) {
                    viewModel.setMode(.keyLines)
                }
            } else if viewModel.mode == .keyLines {
                levelUpCard(
                    icon: "brain.head.profile",
                    message: "Take the final step: Recall the full pattern.",
                    buttonTitle: "Practice Recall (⌘3)",
                    id: "levelUpRecall"
                ) {
                    viewModel.setMode(.recall)
                }
            }

            if let summary = viewModel.lastSummary, !summary.weakLines.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.badge.clock")
                        .foregroundColor(TypingPalette.statusCorrected)
                    Text("Struggled on \(summary.weakLines.count) lines.")
                        .font(.callout)
                    Spacer()
                    Button("Drill \(summary.weakLines.count) Shaky Lines (⌘R)") {
                        viewModel.drillShakyLines()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(TypingPalette.statusCorrected)
                    .accessibilityIdentifier("drillShakyLines")
                }
                .padding(10)
                .background(TypingPalette.statusCorrected.opacity(0.10))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(TypingPalette.statusCorrected.opacity(0.25), lineWidth: 1)
                )
            }
        }
    }

    private func ratingTint(for rating: SelfRating) -> Color {
        switch rating {
        case .forgot: TypingPalette.statusError
        case .shaky: TypingPalette.statusCorrected
        case .solid: .accentColor
        case .effortless: TypingPalette.statusClean
        }
    }

    private func levelUpCard(
        icon: String,
        message: String,
        buttonTitle: String,
        id: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(TypingPalette.statusClean)
            Text(message)
                .font(.callout)
            Spacer()
            Button(buttonTitle, action: action)
                .buttonStyle(.bordered)
                .accessibilityIdentifier(id)
        }
        .padding(10)
        .background(TypingPalette.statusClean.opacity(0.08))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(TypingPalette.statusClean.opacity(0.25), lineWidth: 1)
        )
    }

    private func isLineClean(_ line: PracticeLine) -> Bool {
        let attempt = viewModel.lineAttempts[line.sourceIndex]
        return (attempt?.hints ?? 0) == 0 && (attempt?.wrongSubmits ?? 0) == 0 && !(attempt?.repeated ?? false)
    }

    private var cleanLineCount: Int {
        viewModel.practiceLines.filter(isLineClean).count
    }

    private var cleanLineCountText: String {
        "\(cleanLineCount)/\(viewModel.practiceLines.count) clean"
    }
}
