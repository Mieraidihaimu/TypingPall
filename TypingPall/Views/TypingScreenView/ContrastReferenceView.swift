import SwiftUI

/// The base lesson beside the variant being practiced; the columns stack when the window is narrow.
struct ContrastReferenceView: View {
    let baseTitle: String
    let baseRows: [ReferenceRow]
    let variantTitle: String
    let variantRows: [ReferenceRow]
    let fontSize: Double
    let currentIndex: Int
    let contentKey: String

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width < 900 {
                VStack(spacing: 12) { base(minHeight: 90); variant(minHeight: 90) }
            } else {
                HStack(spacing: 12) { base(minHeight: 180); variant(minHeight: 180) }
            }
        }
        .frame(minHeight: 240)
    }

    private func base(minHeight: CGFloat) -> some View {
        column(baseTitle, identifier: "contrastBase") {
            ReferenceCodeView(rows: baseRows, fontSize: fontSize, currentIndex: 0, contentKey: contentKey, minHeight: minHeight)
        }
    }

    private func variant(minHeight: CGFloat) -> some View {
        column(variantTitle, identifier: "contrastVariant") {
            ReferenceCodeView(rows: variantRows, fontSize: fontSize, currentIndex: currentIndex, contentKey: contentKey, minHeight: minHeight)
        }
    }

    private func column<Content: View>(_ title: String, identifier: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
            content()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}
