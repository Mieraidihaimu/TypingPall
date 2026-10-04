import SwiftUI

/// The graded outcome and optional self-rating shown on the completion card; empty in Copy.
struct AttemptOutcomeView: View {
    @ObservedObject var viewModel: TypingScreenViewModel

    var body: some View {
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
    }
}
