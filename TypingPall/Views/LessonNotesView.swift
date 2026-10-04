import SwiftUI

struct LessonNotesView: View {
    let lesson: PracticeLesson
    var onContrast: ((ContrastPair) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section("Core pattern", lesson.invariant.map { [$0] }, footnote: lesson.complexity.map { "\($0.time) time · \($0.space) space" })
            section("Problem anchors", lesson.anchors?.map { "\($0.name) — \($0.trick)" })
            section("Retrieval triggers", lesson.triggers)
            VStack(alignment: .leading, spacing: 4) {
                if hasNotes { heading("Template") }
                Text(lesson.code).font(.system(.body, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading)
            }
            section("Decision rules", (lesson.pitfalls ?? []) + confusedWith)
            if let onContrast {
                let pairs = ContrastPair.pairs(for: lesson)
                if !pairs.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(pairs, id: \.variant.id) { pair in
                            Button("Contrast with \(pair.variant.title)") { onContrast(pair) }
                                .accessibilityIdentifier("contrast-\(pair.variant.id)")
                        }
                    }
                }
            }
            if let mantra = lesson.mantra {
                VStack(alignment: .leading, spacing: 4) {
                    heading("Mantra")
                    Text(mantra).font(.headline).accessibilityIdentifier("lessonMantra")
                }
            }
        }
        .textSelection(.enabled)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lessonNotes")
    }

    private var hasNotes: Bool { lesson.invariant != nil || lesson.triggers != nil || lesson.mantra != nil }
    private var confusedWith: [String] {
        let titles = (lesson.contrastWith ?? []).compactMap { id in PracticeCatalog.lessons.first { $0.id == id }?.title }
        return titles.isEmpty ? [] : ["Often confused with: " + titles.joined(separator: ", ")]
    }

    private func heading(_ title: String) -> some View {
        Text(title.uppercased()).font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
    }

    @ViewBuilder private func section(_ title: String, _ items: [String]?, footnote: String? = nil) -> some View {
        if let items, !items.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                heading(title)
                ForEach(items, id: \.self) { Text("• \($0)").fixedSize(horizontal: false, vertical: true) }
                if let footnote { Text(footnote).foregroundColor(.secondary) }
            }
        }
    }
}
