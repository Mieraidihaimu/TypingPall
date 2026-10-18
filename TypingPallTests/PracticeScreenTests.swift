import XCTest
@testable import TypingPall

extension XCTestCase {
    func makeDefaults() -> UserDefaults {
        let name = "PracticeScreenTests-\(UUID().uuidString)"
        addTeardownBlock { UserDefaults.standard.removePersistentDomain(forName: name) }
        return UserDefaults(suiteName: name)!
    }
}

final class LegacyLineDiffTests: XCTestCase {
    func testCorrectPrefixHasNoMismatch() {
        let diff = LineDiff(typed: "int le", target: "int left = 0;")
        XCTAssertNil(diff.firstMismatch); XCTAssertNil(diff.mismatchRange)
        XCTAssertEqual(diff.expected, "f"); XCTAssertFalse(diff.isMatch)
    }

    func testMismatchRangeCoversTheRestOfTheTypedText() {
        let diff = LineDiff(typed: "int lxft", target: "int left")
        XCTAssertEqual(diff.firstMismatch, 5)
        XCTAssertEqual(diff.mismatchRange, NSRange(location: 5, length: 3))
        XCTAssertEqual(diff.expected, "e")
    }

    func testTypingPastTheEndIsAMismatch() {
        let diff = LineDiff(typed: "abc;", target: "abc")
        XCTAssertEqual(diff.firstMismatch, 3)
        XCTAssertEqual(diff.mismatchRange, NSRange(location: 3, length: 1))
        XCTAssertNil(diff.expected)
    }

    func testCharacterOffsetsAndUTF16Ranges() {
        let diff = LineDiff(typed: "é🙂x", target: "é🙂y")
        XCTAssertEqual(diff.firstMismatch, 2)
        XCTAssertEqual(diff.mismatchRange, NSRange(location: 3, length: 1))
        XCTAssertTrue(LineDiff(typed: "e\u{301}", target: "é").isMatch)
    }

    func testEmptyInputsAndExactMatch() {
        XCTAssertEqual(LineDiff(typed: "", target: "x").expected, "x")
        XCTAssertTrue(LineDiff(typed: "", target: "").isMatch)
        XCTAssertTrue(LineDiff(typed: "a = 1", target: "a = 1").isMatch)
    }

    func testPreparedTargetLineAndCanonicalEquivalence() {
        let cases = [
            ("let café = 1", "let cafe\u{301} = 1"),
            ("const naïve = true;", "const nai\u{308}ve = true;"),
            ("// résumé", "// re\u{301}sume\u{301}")
        ]
        for (expected, typed) in cases {
            let target = PreparedTargetLine(rawLine: expected)
            let result = LineDiff.evaluate(target: target, typed: typed, tolerance: .strictCharacter)
            XCTAssertNil(result.errorUTF16Range, "Mismatch in canonical equivalence for \(expected) vs \(typed)")
            XCTAssertTrue(result.isComplete)
        }
    }

    func testSyntaxAwareTriviaMatching() {
        let target = PreparedTargetLine(rawLine: "    int left = 0, right = n - 1;")
        let compactTyped = "int left=0,right=n-1;"

        let strictResult = LineDiff.evaluate(target: target, typed: compactTyped, tolerance: .strictCharacter)
        XCTAssertNotNil(strictResult.errorUTF16Range)

        let relaxedResult = LineDiff.evaluate(target: target, typed: compactTyped, tolerance: .syntaxAwareTrivia)
        XCTAssertNil(relaxedResult.errorUTF16Range)
        XCTAssertTrue(relaxedResult.isComplete)

        // Ensure spaces inside string literals are NEVER collapsed
        let stringTarget = PreparedTargetLine(rawLine: #"print("hello  world")"#)
        let wrongStringTyped = #"print("hello world")"#
        let stringResult = LineDiff.evaluate(target: stringTarget, typed: wrongStringTyped, tolerance: .syntaxAwareTrivia)
        XCTAssertNotNil(stringResult.errorUTF16Range)
    }

    func testFuzzUTF16BoundsSafety() {
        let fragments = ["func ", "é", "e\u{301}", "👨‍👩‍👧‍👦", "🏳️‍🌈", "🚀", "int a = 0;", "漢字", "\u{200B}"]
        var rng = SystemRandomNumberGenerator()

        for _ in 0..<500 {
            let expectedRaw = (0..<Int.random(in: 0...8, using: &rng))
                .map { _ in fragments.randomElement(using: &rng)! }
                .joined()
            let typedRaw = (0..<Int.random(in: 0...8, using: &rng))
                .map { _ in fragments.randomElement(using: &rng)! }
                .joined()

            let target = PreparedTargetLine(rawLine: expectedRaw)
            let result = LineDiff.evaluate(target: target, typed: typedRaw)

            if let errorRange = result.errorUTF16Range {
                let utf16Length = (typedRaw as NSString).length
                XCTAssertGreaterThanOrEqual(errorRange.location, 0)
                XCTAssertLessThanOrEqual(NSMaxRange(errorRange), utf16Length)
            }
        }
    }
}

@MainActor
final class PracticeScreenModelTests: XCTestCase {
    func testReferenceRowsFlagCurrentAndSkippedLines() throws {
        let model = TypingScreenViewModel(defaults: makeDefaults())
        try model.updatePlaceholder(with: "# c\nx = 1\ny = 2", language: .python)
        XCTAssertEqual(model.referenceRows.map(\.sourceIndex), [0, 1, 2])
        XCTAssertEqual(model.referenceRows.map(\.isSkipped), [true, false, false])
        XCTAssertEqual(model.referenceRows.filter(\.isCurrent).map(\.sourceIndex), [1])
        XCTAssertTrue(model.referenceRows.allSatisfy { !$0.isMasked && $0.marker == nil })
        model.editorText = "x = 1"; model.advanceLine()
        model.editorText = "y = 2"; model.advanceLine()
        XCTAssertTrue(model.isComplete)
        XCTAssertFalse(model.referenceRows.contains(where: \.isCurrent), "No current row once complete")
    }

    func testProgressTextIsASingleReadout() throws {
        let model = TypingScreenViewModel(defaults: makeDefaults())
        try model.updatePlaceholder(with: "a\nb")
        XCTAssertEqual(model.progressText, "1 of 2")
        model.editorText = "a"; model.advanceLine()
        XCTAssertEqual(model.progressText, "2 of 2")
        model.editorText = "b"; model.advanceLine()
        XCTAssertEqual(model.progressText, "Pattern complete")
        try model.updatePlaceholder(with: "# only", language: .python)
        XCTAssertEqual(model.progressText, "No code to practice")
    }

    func testSubtitleNamesTheSource() throws {
        let catalog = try PracticeCatalog.load()
        let model = TypingScreenViewModel(defaults: makeDefaults())
        XCTAssertEqual(model.lessonSubtitle, "Starter pattern")
        try model.loadLesson(catalog[0])
        XCTAssertEqual(model.currentLessonID, catalog[0].id)
        XCTAssertEqual(model.lessonSubtitle, catalog[0].category)
        try model.updatePlaceholder(with: "x = 1", language: .python)
        XCTAssertNil(model.currentLessonID)
        XCTAssertEqual(model.lessonSubtitle, "My script · Python")
    }

    func testChangingOptionsMidPatternKeepsYourPlace() throws {
        let model = TypingScreenViewModel(defaults: makeDefaults())
        try model.updatePlaceholder(with: "# intro\na = 1\nb = 2 # note\nc = 3", language: .python)
        model.editorText = "a = 1"
        XCTAssertTrue(model.advanceLine())
        model.editorText = "b ="
        model.setSkipComments(false)
        XCTAssertEqual(model.currentLineIndex, 2, "Same source line")
        XCTAssertEqual(model.currentLine, "b = 2 # note")
        XCTAssertEqual(model.editorText, "", "The attempt restarts on the same line")
        model.setSkipComments(true)
        XCTAssertEqual(model.currentLine, "b = 2")
        model.setLanguage(.plainText)
        XCTAssertEqual(model.currentLineIndex, 2)
    }

    func testChangingOptionsAfterCompletionRestarts() throws {
        let model = TypingScreenViewModel(defaults: makeDefaults())
        try model.updatePlaceholder(with: "a = 1\n# end", language: .python)
        model.editorText = "a = 1"
        XCTAssertTrue(model.advanceLine())
        XCTAssertTrue(model.isComplete)
        model.setSkipComments(false)
        XCTAssertFalse(model.isComplete)
        XCTAssertEqual(model.currentLineIndex, 0)
    }

    func testNewScriptLanguageRemembersTheLastChoice() {
        let defaults = makeDefaults()
        XCTAssertEqual(TypingScreenViewModel(defaults: defaults).draftLanguage, .plainText)
        TypingScreenViewModel(defaults: defaults).draftLanguage = .go
        XCTAssertEqual(TypingScreenViewModel(defaults: defaults).draftLanguage, .go)
    }

    func testStarterPatternLanguageCannotBeOverridden() {
        let model = TypingScreenViewModel(defaults: makeDefaults())
        model.editorText = "int lowerBound"
        XCTAssertFalse(model.canEditLanguage)
        model.setLanguage(.go)
        XCTAssertEqual(model.language, .cpp)
        XCTAssertEqual(model.editorText, "int lowerBound", "An ignored override preserves the attempt")
        XCTAssertEqual(model.placeholderText, TypingScreenViewModel.starterPattern)
    }

    func testBuiltInLessonLanguageCannotBeOverridden() throws {
        let model = TypingScreenViewModel(defaults: makeDefaults())
        let lesson = PracticeLesson(id: "python", title: "Python", category: "Test", track: .languages,
                                    language: .python, summary: "S", code: "# intro\nx = 1")
        try model.loadLesson(lesson)
        model.editorText = "x ="
        XCTAssertFalse(model.canEditLanguage)
        model.setLanguage(.go)
        XCTAssertEqual(model.language, .python)
        XCTAssertEqual(model.currentLine, "x = 1")
        XCTAssertEqual(model.editorText, "x =")
        XCTAssertEqual(model.currentLessonID, lesson.id)
    }

    func testLanguageCanBeCorrectedForUserScripts() throws {
        let model = TypingScreenViewModel(defaults: makeDefaults())
        try model.updatePlaceholder(with: "# intro\nx = 1", language: .plainText)
        XCTAssertTrue(model.canEditLanguage)
        XCTAssertEqual(model.currentLine, "# intro")
        model.setLanguage(.python)
        XCTAssertEqual(model.language, .python)
        XCTAssertEqual(model.currentLine, "x = 1", "Comment handling follows the corrected script language")
        XCTAssertEqual(model.placeholderText, "# intro\nx = 1", "Changing language preserves the source code")
    }

    func testReferenceUsesASmallerFontAndSplitsIndentation() {
        XCTAssertEqual(ReferenceCodeView.referenceFontSize(for: 25), 18)
        XCTAssertEqual(ReferenceCodeView.referenceFontSize(for: 12), 11)
        XCTAssertEqual(ReferenceCodeView.referenceFontSize(for: 30), 21)
        XCTAssertEqual(ReferenceCodeView.split("        left = mid + 1").indent.count, 8)
        XCTAssertEqual(ReferenceCodeView.split("        left = mid + 1").code, "left = mid + 1")
        XCTAssertEqual(ReferenceCodeView.split("").code, "")
    }

    func testNextLessonFollowsCatalogOrder() throws {
        let catalog = try PracticeCatalog.load()
        let model = TypingScreenViewModel(defaults: makeDefaults())
        XCTAssertEqual(model.nextLesson(in: catalog)?.id, catalog.first?.id, "Starter → first lesson")
        try model.loadLesson(catalog[0])
        XCTAssertEqual(model.nextLesson(in: catalog)?.id, catalog[1].id)
        try model.loadLesson(catalog[catalog.count - 1])
        XCTAssertNil(model.nextLesson(in: catalog), "No wrap-around")
        try model.updatePlaceholder(with: "x = 1")
        XCTAssertNil(model.nextLesson(in: catalog), "User scripts have no next lesson")
    }
}
