import XCTest
@testable import TypingPall

private func fixture(_ id: String, family: String?, prompts: Bool = true, contrast: [String]? = nil,
                     track: LessonTrack = .leetcode) -> PracticeLesson {
    PracticeLesson(id: id, title: id, category: "C", track: track, language: .python, summary: "S", code: "x = 1", family: family,
                   prompts: prompts ? ["\(id) scenario one", "\(id) scenario two"] : nil, contrastWith: contrast)
}

final class RecognitionDrillTests: XCTestCase {
    private let lessons = [
        fixture("lower", family: "binary-search", contrast: ["upper", "answer"]), fixture("upper", family: "binary-search", contrast: ["lower"]),
        fixture("answer", family: "binary-search", contrast: ["lower"]), fixture("window", family: "sliding-window", contrast: ["pair"]),
        fixture("pair", family: "two-pointers", contrast: ["window"]), fixture("bfs", family: "bfs"), fixture("dfs", family: "dfs"),
        fixture("notesOnly", family: "dfs", prompts: false), fixture("fundamentals", family: nil, prompts: false),
    ]
    private func family(_ id: String) -> String? { lessons.first { $0.id == id }?.family }

    func testSameSeedSameRoundAndSeedsVary() {
        XCTAssertEqual(RecognitionDrill(lessons: lessons, seed: 7).questions, RecognitionDrill(lessons: lessons, seed: 7).questions)
        var rounds = Set<[String]>()
        for seed: UInt64 in 0..<20 { rounds.insert(RecognitionDrill(lessons: lessons, seed: seed).questions.map(\.lessonID)) }
        XCTAssertGreaterThan(rounds.count, 1)
    }

    func testFourDistinctPatternOptionsIncludingTheAnswer() {
        for seed: UInt64 in 0..<50 {
            let drill = RecognitionDrill(lessons: lessons, seed: seed)
            XCTAssertEqual(drill.questions.count, 8)
            for question in drill.questions {
                XCTAssertEqual(Set(question.options).count, RecognitionDrill.optionCount)
                XCTAssertTrue(question.options.contains(question.lessonID))
                XCTAssertFalse(question.options.contains("fundamentals"))
                XCTAssertNotEqual(question.lessonID, "notesOnly")
                XCTAssertTrue(question.prompt.hasPrefix(question.lessonID + " scenario"))
            }
        }
    }

    func testContrastLessonsAreAlwaysOffered() {
        for seed: UInt64 in 0..<50 {
            for question in RecognitionDrill(lessons: lessons, seed: seed).questions where question.lessonID == "lower" {
                XCTAssertTrue(Set(question.options).isSuperset(of: ["upper", "answer"]))
            }
        }
    }

    func testOptionsComeFromTheAnswersTrack() {
        let design = ["strategy", "state", "observer", "factory"].map { fixture($0, family: $0, track: .lowLevelDesign) }
        let pool = lessons + design
        for seed: UInt64 in 0..<50 {
            for question in RecognitionDrill(lessons: pool, seed: seed).questions {
                let tracks = Set(question.options.compactMap { id in pool.first { $0.id == id }?.track })
                XCTAssertEqual(tracks.count, 1, question.prompt)
                XCTAssertEqual(question.options.count, RecognitionDrill.optionCount)
            }
        }
    }

    func testNeverTheSamePatternTwiceInARow() {
        for seed: UInt64 in 0..<50 {
            let ids = RecognitionDrill(lessons: lessons, seed: seed).questions.map(\.lessonID)
            for (first, second) in zip(ids, ids.dropFirst()) { XCTAssertNotEqual(family(first), family(second)) }
        }
    }

    func testChoosingAdvancingAndRoundSummary() throws {
        var drill = RecognitionDrill(lessons: lessons, seed: 3, length: 2)
        let first = try XCTUnwrap(drill.current)
        let wrong = try XCTUnwrap(first.options.first { $0 != first.lessonID })
        drill.choose(wrong)
        drill.choose(first.lessonID)
        XCTAssertEqual(drill.currentChoice, wrong, "The first choice sticks")
        drill.advance()
        let second = try XCTUnwrap(drill.current)
        drill.advance()
        XCTAssertEqual(drill.current, second, "Can't skip without answering")
        drill.choose(second.lessonID)
        drill.advance()
        XCTAssertTrue(drill.isFinished)
        XCTAssertEqual(drill.recognizedCount, 1)
        XCTAssertEqual(drill.missedLessonIDs, [first.lessonID])
    }

    func testSmallPoolsDegradeGracefully() {
        let two = [fixture("lower", family: "binary-search"), fixture("window", family: "sliding-window")]
        XCTAssertEqual(RecognitionDrill(lessons: two, seed: 1).questions.map(\.options.count), Array(repeating: 2, count: 8))
        XCTAssertEqual(RecognitionDrill(lessons: [fixture("lower", family: "binary-search")], seed: 1).questions.count, 1)
        XCTAssertTrue(RecognitionDrill(lessons: [], seed: 1).questions.isEmpty)
    }

    func testBundledCatalogSupportsAFullRound() {
        let drill = RecognitionDrill(lessons: PracticeCatalog.lessons, seed: 42)
        XCTAssertEqual(drill.questions.count, 8)
        XCTAssertTrue(drill.questions.allSatisfy { $0.options.count == RecognitionDrill.optionCount })
    }
}
