import XCTest
@testable import TypingPall

final class BugHuntTests: XCTestCase {
    private let lesson = PracticeLesson(id: "b", title: "B", category: "C", track: .leetcode, language: .python, summary: "S",
                                        code: "def f(values):\n    left = 0\n    return left", family: "f", mutations: [
                                            LessonMutation(line: 1, replacement: "    left = 1", explanation: "Starts one too far."),
                                            LessonMutation(line: 2, replacement: "    return left + 1", explanation: "Off by one.")])

    func testNeedsAValidMutation() {
        XCTAssertNil(BugHunt(lesson: PracticeLesson(id: "x", title: "X", category: "C", track: .leetcode, language: .python, summary: "S", code: "x = 1"), mutationIndex: 0))
        XCTAssertNil(BugHunt(lesson: lesson, mutationIndex: 2))
    }

    func testShowsThePlantedBugAndKeepsTheOriginalLine() throws {
        let hunt = try XCTUnwrap(BugHunt(lesson: lesson, mutationIndex: 0))
        XCTAssertEqual(hunt.lines, ["def f(values):", "    left = 1", "    return left"])
        XCTAssertEqual(hunt.bugLine, 1)
        XCTAssertEqual(hunt.originalLine, "    left = 0")
        XCTAssertEqual(hunt.phase, .finding)
    }

    func testWrongRowsAreRememberedOnceAndTheRightRowStartsFixing() throws {
        var hunt = try XCTUnwrap(BugHunt(lesson: lesson, mutationIndex: 0))
        XCTAssertFalse(hunt.select(line: 2))
        XCTAssertFalse(hunt.select(line: 2))
        XCTAssertEqual(hunt.wrongGuesses, [2])
        XCTAssertTrue(hunt.select(line: 1))
        XCTAssertEqual(hunt.phase, .fixing)
        XCTAssertFalse(hunt.select(line: 0), "Selection locks once the bug is found")
        hunt.markSolved()
        XCTAssertEqual(hunt.phase, .solved)
    }
}

final class BugHuntPracticeTests: XCTestCase {
    func testHuntShowsTheBugThenPracticesOnlyTheFix() throws {
        let name = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = TypingScreenViewModel(defaults: defaults)
        let lesson = PracticeLesson(id: "b", title: "B", category: "C", track: .leetcode, language: .python, summary: "S",
                                    code: "def f(values):\n    left = 0\n    return left", family: "f",
                                    mutations: [LessonMutation(line: 1, replacement: "    left = 1", explanation: "Starts one too far.")])
        try model.startBugHunt(lesson, mutationIndex: 0)
        XCTAssertEqual(model.lines[1], "    left = 1")
        XCTAssertFalse(model.hasPracticeLines)
        model.selectReferenceLine(2)
        XCTAssertEqual(model.bugHunt?.wrongGuesses, [2])
        XCTAssertEqual(model.referenceRows.map(\.marker), [nil, nil, .notTheBug])
        model.selectReferenceLine(1)
        XCTAssertEqual(model.practiceLines, [PracticeLine(sourceIndex: 1, text: "    left = 0")])
        XCTAssertEqual(model.referenceRows[1].marker, .plantedBug)
        XCTAssertFalse(model.referenceRows.contains(where: \.isMasked), "The planted version stays readable")
        model.editorText = "left = 0"
        XCTAssertTrue(model.advanceLine())
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.bugHunt?.phase, .solved)
        try model.loadLesson(lesson)
        XCTAssertNil(model.bugHunt, "Any other load ends the hunt")
        XCTAssertEqual(model.lines[1], "    left = 0")
        XCTAssertEqual(model.mode, .copy, "The learner's mode comes back")
    }
}

final class ContrastPairTests: XCTestCase {
    private let lower = "# Exclude mid only when its value is too small.\ndef lower_bound(values, target):\n    left, right = 0, len(values)\n    while left < right:\n        mid = left + (right - left) // 2\n        if values[mid] < target:\n            left = mid + 1\n        else:\n            right = mid\n    return left"
    private var upper: String {
        lower.replacingOccurrences(of: "too small", with: "at most target").replacingOccurrences(of: "lower_bound", with: "upper_bound")
            .replacingOccurrences(of: "values[mid] < target", with: "values[mid] <= target")
    }
    private func lesson(_ id: String, _ code: String, _ language: CodeLanguage = .python) -> PracticeLesson {
        PracticeLesson(id: id, title: id, category: "C", track: .leetcode, language: language, summary: "S", code: code, family: "binary-search")
    }

    func testUnmatchedLinesFollowALineLCS() {
        XCTAssertEqual(ContrastPair.unmatchedLines(of: ["a", "b", "c", "d"], against: ["a", "x", "c", "d"]), [1])
        XCTAssertEqual(ContrastPair.unmatchedLines(of: ["a", "b", "c"], against: ["a", "c"]), [1])
        XCTAssertEqual(ContrastPair.unmatchedLines(of: ["a", "c"], against: ["a", "b", "c"]), [])
    }

    func testVariantHidesOnlyItsDifferingTypedLines() throws {
        let pair = try XCTUnwrap(ContrastPair(base: lesson("lower", lower), variant: lesson("upper", upper)))
        XCTAssertEqual(pair.differingLines, [1, 5], "The comment differs too, but it isn't typed")
        XCTAssertEqual(pair.baseMarkedLines, [0, 1, 5])
    }

    func testPairsNeedTheSameLanguageAndALimitedDifference() {
        XCTAssertNil(ContrastPair(base: lesson("lower", lower), variant: lesson("same", lower)))
        XCTAssertNil(ContrastPair(base: lesson("lower", lower), variant: lesson("cpp", upper, .cpp)))
        XCTAssertNil(ContrastPair(base: lesson("lower", lower), variant: lesson("other", "def f(x):\n    return x * 2")))
    }

    func testContrastPracticeTypesOnlyTheDifferingLines() throws {
        let name = UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = TypingScreenViewModel(defaults: defaults)
        let pair = try XCTUnwrap(ContrastPair(base: lesson("lower", lower), variant: lesson("upper", upper)))
        try model.startContrast(pair)
        XCTAssertEqual(model.contrast?.base.id, "lower")
        XCTAssertEqual(model.mode, .keyLines)
        XCTAssertEqual(Set(model.practiceLines.map(\.sourceIndex)), [1, 5])
        XCTAssertEqual(model.contrastBaseRows.count, 10)
        XCTAssertEqual(Set(model.contrastBaseRows.filter { $0.marker == .differs }.map(\.sourceIndex)), [0, 1, 5])
        try model.loadLesson(lesson("lower", lower))
        XCTAssertNil(model.contrast)
        XCTAssertEqual(model.mode, .copy, "The learner's mode comes back")
    }

    func testBundledLowerAndUpperBoundFormAPair() throws {
        let lower = try XCTUnwrap(PracticeCatalog.lessons.first { $0.id == "py-binary-search" })
        let pair = try XCTUnwrap(ContrastPair.pairs(for: lower).first { $0.variant.id == "py-upper-bound" })
        XCTAssertEqual(pair.differingLines, [1, 5])
    }
}
