import Foundation

/// Shows a lesson with one planted bug; the learner finds the line, then types the fix.
struct BugHunt: Equatable {
    enum Phase: Equatable { case finding, fixing, solved }

    let lessonID: String
    let mutation: LessonMutation
    let lines: [String]
    let originalLine: String
    private(set) var phase = Phase.finding
    private(set) var wrongGuesses: [Int] = []
    var bugLine: Int { mutation.line }

    init?(lesson: PracticeLesson, mutationIndex: Int) {
        guard let mutations = lesson.mutations, mutations.indices.contains(mutationIndex) else { return nil }
        var lines = lesson.sourceLines
        let mutation = mutations[mutationIndex]
        guard lines.indices.contains(mutation.line) else { return nil }
        originalLine = lines[mutation.line]
        lines[mutation.line] = mutation.replacement
        lessonID = lesson.id
        self.mutation = mutation
        self.lines = lines
    }

    @discardableResult
    mutating func select(line: Int) -> Bool {
        guard phase == .finding else { return false }
        guard line == mutation.line else {
            if !wrongGuesses.contains(line) { wrongGuesses.append(line) }
            return false
        }
        phase = .fixing
        return true
    }

    mutating func markSolved() { if phase == .fixing { phase = .solved } }
}
