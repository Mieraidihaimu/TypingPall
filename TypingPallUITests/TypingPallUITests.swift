import XCTest

final class TypingPallUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testLinePracticeCorrectionRepetitionCompletionAndLibrary() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["Add Script"].click()
        let script = app.textViews["scriptText"]
        XCTAssertTrue(script.waitForExistence(timeout: 5))
        script.click()
        script.typeText("abc\n    def")
        app.buttons["Save & Practice"].click()
        let input = app.textViews["practiceInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.click()
        input.typeText("abx")
        XCTAssertEqual(input.value as? String, "abx")
        input.typeText(XCUIKeyboardKey.delete.rawValue + "c")
        XCTAssertTrue(app.buttons["nextLine"].isEnabled)
        input.typeText(XCUIKeyboardKey.return.rawValue)
        XCTAssertEqual(input.value as? String, "")
        input.typeText("de")
        app.buttons["repeatLine"].click()
        XCTAssertEqual(input.value as? String, "")
        input.click()
        input.typeText("def" + XCUIKeyboardKey.return.rawValue)
        XCTAssertTrue(app.staticTexts["Pattern complete"].waitForExistence(timeout: 5))
        app.buttons["restartPractice"].click()
        XCTAssertEqual(app.textViews["practiceInput"].value as? String, "")
        app.buttons["Library"].click()
        app.buttons["My scripts"].click()
        app.buttons["Practice"].click()
        XCTAssertEqual(app.textViews["practiceInput"].value as? String, "")
    }

    func testEmptyScriptCannotBeSaved() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["Add Script"].click()
        XCTAssertFalse(app.buttons["Save & Practice"].isEnabled)
        app.buttons["Cancel"].click()
        XCTAssertTrue(app.textViews["practiceInput"].exists)
    }
    func testBuiltInLessonSearchLoadAndCommentSkipping() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"]
        app.launch()
        app.buttons["Library"].click()
        let search = app.textFields["lessonSearch"]
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.click()
        search.typeText("Sliding window")
        app.staticTexts["Sliding window"].firstMatch.click()
        app.buttons["practiceLesson"].click()
        let input = app.textViews["practiceInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let skip = app.checkBoxes["skipComments"]
        if (skip.value as? String) == "0" { skip.click() }
        input.click()
        input.typeText("def longest_unique(text):")
        XCTAssertTrue(app.buttons["nextLine"].isEnabled)
        skip.click()
        XCTAssertEqual(input.value as? String, "")
        input.click()
        input.typeText("# Keep a window with no repeated characters.")
        XCTAssertTrue(app.buttons["nextLine"].isEnabled)
    }

}
