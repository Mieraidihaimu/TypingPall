import Foundation

struct LessonAnchor: Codable, Hashable { let name: String; let trick: String }
struct LessonComplexity: Codable, Hashable { let time: String; let space: String }
struct LessonMutation: Codable, Hashable { let line: Int; let replacement: String; let explanation: String }

extension PracticeLesson {
    var sourceLines: [String] { code.components(separatedBy: "\n") }

    var searchableText: String { ([title, category, track.title, summary, language.title] + (triggers ?? [])).joined(separator: " ") }

    var practicedLineIndices: Set<Int> {
        let scaffold = Set(scaffoldLineIndices ?? [])
        return Set(CommentFilter.lines(sourceLines, language: language, skippingComments: true)
            .filter { !scaffold.contains($0.sourceIndex) && !$0.text.trimmingCharacters(in: .whitespaces).isEmpty }
            .map(\.sourceIndex))
    }

    func knownMistake(on line: Int, typed: String) -> LessonMutation? {
        let attempt = typed.trimmingCharacters(in: .whitespaces)
        return mutations?.first { $0.line == line && $0.replacement.trimmingCharacters(in: .whitespaces) == attempt }
    }
}

enum LessonValidator {
    /// Returns [] when every lesson is valid; otherwise one "id: field detail" entry per problem.
    static func problems(in lessons: [PracticeLesson]) -> [String] {
        let ids = Set(lessons.map(\.id))
        var problems = ids.count == lessons.count ? [] : ["catalog: duplicate lesson ids"]
        for lesson in lessons {
            func report(_ message: String) { problems.append("\(lesson.id): \(message)") }
            let lines = lesson.sourceLines, practiced = lesson.practicedLineIndices
            if (try? PracticeText.validated(lesson.code, tabSpaces: 4)) != lesson.code { report("code is not normalized") }
            if practiced.isEmpty { report("no practiced lines") }
            for index in lesson.keyLineIndices ?? [] where !practiced.contains(index) {
                report("keyLineIndices \(index) is not a practiced line")
            }
            for index in lesson.scaffoldLineIndices ?? [] where !lines.indices.contains(index) {
                report("scaffoldLineIndices \(index) is out of range")
            }
            for other in lesson.contrastWith ?? [] where other == lesson.id || !ids.contains(other) {
                report("contrastWith \(other) is not another lesson")
            }
            for mutation in lesson.mutations ?? [] {
                guard practiced.contains(mutation.line) else { report("mutation \(mutation.line) is not a practiced line"); continue }
                if mutation.replacement == lines[mutation.line] { report("mutation \(mutation.line) changes nothing") }
                if indentation(mutation.replacement) != indentation(lines[mutation.line]) {
                    report("mutation \(mutation.line) changes indentation")
                }
            }
            if lesson.prompts != nil && lesson.family == nil { report("prompts need a family") }
            for (field, texts) in textFields(of: lesson) where texts.isEmpty || texts.contains(where: isBlank) {
                report("\(field) is empty")
            }
        }
        return problems
    }

    private static func indentation(_ line: String) -> Substring { line.prefix { $0 == " " || $0 == "\t" } }
    private static func isBlank(_ text: String) -> Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private static func textFields(of lesson: PracticeLesson) -> [(String, [String])] {
        let fields: [(String, [String]?)] = [
            ("family", lesson.family.map { [$0] }), ("invariant", lesson.invariant.map { [$0] }), ("mantra", lesson.mantra.map { [$0] }),
            ("triggers", lesson.triggers), ("prompts", lesson.prompts), ("pitfalls", lesson.pitfalls), ("contrastWith", lesson.contrastWith),
            ("anchors", lesson.anchors?.flatMap { [$0.name, $0.trick] }), ("complexity", lesson.complexity.map { [$0.time, $0.space] }),
            ("mutations", lesson.mutations?.map(\.explanation)), ("keyLineIndices", lesson.keyLineIndices?.map(String.init)),
            ("scaffoldLineIndices", lesson.scaffoldLineIndices?.map(String.init)),
        ]
        return fields.compactMap { field, texts in texts.map { (field, $0) } }
    }
}
