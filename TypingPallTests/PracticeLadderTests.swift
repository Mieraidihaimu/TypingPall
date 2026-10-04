import XCTest
import AppKit
import SwiftUI
@testable import TypingPall

final class PracticeLadderTests: XCTestCase {
    private func tokens(_ text: String) -> [String] { CodeTokens.ranges(in: text).map { String(Array(text)[$0]) } }

    func testTokensAreWordRunsOrSymbolRuns() {
        XCTAssertEqual(tokens("left = max(left, last_seen[char] + 1)"),
                       ["left", "=", "max", "(", "left", ",", "last_seen", "[", "char", "]", "+", "1", ")"])
        XCTAssertEqual(tokens("x+=1;  }):"), ["x", "+=", "1", ";", "}):"])
        XCTAssertEqual(tokens("  🙂 = é_2"), ["🙂", "=", "é_2"])
        XCTAssertEqual(tokens(" "), [])
    }

    func testHintRevealsThroughTheNextToken() {
        let line = "left = max(left, last_seen[char] + 1)"
        XCTAssertEqual([0, 4, 10, 12, 37].map { CodeTokens.revealEnd(in: line, from: $0) }, [4, 6, 11, 15, 37])
    }

    func testMaskedLinesKeepIndentationRevealedTextAndTrailingComments() {
        XCTAssertEqual(MaskedLine.placeholder(source: "    left = 0", typed: "left = 0"), "    ━━━━━━━━")
        XCTAssertEqual(MaskedLine.placeholder(source: "    left = 0", typed: "left = 0", revealed: 4), "    left━━━━")
        XCTAssertEqual(MaskedLine.placeholder(source: "  a = 1  # note", typed: "a = 1"), "  ━━━━━  # note")
        XCTAssertEqual(MaskedLine.placeholder(source: "a/* x */+b", typed: "a +b"), "━━━━")
        XCTAssertEqual(MaskedLine.placeholder(source: "x", typed: "x", revealed: 9), "x")
    }

    func testTypedLinesPerMode() {
        let code = ["def f(values):", "    a = 1", "", "    b = 2", "    c = 3", "    return a"]
            .enumerated().map { PracticeLine(sourceIndex: $0.offset + 1, text: $0.element) }
        func pick(_ mode: PracticeMode, keys: [Int] = [], weak: Set<Int> = []) -> [Int] {
            PracticeLineSelection.lines(for: mode, from: code, keyLines: keys, weakLines: weak).map(\.sourceIndex)
        }
        XCTAssertEqual(pick(.copy), [1, 2, 3, 4, 5, 6])
        XCTAssertEqual(pick(.recall), [2, 4, 5, 6], "The signature and blank lines stay visible")
        XCTAssertEqual(pick(.keyLines, keys: [5, 9], weak: [2]), [5])
        XCTAssertEqual(pick(.keyLines, weak: [6, 1]), [6], "No key lines: this session's weak lines")
        XCTAssertEqual(pick(.keyLines), [5], "Otherwise an evenly spaced third")
        XCTAssertEqual(PracticeLineSelection.evenlySpaced(Array(0..<9)), [1, 4, 7])
        XCTAssertEqual(PracticeLineSelection.evenlySpaced(Array(0..<10)), [1, 5, 8])
        XCTAssertEqual(PracticeLineSelection.evenlySpaced([7]), [7])
    }

    func testGradeTable() {
        let clean = LineAttempt(), slip = LineAttempt(wrongSubmits: 1), hinted = LineAttempt(hints: 1)
        let shown = LineAttempt(hints: 3, revealed: true)
        let cases: [([LineAttempt], SelfRating?, ReviewGrade?)] = [
            ([], nil, nil),
            ([clean, clean, clean, clean], nil, .good), ([clean, clean, clean, clean], .effortless, .easy),
            ([slip, clean, clean, clean], nil, .good), ([slip, clean, clean, clean], .effortless, .good),
            ([slip, hinted, clean, clean], nil, .hard), ([shown, clean, clean, clean, clean], nil, .hard),
            ([shown, clean, clean, clean], nil, .again), ([clean, clean], .shaky, .hard), ([clean, clean], .forgot, .again),
            ([slip, hinted, clean], .effortless, .hard), ([shown, clean, clean, clean], .solid, .again),
        ]
        for (lines, rating, expected) in cases {
            XCTAssertEqual(PatternGrader.grade(lines, selfRating: rating), expected, "\(lines) \(String(describing: rating))")
        }
    }

    func testSummaryCountsLinesAndGradesOnlyGradedModes() {
        let lines = [3: LineAttempt(), 5: LineAttempt(wrongSubmits: 2), 7: LineAttempt(hints: 1)]
        let summary = AttemptSummary(mode: .recall, lines: lines)
        XCTAssertEqual(summary.cleanLines, [3]); XCTAssertEqual(summary.weakLines, [5, 7])
        XCTAssertEqual(summary.hints, 1); XCTAssertEqual(summary.wrongSubmits, 2)
        XCTAssertEqual(summary.grade(), .hard)
        XCTAssertNil(AttemptSummary(mode: .copy, lines: lines).grade())
    }

    func testSubmitFeedbackLocatesTheDifferenceWithoutGivingItAway() {
        XCTAssertEqual(SubmitFeedback.message(typed: "left = min(", target: "left = max(left, 0)"), "Not quite: the first difference is at character 9.")
        XCTAssertEqual(SubmitFeedback.message(typed: "left = ", target: "left = 0"), "So far so good. The line continues.")
        XCTAssertEqual(SubmitFeedback.message(typed: "left = 00", target: "left = 0"), "The line ends after character 8.")
        XCTAssertEqual(SubmitFeedback.message(typed: "x = 2", target: "x = 1", explanation: "Off by one."),
                       "Not quite: the first difference is at character 5. Off by one.")
    }
}

private func freshModel(for test: XCTestCase) throws -> TypingScreenViewModel {
    let name = UUID().uuidString
    test.addTeardownBlock { UserDefaults().removePersistentDomain(forName: name) }
    return TypingScreenViewModel(defaults: try XCTUnwrap(UserDefaults(suiteName: name)))
}

private let windowLesson = PracticeLesson(id: "w", title: "W", category: "C", track: .leetcode, language: .python, summary: "Move left past a repeat.",
    code: "# Keep a window.\ndef f(text):\n    seen = {}\n    left = 0\n    for right, char in enumerate(text):\n        left = max(left, seen.get(char, -1) + 1)\n        seen[char] = right\n    return left",
    invariant: "text[left:right + 1] has no repeat.", keyLineIndices: [5, 6],
    mutations: [LessonMutation(line: 5, replacement: "        left = seen.get(char, -1) + 1", explanation: "Without max(), left can move backwards.")])

final class PracticeModeTests: XCTestCase {
    func testModesChooseTypedLinesAndMaskOnlyUnfinishedOnes() throws {
        let model = try freshModel(for: self)
        try model.loadLesson(windowLesson)
        XCTAssertEqual(model.mode, .copy); XCTAssertEqual(model.maskedLineIndices, [])
        model.setMode(.keyLines)
        XCTAssertEqual(model.practiceLines.map(\.sourceIndex), [5, 6]); XCTAssertEqual(model.maskedLineIndices, [5, 6])
        let row = try XCTUnwrap(model.referenceRows.first { $0.sourceIndex == 5 })
        XCTAssertTrue(row.isMasked); XCTAssertFalse(row.text.contains("max"), "Hidden text never reaches the view")
        XCTAssertEqual(model.displayedSummary, "text[left:right + 1] has no repeat.")
        model.editorText = "left = max(left, seen.get(char, -1) + 1)"
        XCTAssertTrue(model.advanceLine())
        XCTAssertEqual(model.maskedLineIndices, [6], "Finished lines reappear")
        model.setMode(.recall)
        XCTAssertEqual(model.practiceLines.map(\.sourceIndex), [2, 3, 4, 5, 6, 7]); XCTAssertEqual(model.completedLineCount, 0)
        model.setSkipComments(false)
        XCTAssertEqual(model.practiceLines.map(\.sourceIndex), [2, 3, 4, 5, 6, 7], "Comments are cues, never typed")
        model.setMode(.copy)
        XCTAssertEqual(model.practiceLines.map(\.sourceIndex), Array(0...7)); XCTAssertEqual(model.displayedSummary, "Move left past a repeat.")
    }

    func testScriptsWithoutKeyLinesUseAnEvenlySpacedThird() throws {
        let model = try freshModel(for: self)
        try model.updatePlaceholder(with: "a\nb\nc\nd\ne\nf\ng")
        model.setMode(.keyLines)
        XCTAssertEqual(model.practiceLines.map(\.sourceIndex), [2, 5])
    }

    func testGradedModesCheckOnReturnAndCountWrongSubmits() throws {
        let model = try freshModel(for: self)
        try model.loadLesson(windowLesson)
        model.setMode(.keyLines)
        model.editorText = "left = seen.get(char, -1) + 1"
        XCTAssertFalse(model.advanceLine())
        XCTAssertEqual(model.editorText, "left = seen.get(char, -1) + 1", "The learner fixes the line")
        XCTAssertEqual(model.learningStatus, "Not quite: the first difference is at character 8. Without max(), left can move backwards.")
        model.editorText = ""
        XCTAssertFalse(model.advanceLine())
        XCTAssertEqual(model.lineAttempts[5], LineAttempt(wrongSubmits: 1), "An empty Return is not an attempt")
        model.editorText = "left = max(left, seen.get(char, -1) + 1)"
        XCTAssertTrue(model.advanceLine())
        model.editorText = "seen[char] = rig"
        model.repeatLine()
        XCTAssertEqual(model.lineAttempts[6], LineAttempt(repeated: true))
    }

    func testHintsRevealATokenAtATimeAndTheThirdRevealsTheLine() throws {
        let model = try freshModel(for: self)
        try model.loadLesson(windowLesson)
        model.setMode(.recall)                                       // first typed line: "seen = {}"
        XCTAssertEqual(model.visibleTarget, "━━━━━━━━━")
        model.revealHint()
        XCTAssertEqual(model.visibleTarget, "seen━━━━━")
        model.editorText = "seen"
        model.revealHint()
        XCTAssertEqual(model.visibleTarget, "seen =━━━"); XCTAssertEqual(model.lineAttempts[2], LineAttempt(hints: 2))
        model.revealHint()
        XCTAssertEqual(model.visibleTarget, "seen = {}"); XCTAssertEqual(model.lineAttempts[2], LineAttempt(hints: 3, revealed: true))
        model.editorText = "seen = {}"
        XCTAssertTrue(model.advanceLine())
        XCTAssertEqual(model.visibleTarget, "━━━━━━━━", "Hints don't carry over to the next line")
        model.setMode(.copy)
        model.editorText = "def f(t"
        model.revealHint()
        XCTAssertEqual(model.hintOffset, 7, "Copy points at the next expected character")
    }

    func testCompletionSummarizesAndSelfRatingAdjustsTheGrade() throws {
        let model = try freshModel(for: self)
        try model.updatePlaceholder(with: "def f():\n    a = 1\n    b = 2\n    return a + b", language: .python)
        model.setMode(.recall)                                                   // types lines 1–3
        for typed in ["a = 2", "a = 1", "b = 2", "return a + b"] { model.editorText = typed; model.advanceLine() }
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.lastSummary?.weakLines, [1]); XCTAssertEqual(model.grade, .good)
        model.rate(.effortless)
        XCTAssertEqual(model.grade, .good, "Effortless can't lift a line that wasn't clean")
        model.rate(.shaky)
        XCTAssertEqual(model.grade, .hard)
        model.setMode(.keyLines)
        XCTAssertEqual(model.practiceLines.map(\.sourceIndex), [1], "Key lines fall back to this session's weak lines")
        XCTAssertNil(model.lastSummary)
    }

    func testGradedModesIgnoreSpacingOnlyDifferences() throws {
        let model = try freshModel(for: self)
        try model.loadLesson(windowLesson)
        model.setMode(.keyLines)
        model.editorText = "left=max(left,seen.get(char,-1)+1)"
        XCTAssertTrue(model.advanceLine()); XCTAssertEqual(model.lineAttempts[5], nil, "Still clean")
        model.setMode(.copy)
        model.editorText = "def f(text) :"
        XCTAssertFalse(model.advanceLine(), "Copy stays exact")
    }
}

extension EditorRegressionTests {
    func testHiddenModesUnderlineOnlyAfterReturnUntilTheNextEdit() {
        var submissions = 0
        let parent = TextKit2TypingEditor(typedText: .constant("abx"), targetText: .constant("abc"), fontSize: 18,
                                         liveFeedback: false, onSubmit: { submissions += 1 })
        let coordinator = TextKit2Coordinator(parent), view = NSTextView()
        view.string = "abx"
        coordinator.textView = view
        coordinator.applyStyle()
        XCTAssertNil(view.textStorage?.attribute(.underlineStyle, at: 2, effectiveRange: nil), "No live colouring")
        XCTAssertTrue(coordinator.textView(view, doCommandBy: #selector(NSTextView.insertNewline(_:))))
        XCTAssertEqual(submissions, 1)
        XCTAssertNotNil(view.textStorage?.attribute(.underlineStyle, at: 2, effectiveRange: nil))
        view.string = "ab"
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: view))
        XCTAssertNil(view.textStorage?.attribute(.underlineStyle, at: 1, effectiveRange: nil))
    }
}
