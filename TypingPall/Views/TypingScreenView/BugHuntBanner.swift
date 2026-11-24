import SwiftUI

struct BugHuntBanner: View {
    let hunt: BugHunt

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "ladybug")
                .foregroundColor(TypingPalette.statusError)
            Text(hunt.phase == .finding ? "Find the planted bug: click the line that's wrong." : "Type the corrected line, then press Return.")
            Spacer()
            if hunt.phase == .finding && !hunt.wrongGuesses.isEmpty {
                Text("^[\(hunt.wrongGuesses.count) line](inflect: true) checked")
                    .foregroundColor(.secondary)
                    .accessibilityIdentifier("bugHuntStatus")
            }
        }
        .font(.callout)
        .padding(10)
        .background(TypingPalette.statusError.opacity(0.09))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(TypingPalette.statusError.opacity(0.25), lineWidth: 1))
    }
}
