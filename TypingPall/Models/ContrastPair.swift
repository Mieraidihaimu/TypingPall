import Foundation

/// A variant lesson set against its base, so only the lines that differ are hidden and typed.
struct ContrastPair: Equatable {
    let base: PracticeLesson
    let variant: PracticeLesson
    let differingLines: Set<Int>    // variant lines hidden and typed
    let baseMarkedLines: Set<Int>   // base lines marked as different

    init?(base: PracticeLesson, variant: PracticeLesson) {
        guard base.id != variant.id, base.language == variant.language else { return nil }
        let practiced = variant.practicedLineIndices
        let differing = Self.unmatchedLines(of: variant.sourceLines, against: base.sourceLines).intersection(practiced)
        guard !differing.isEmpty, differing.count * 2 <= practiced.count else { return nil }
        self.base = base
        self.variant = variant
        differingLines = differing
        baseMarkedLines = Self.unmatchedLines(of: base.sourceLines, against: variant.sourceLines)
    }

    /// Indices of `variant` lines left out of a longest common subsequence with `base`.
    static func unmatchedLines(of variant: [String], against base: [String]) -> Set<Int> {
        var table = Array(repeating: Array(repeating: 0, count: base.count + 1), count: variant.count + 1)
        for i in stride(from: variant.count - 1, through: 0, by: -1) {
            for j in stride(from: base.count - 1, through: 0, by: -1) {
                table[i][j] = variant[i] == base[j] ? table[i + 1][j + 1] + 1 : max(table[i + 1][j], table[i][j + 1])
            }
        }
        var unmatched = Set<Int>(), i = 0, j = 0
        while i < variant.count {
            if j < base.count && variant[i] == base[j] {
                i += 1
                j += 1
            } else if j < base.count && table[i][j + 1] >= table[i + 1][j] {
                j += 1
            } else {
                unmatched.insert(i)
                i += 1
            }
        }
        return unmatched
    }

    /// Valid pairs with the lessons `lesson` lists in `contrastWith`.
    static func pairs(for lesson: PracticeLesson, in catalog: [PracticeLesson] = PracticeCatalog.lessons) -> [ContrastPair] {
        (lesson.contrastWith ?? []).compactMap { id in catalog.first { $0.id == id }.flatMap { ContrastPair(base: lesson, variant: $0) } }
    }
}
