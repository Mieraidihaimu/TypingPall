import SwiftUI

struct BugHuntBanner: View {
    let hunt: BugHunt

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: "ladybug")
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
        .background(Color.accentColor.opacity(0.08))
        .cornerRadius(8)
    }
}
