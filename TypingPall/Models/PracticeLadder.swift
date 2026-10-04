import Foundation

enum PracticeMode: Int, CaseIterable, Identifiable, Comparable {
    case copy, keyLines, recall
    var id: Int { rawValue }
    var title: String { ["Copy", "Key lines", "Recall"][rawValue] }
    var isGraded: Bool { self != .copy }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum CodeTokens {
    /// A token is a maximal run of word characters (letters, digits, "_") or of other non-space characters.
    static func ranges(in text: String) -> [Range<Int>] {
        var ranges: [Range<Int>] = [], start = 0, previous: Bool? = nil   // nil = whitespace
        for (offset, character) in text.enumerated() {
            let kind: Bool? = character.isWhitespace ? nil : character.isLetter || character.isNumber || character == "_"
            if kind != previous {
                if previous != nil { ranges.append(start..<offset) }
                start = offset
            }
            previous = kind
        }
        if previous != nil { ranges.append(start..<text.count) }
        return ranges
    }

    static func revealEnd(in target: String, from offset: Int) -> Int {
        ranges(in: target).first { $0.upperBound > offset }?.upperBound ?? target.count
    }
}

enum MaskedLine {
    static let hidden: Character = "━"

    static func placeholder(source: String, typed: String, revealed: Int = 0) -> String {
        let indentation = source.prefix { $0 == " " || $0 == "\t" }
        let content = source.dropFirst(indentation.count)
        let trailing = content.hasPrefix(typed) ? content.dropFirst(typed.count) : ""   // a stripped trailing comment stays visible
        let shown = min(max(revealed, 0), typed.count)
        return String(indentation) + typed.prefix(shown) + String(repeating: hidden, count: typed.count - shown) + trailing
    }
}

enum PracticeLineSelection {
    static func lines(for mode: PracticeMode, from code: [PracticeLine], keyLines: [Int], weakLines: Set<Int>) -> [PracticeLine] {
        guard mode.isGraded else { return code }
        let typed = code.filter { !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
        let body = typed.count > 1 ? Array(typed.dropFirst()) : typed
        if mode == .recall { return body }
        let keys = Set(keyLines), chosen = typed.filter { keys.contains($0.sourceIndex) }
        if !chosen.isEmpty { return chosen }
        let weak = body.filter { weakLines.contains($0.sourceIndex) }
        return weak.isEmpty ? evenlySpaced(body) : weak
    }

    static func evenlySpaced<T>(_ items: [T]) -> [T] {
        guard !items.isEmpty else { return [] }
        let count = max(1, (items.count + 1) / 3)
        return (0..<count).map { items[(2 * $0 + 1) * items.count / (2 * count)] }
    }
}

enum ReviewGrade: Int, CaseIterable, Comparable {
    case again = 1, hard, good, easy
    var title: String { ["Forgot", "Shaky", "Solid", "Effortless"][rawValue - 1] }
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum SelfRating: Int, CaseIterable, Identifiable {
    case forgot = 1, shaky, solid, effortless
    var id: Int { rawValue }
    var grade: ReviewGrade { ReviewGrade(rawValue: rawValue) ?? .good }
    var title: String { grade.title }
}

struct LineAttempt: Equatable {
    var wrongSubmits = 0, hints = 0
    var repeated = false, revealed = false
    var isClean: Bool { wrongSubmits == 0 && hints == 0 && !repeated && !revealed }
}

struct AttemptSummary: Equatable {
    let mode: PracticeMode
    let lines: [Int: LineAttempt]
    var cleanLines: Set<Int> { Set(lines.filter { $0.value.isClean }.keys) }
    var weakLines: Set<Int> { Set(lines.keys).subtracting(cleanLines) }
    var hints: Int { lines.values.map(\.hints).reduce(0, +) }
    var wrongSubmits: Int { lines.values.map(\.wrongSubmits).reduce(0, +) }
    func grade(_ rating: SelfRating? = nil) -> ReviewGrade? { mode.isGraded ? PatternGrader.grade(Array(lines.values), selfRating: rating) : nil }
}

/// Grades come from per-line stats only; time is never an input.
enum PatternGrader {
    static func grade(_ lines: [LineAttempt], selfRating: SelfRating? = nil) -> ReviewGrade? {
        guard !lines.isEmpty else { return nil }
        let revealed = lines.filter(\.revealed).count, unclean = lines.filter { !$0.isClean }.count
        let objective: ReviewGrade = revealed > 0 && revealed * 4 >= lines.count ? .again : revealed > 0 || unclean > 1 ? .hard : .good
        switch selfRating {
        case nil: return objective
        case .effortless?: return objective == .good && unclean == 0 ? .easy : objective
        case let rating?: return min(objective, rating.grade)
        }
    }
}

/// Locates a wrong submission without giving the answer away.
enum SubmitFeedback {
    static func message(typed: String, target: String, explanation: String? = nil) -> String {
        let mismatch = LineDiff(typed: typed, target: target).firstMismatch ?? typed.count
        let base = typed.isEmpty ? "Type the line from memory, or ask for a hint (⌘')."
            : mismatch >= typed.count ? "So far so good. The line continues."
            : mismatch >= target.count ? "The line ends after character \(target.count)."
            : "Not quite: the first difference is at character \(mismatch + 1)."
        return explanation.map { base + " " + $0 } ?? base
    }
}
