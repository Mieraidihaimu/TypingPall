import Foundation

struct RecognitionDrill {
    struct Question: Equatable {
        let lessonID: String
        let prompt: String
        let options: [String]
    }

    /// SplitMix64, so a seed reproduces a round.
    struct Generator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            return value ^ (value >> 31)
        }
    }

    static let optionCount = 4
    let questions: [Question]
    private(set) var position = 0
    private(set) var choices: [String] = []

    init(lessons: [PracticeLesson], seed: UInt64, length: Int = 8) {
        var generator = Generator(seed: seed)
        let candidates = lessons.filter { $0.family != nil }
        let askable = candidates.filter { !($0.prompts ?? []).isEmpty }
        var questions: [Question] = [], asked = Set<String>(), usedPrompts = Set<String>(), previousFamily: String?
        while questions.count < length {
            let allowed = askable.filter { $0.family != previousFamily }
            let fresh = allowed.filter { !asked.contains($0.id) }
            guard let lesson = (fresh.isEmpty ? allowed : fresh).randomElement(using: &generator),
                  let prompts = lesson.prompts else { break }
            let unused = prompts.filter { !usedPrompts.contains($0) }
            guard let prompt = (unused.isEmpty ? prompts : unused).randomElement(using: &generator) else { break }
            let options = Self.options(for: lesson, from: candidates, using: &generator)
            questions.append(Question(lessonID: lesson.id, prompt: prompt, options: options))
            asked.insert(lesson.id)
            usedPrompts.insert(prompt)
            previousFamily = lesson.family
        }
        self.questions = questions
    }

    // From the answer's track: contrast lessons first, then same-family variants, then one lesson per other family.
    private static func options(for lesson: PracticeLesson, from candidates: [PracticeLesson],
                                using generator: inout Generator) -> [String] {
        let others = candidates.filter { $0.id != lesson.id && $0.track == lesson.track }
        let contrast = Set(lesson.contrastWith ?? [])
        var picked = others.filter { contrast.contains($0.id) }.shuffled(using: &generator)
        picked += others.filter { !contrast.contains($0.id) && $0.family == lesson.family }.shuffled(using: &generator)
        var families = Set(picked.map { $0.family ?? $0.id }).union([lesson.family ?? lesson.id])
        for other in others.shuffled(using: &generator) where !families.contains(other.family ?? other.id) {
            picked.append(other)
            families.insert(other.family ?? other.id)
        }
        return ([lesson.id] + picked.prefix(optionCount - 1).map(\.id)).shuffled(using: &generator)
    }

    var current: Question? { questions.indices.contains(position) ? questions[position] : nil }
    var currentChoice: String? { choices.indices.contains(position) ? choices[position] : nil }
    var isFinished: Bool { position >= questions.count }
    var recognizedCount: Int { zip(questions, choices).filter { $0.lessonID == $1 }.count }
    var missedLessonIDs: [String] {
        zip(questions, choices).filter { $0.lessonID != $1 }.map { $0.0.lessonID }
            .reduce(into: []) { result, id in if !result.contains(id) { result.append(id) } }
    }

    mutating func choose(_ lessonID: String) {
        guard let current, currentChoice == nil, current.options.contains(lessonID) else { return }
        choices.append(lessonID)
    }

    mutating func advance() { if currentChoice != nil { position += 1 } }
}
