import XCTest

final class TypingPallUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    @discardableResult
    private func launchApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-NSQuitAlwaysKeepsWindows", "NO"] + arguments
        app.launch()
        app.activate()
        return app
    }

    func testLinePracticeCorrectionRepetitionCompletionAndLibrary() {
        let app = launchApp(arguments: ["-ux.hasSeenPracticeTip", "YES"])
        let addScript = app.buttons["Add Script"]
        XCTAssertTrue(addScript.waitForExistence(timeout: 10))
        addScript.click()
        let script = app.textViews["scriptText"]
        XCTAssertTrue(script.waitForExistence(timeout: 5))
        script.click()
        script.typeText("abc\n    def")
        app.buttons["Save & Practice"].click()
        let input = app.textViews["practiceInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["targetLine"].text, "abc")
        input.click()
        input.typeText("abx")
        XCTAssertEqual(input.value as? String, "abx")
        input.typeText(XCUIKeyboardKey.delete.rawValue + "c")
        XCTAssertTrue(app.buttons["nextLine"].isEnabled)
        input.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(input.value as? String, "")
        XCTAssertEqual(app.staticTexts["targetLine"].text, "def", "Indentation is skipped")
        input.typeText("de")
        app.buttons["repeatLine"].click()
        XCTAssertEqual(input.value as? String, "")
        input.click()
        input.typeText("def" + XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(app.staticTexts["Pattern complete"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["completionRepeat"].exists, "Scripts offer Repeat as the main action")
        app.typeKey(.return, modifierFlags: [])
        XCTAssertEqual(app.textViews["practiceInput"].value as? String, "")
        XCTAssertEqual(app.staticTexts["targetLine"].text, "abc")
        app.buttons["restartPractice"].click()
        XCTAssertEqual(app.textViews["practiceInput"].value as? String, "")
        app.buttons["Library"].click()
        app.segment("My scripts").click()
        app.buttons["Practice"].click()
        XCTAssertEqual(app.textViews["practiceInput"].value as? String, "")
    }

    func testEmptyScriptCannotBeSaved() {
        let app = launchApp(arguments: ["-ux.hasSeenPracticeTip", "YES"])
        let addScript = app.buttons["Add Script"]
        XCTAssertTrue(addScript.waitForExistence(timeout: 10))
        addScript.click()
        XCTAssertFalse(app.buttons["Save & Practice"].isEnabled)
        app.buttons["Cancel"].click()
        XCTAssertTrue(app.textViews["practiceInput"].exists)
    }
    func testBuiltInLessonSearchLoadAndCommentSkipping() {
        let app = launchApp(arguments: ["-ux.hasSeenPracticeTip", "YES", "-skipPracticeComments", "YES"])
        let library = app.buttons["Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        library.click()
        let search = app.textFields["lessonSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("zzzz")
        app.buttons["clearSearch"].click()
        XCTAssertTrue(app.staticTexts["Sliding window"].exists)
        search.click()
        search.typeText("Sliding window")
        app.staticTexts["Sliding window"].firstMatch.click()
        app.buttons["practiceLesson"].click()
        let input = app.textViews["practiceInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.click()
        input.typeCode("def longest_unique(text):")
        XCTAssertTrue(app.buttons["nextLine"].isEnabled)
        app.buttons["practiceOptions"].click()
        let skip = app.checkBoxes["skipComments"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.click()
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertEqual(input.value as? String, "")
        input.click()
        input.typeCode("def longest_unique(text):")
        XCTAssertTrue(app.buttons["nextLine"].isEnabled, "Changing options keeps your place")
        app.buttons["restartPractice"].click()
        input.click()
        input.typeText("# Keep a window with no repeated characters.")
        XCTAssertTrue(app.buttons["nextLine"].isEnabled)
    }

    func testLibrarySearchMatchesTriggersAndShowsPatternNotes() {
        let app = launchApp(arguments: ["-ux.hasSeenPracticeTip", "YES"])
        let library = app.buttons["Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        library.click()
        let search = app.textFields["lessonSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("next greater")   // appears only in py-monotonic-stack's triggers
        app.staticTexts["Monotonic stack: next warmer day"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["lessonMantra"].waitForExistence(timeout: 5))
        app.buttons["practiceLesson"].click()
        XCTAssertTrue(app.textViews["practiceInput"].waitForExistence(timeout: 5))
    }

    func testFirstRunTipShowsUntilSeen() {
        let app = launchApp(arguments: ["-ux.hasSeenPracticeTip", "NO"])
        XCTAssertTrue(app.buttons["dismissTip"].waitForExistence(timeout: 10))
        app.terminate()
        let app2 = launchApp(arguments: ["-ux.hasSeenPracticeTip", "YES"])
        XCTAssertTrue(app2.textViews["practiceInput"].waitForExistence(timeout: 10))
        XCTAssertFalse(app2.buttons["dismissTip"].exists)
    }

    func testKeyLinesCheckOnReturnHintsAndSelfRating() {
        let app = launchApp(arguments: ["-ux.hasSeenPracticeTip", "YES"])
        let library = app.buttons["Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        library.click()
        let search = app.textFields["lessonSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("Sliding window")
        app.staticTexts["Sliding window"].firstMatch.click()
        app.buttons["practiceLesson"].click()
        let input = app.textViews["practiceInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        app.typeKey("2", modifierFlags: .command)                       // Key lines: M2a's lines 7, 8 and 9
        input.click()
        input.typeText("left = min(left, last_seen[char] + 1)" + XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(input.value as? String, "left = min(left, last_seen[char] + 1)")
        XCTAssertTrue(app.staticTexts["Not quite: the first difference is at character 9."].exists)
        input.typeKey("a", modifierFlags: .command)
        input.typeText("left = max(left, last_seen[char] + 1)" + XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(input.value as? String, "")
        for _ in 0..<3 { app.buttons["hintButton"].click() }
        input.click()
        input.typeText("last_seen[char] = right" + XCUIKeyboardKey.return.rawValue)
        input.typeText("best = max(best, right - left + 1)" + XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(app.buttons["rateSolid"].waitForExistence(timeout: 5))
        app.buttons["rateSolid"].click()
        XCTAssertTrue(app.staticTexts["attemptSummary"].exists)
    }

    func testWhichPatternDrillRevealsCuesAndOpensPractice() {
        let app = launchApp(arguments: ["-ux.hasSeenPracticeTip", "YES"])
        XCTAssertTrue(app.buttons["whichPattern"].waitForExistence(timeout: 10))
        app.typeKey("d", modifierFlags: [.command, .shift])
        XCTAssertTrue(app.staticTexts["drillPrompt"].waitForExistence(timeout: 5))
        app.buttons["drillOption0"].click()
        XCTAssertTrue(app.staticTexts["drillMantra"].waitForExistence(timeout: 5))
        app.buttons["drillPractice"].click()
        XCTAssertTrue(app.textViews["practiceInput"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["drillPrompt"].waitForNonExistence(timeout: 5))
    }

    func testBugHuntFindFixAndExplanation() {
        let app = launchApp(arguments: ["-ux.hasSeenPracticeTip", "YES"])
        let library = app.buttons["Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        library.click()
        let search = app.textFields["lessonSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("top k")
        app.staticTexts["Heap: top k largest"].firstMatch.click()
        app.buttons["findBug"].click()
        app.buttons["referenceLine8"].click()
        XCTAssertTrue(app.staticTexts["bugHuntStatus"].waitForExistence(timeout: 5))
        app.buttons["referenceLine9"].click()                         // py-top-k's only planted bug
        let input = app.textViews["practiceInput"]
        input.click()
        input.typeCode("if len(heap) > k:")
        input.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(app.staticTexts["bugExplanation"].waitForExistence(timeout: 5))
    }

    func testContrastPairFromTheLibrary() {
        let app = launchApp(arguments: ["-ux.hasSeenPracticeTip", "YES"])
        let library = app.buttons["Library"]
        XCTAssertTrue(library.waitForExistence(timeout: 10))
        library.click()
        let search = app.textFields["lessonSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("lower bound")
        app.staticTexts["Binary search: lower bound"].firstMatch.click()
        app.buttons["contrast-py-upper-bound"].click()
        XCTAssertTrue(app.descendants(matching: .any)["contrastBase"].firstMatch.waitForExistence(timeout: 5))
        let input = app.textViews["practiceInput"]
        input.click()
        input.typeText("def upper")
        XCTAssertEqual(input.value as? String, "def upper", "The differing lines are typed")
    }

}

private extension XCUIElement {
    /// SwiftUI Text exposes its string as the accessibility value on macOS.
    var text: String { (value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? label }

    /// typeText drops ":" with the British keyboard layout, so colons are typed as Shift-;.
    func typeCode(_ text: String) {
        for (index, part) in text.components(separatedBy: ":").enumerated() {
            if index > 0 { typeKey(";", modifierFlags: .shift) }
            if !part.isEmpty { typeText(part) }
        }
    }
}

private extension XCUIApplication {
    /// Segmented-picker segments are radio buttons from macOS 26 and buttons before it.
    func segment(_ label: String) -> XCUIElement {
        let types = [XCUIElement.ElementType.button.rawValue, XCUIElement.ElementType.radioButton.rawValue]
        return descendants(matching: .any).matching(NSPredicate(format: "label == %@ AND elementType IN %@", label, types)).firstMatch
    }
}
