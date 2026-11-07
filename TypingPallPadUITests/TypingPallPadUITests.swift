import XCTest

@MainActor
final class TypingPallPadUITests: XCTestCase {
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "-ux.hasSeenPracticeTip", "YES",
                               "-skipPracticeComments", "YES", "-ux.diffTolerance", "strictCharacter"]
        app.launch()
        addTeardownBlock { app.terminate() }
        return app
    }

    private func assertTarget(_ expected: String, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let target = app.staticTexts["targetLine"]
        let match = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", expected), object: target)
        XCTAssertEqual(XCTWaiter.wait(for: [match], timeout: 5), .completed,
                       "Expected \(expected), found \(target.exists ? target.label : "no target")", file: file, line: line)
    }

    func testReturnChecksTheLineAndTapCanAdvanceTheNextLine() {
        let app = launchApp()
        let input = app.textViews["practiceInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("intx")
        XCTAssertFalse(app.buttons["nextLine"].isEnabled)
        input.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(input.value as? String, "intx")

        input.typeText(XCUIKeyboardKey.delete.rawValue)
        input.typeText(" lowerBound(const std::vector<int>& values, int target) {")
        XCTAssertEqual(input.value as? String, "int lowerBound(const std::vector<int>& values, int target) {")
        XCTAssertTrue(app.buttons["nextLine"].isEnabled)
        input.typeText(XCUIKeyboardKey.return.rawValue)
        assertTarget("int left = 0;", in: app)

        input.typeText("int left = 0;")
        app.buttons["nextLine"].tap()
        assertTarget("int right = static_cast<int>(values.size());", in: app)
    }

    func testLibraryRoundTripPreservesInputAndRecallMasksTheAnswer() {
        let app = launchApp()
        let input = app.textViews["practiceInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        input.tap()
        input.typeText("int")
        app.buttons["openLibrary"].tap()
        let close = app.buttons["closeLibrary"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        XCTAssertEqual(input.value as? String, "int")

        input.typeKey("3", modifierFlags: .command)
        let target = app.staticTexts["targetLine"]
        assertTarget("Hidden line", in: app)
        input.typeText("wrong")
        app.buttons["nextLine"].tap()
        XCTAssertTrue(target.label.hasPrefix("Hint:"), "Checking in Recall should reveal the first hint")
    }

    func testSaveAndReopenAScript() {
        let app = launchApp()
        let actions = app.buttons["practiceActions"]
        XCTAssertTrue(actions.waitForExistence(timeout: 10))
        actions.tap()
        app.buttons["Add Script"].tap()
        let code = app.textViews["scriptText"]
        XCTAssertTrue(code.waitForExistence(timeout: 5))
        code.tap()
        let draft = "let a = 1\n\nlet b = 2"
        code.typeText(draft)
        XCTAssertEqual(code.value as? String, draft)
        app.buttons["saveScript"].tap()
        assertTarget("let a = 1", in: app)

        let input = app.textViews["practiceInput"]
        input.typeText("let a = 1")
        XCTAssertEqual(input.value as? String, "let a = 1")
        input.typeText(XCUIKeyboardKey.return.rawValue)
        assertTarget("let b = 2", in: app)

        app.buttons["openLibrary"].tap()
        let scripts = app.segmentedControls["libraryShelf"].buttons["My Scripts"]
        XCTAssertTrue(scripts.waitForExistence(timeout: 5))
        scripts.tap()
        let saved = app.buttons["savedScript"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        saved.tap()
        assertTarget("let a = 1", in: app)
    }
}
