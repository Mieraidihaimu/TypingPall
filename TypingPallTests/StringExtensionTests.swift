import XCTest
@testable import TypingPall

class StringExtensionTests: XCTestCase {

    func testExtractMismatchedRange_WhenStringsAreIdentical() {
        // Given: Two identical strings
        let stringA = "Hello, World!"
        let stringB = "Hello, World!"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result should be nil
        XCTAssertNil(range)
    }

    func testExtractMismatchedRange_WhenStringAIsLonger() {
        // Given: String A is longer than String B
        let stringA = "Hello, World!"
        let stringB = "Hello"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result should be the range of the extra characters in String A
        XCTAssertEqual(range, NSRange(location: 5, length: 13 - 5))
    }

    func testExtractMismatchedRange_WhenStringBIsLonger() {
        // Given: String B is longer than String A
        let stringA = "Hello"
        let stringB = "Hello, World!"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result should be nil
        XCTAssertNil(range)
    }

    func testExtractMismatchedRange_WhenStringsHaveDifferentCharacters() {
        // Given: Two strings with different characters
        let stringA = "Hello, World!"
        let stringB = "Hello, Swift!"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result should be the range of the different characters in String A
        XCTAssertEqual(range, NSRange(location: 7, length: 13 - 7))
    }

    func testExtractMismatchedRange_WhenStringAIsEmpty() {
        // Given: String A is empty
        let stringA = ""
        let stringB = "Hello, World!"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result should be nil
        XCTAssertNil(range)
    }

    func testExtractMismatchedRange_WhenStringBIsEmpty() {
        // Given: String B is empty
        let stringA = "Hello, World!"
        let stringB = ""

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result all string A is mismatched
        XCTAssertEqual(range, NSRange(location: 0, length: 13))
    }

    func testExtractMismatchedRange_WhenStringBIsTotallyMismatch() {
        // Given: String B is empty
        let stringA = "Hello, World!"
        let stringB = "WFDSFDHSJ"

        // When: extractMismatchedRange is called
        let range = stringA.extractMismatchedRange(comparedTo: stringB)

        // Then: The result all string A is mismatched compare to String B
        XCTAssertEqual(range, NSRange(location: 0, length: 13))
    }
}


final class PracticeTextTests: XCTestCase {
    func testUnicodeRangesUseUTF16() {
        XCTAssertEqual("👨‍👩‍👧‍👦x".extractMismatchedRange(comparedTo: "👨‍👩‍👧‍👦y"), NSRange(location: 11, length: 1))
        XCTAssertEqual("é🙂".extractMismatchedRange(comparedTo: "éx"), NSRange(location: 1, length: 2))
        XCTAssertNil("e\u{301}".extractMismatchedRange(comparedTo: "é"))
    }

    func testNormalizationPreservesLiteralMarkers() throws {
        XCTAssertEqual(try PracticeText.validated("·→↵\t🙂\r\nx\ry", tabSpaces: 2), "·→↵  🙂\nx\ny")
    }

    func testRejectsEmptyBinaryAndOversizedText() {
        for text in [" \n\t", "abc\0def", String(repeating: "x", count: 20_001)] {
            XCTAssertThrowsError(try PracticeText.validated(text, tabSpaces: 4))
        }
        XCTAssertThrowsError(try PracticeText.validated(String(repeating: "\t", count: 6_000) + "x", tabSpaces: 4))
    }

    func testInvalidPreferencesAreClamped() {
        XCTAssertEqual(PracticeText.tabWidth(.nan), 4)
        XCTAssertEqual(PracticeText.tabWidth(.infinity), 4)
        XCTAssertEqual(PracticeText.tabWidth(-1), 1)
        XCTAssertEqual(PracticeText.tabWidth(1e20), 8)
    }
}

@MainActor
final class PatternPracticeTests: XCTestCase {
    func testRequiresMatchingLineBeforeAdvancing() throws {
        let model = TypingScreenViewModel()
        try model.updatePlaceholder(with: "first\n    second\nlast")
        model.editorText = "wrong"
        XCTAssertFalse(model.advanceLine())
        XCTAssertEqual(model.currentLineIndex, 0)
        model.editorText = "first"
        XCTAssertTrue(model.advanceLine())
        XCTAssertEqual(model.currentLine, "second")
        XCTAssertEqual(model.lines[1], "    second")
        XCTAssertEqual(model.completedLineCount, 1)
        XCTAssertEqual(model.editorText, "")
        model.editorText = "second"
        XCTAssertTrue(model.advanceLine(), "Leading indentation is skipped")
    }

    func testSkipsMixedIndentationAndWhitespaceOnlyLinesWhilePreservingContentSpacing() throws {
        let model = TypingScreenViewModel()
        try model.updatePlaceholder(with: " \t🙂 =  1  \n\t  \n\tend")
        XCTAssertEqual(model.currentLine, "🙂 =  1  ")
        model.editorText = "🙂 = 1  "
        XCTAssertFalse(model.advanceLine(), "Internal spaces are still required")
        model.editorText = "🙂 =  1"
        XCTAssertFalse(model.advanceLine(), "Trailing spaces are still required")
        model.editorText = "🙂 =  1  "
        XCTAssertTrue(model.advanceLine())
        XCTAssertEqual(model.currentLine, "end")
        XCTAssertEqual(model.currentLineIndex, 2)
        model.editorText = "en"
        model.repeatLine()
        XCTAssertEqual(model.editorText, "")
        XCTAssertEqual(model.currentLine, "end")
        model.editorText = "end"
        XCTAssertTrue(model.advanceLine())
        XCTAssertTrue(model.isComplete)
        model.restart()
        XCTAssertEqual(model.currentLine, "🙂 =  1  ")
        XCTAssertEqual(model.editorText, "")
    }

    func testRepeatLinePreservesPositionAndPatternRestartResetsIt() throws {
        let model = TypingScreenViewModel()
        try model.updatePlaceholder(with: "one\ntwo")
        model.editorText = "one"
        model.advanceLine()
        let previousID = model.sessionID
        model.editorText = "tw"
        model.repeatLine()
        XCTAssertEqual(model.currentLineIndex, 1)
        XCTAssertEqual(model.completedLineCount, 1)
        XCTAssertEqual(model.editorText, "")
        XCTAssertNotEqual(model.sessionID, previousID)
        model.restart()
        XCTAssertEqual(model.currentLineIndex, 0)
        XCTAssertEqual(model.completedLineCount, 0)
    }

    func testBlankLinesUnicodeAndFinalNewline() throws {
        let model = TypingScreenViewModel()
        try model.updatePlaceholder(with: "\n🙂\n\n終わり\n\n")
        XCTAssertEqual(model.lines.count, 5)
        XCTAssertEqual(model.practiceLines.map(\.sourceIndex), [1, 3])
        model.editorText = "🙂"
        XCTAssertTrue(model.advanceLine())
        XCTAssertEqual(model.currentLine, "終わり")
        model.editorText = "終わり"
        XCTAssertFalse(model.isComplete, "Matching the final line waits for deliberate confirmation")
        XCTAssertTrue(model.advanceLine())
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.completedLineCount, 2)
        XCTAssertFalse(model.advanceLine())
        model.restart()
        XCTAssertFalse(model.isComplete)
    }
}

#if os(macOS)
import AppKit
#endif
import SwiftUI
import CoreData

@MainActor
final class EditorRegressionTests: XCTestCase {
    #if os(macOS)
    func testEditorNeverCopiesReferenceAndAllowsDeletionAndUnicode() {
        var typed = "🙂x"
        let parent = TextKit2TypingEditor(typedText: Binding(get: { typed }, set: { typed = $0 }),
                                         targetText: .constant("🙂y·→↵"), fontSize: 18)
        let coordinator = TextKit2Coordinator(parent)
        let view = NSTextView()
        view.string = typed
        coordinator.textView = view
        coordinator.applyStyle()
        XCTAssertEqual(view.string, "🙂x")
        XCTAssertTrue(coordinator.textView(view, shouldChangeTextIn: NSRange(location: 2, length: 1), replacementString: ""))
        view.string = "🙂"
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: view))
        XCTAssertEqual(typed, "🙂")
        XCTAssertEqual(view.string, "🙂")
        XCTAssertEqual(view.textStorage?.length, 2)
    }

    func testReturnSubmitsLineAndMultilinePasteIsRejected() {
        var submissions = 0
        let parent = TextKit2TypingEditor(typedText: .constant("x"), targetText: .constant("x"),
                                         fontSize: 18, onSubmit: { submissions += 1 })
        let coordinator = TextKit2Coordinator(parent)
        let view = NSTextView()
        view.string = "x"
        XCTAssertTrue(coordinator.textView(view, doCommandBy: #selector(NSTextView.insertNewline(_:))))
        XCTAssertEqual(submissions, 1)
        XCTAssertEqual(view.string, "x")
        XCTAssertFalse(coordinator.textView(view, shouldChangeTextIn: NSRange(location: 1, length: 0), replacementString: "y\nz"))
        XCTAssertTrue(coordinator.textView(view, shouldChangeTextIn: NSRange(location: 1, length: 0), replacementString: "y"))
    }

    func testStyleMarksOnlyTheFirstDifference() throws {
        let parent = TextKit2TypingEditor(typedText: .constant("abxd"), targetText: .constant("abcd"), fontSize: 18)
        let coordinator = TextKit2Coordinator(parent)
        let view = NSTextView()
        view.string = "abxd"
        coordinator.textView = view
        coordinator.applyStyle()
        let storage = try XCTUnwrap(view.textStorage)
        func color(_ i: Int) -> NSColor? { storage.attribute(.foregroundColor, at: i, effectiveRange: nil) as? NSColor }
        func underline(_ i: Int) -> Int? { storage.attribute(.underlineStyle, at: i, effectiveRange: nil) as? Int }
        XCTAssertEqual(color(0), .labelColor)
        XCTAssertNil(underline(1))
        XCTAssertEqual(underline(2), NSUnderlineStyle.thick.rawValue)
        XCTAssertEqual(color(3), .tertiaryLabelColor)
        XCTAssertNil(underline(3))
    }

    func testRejectedEditsReportTheirReason() {
        var reasons: [PracticeText.InputRejection] = []
        let parent = TextKit2TypingEditor(typedText: .constant("x"), targetText: .constant("x"), fontSize: 18,
                                         onSubmit: {}, onReject: { reasons.append($0) })
        let coordinator = TextKit2Coordinator(parent)
        let view = NSTextView()
        view.string = "x"
        XCTAssertFalse(coordinator.textView(view, shouldChangeTextIn: NSRange(location: 1, length: 0), replacementString: "a\nb"))
        XCTAssertFalse(coordinator.textView(view, shouldChangeTextIn: NSRange(location: 9, length: 0), replacementString: "a"))
        XCTAssertEqual(reasons, [.multipleLines, .invalidRange])
        XCTAssertNil(PracticeText.InputRejection.invalidRange.message)
    }

    #endif

    func testSwitchingScriptResetsInputEvenForSameText() throws {
        let model = TypingScreenViewModel()
        try model.updatePlaceholder(with: "abc")
        let oldID = model.sessionID
        model.editorText = "ab"
        try model.updatePlaceholder(with: "abc")
        XCTAssertEqual(model.editorText, "")
        XCTAssertNotEqual(model.sessionID, oldID)
        XCTAssertThrowsError(try model.updatePlaceholder(with: "  "))
        XCTAssertEqual(model.placeholderText, "abc")
    }

    func testInMemoryLibrarySaveAndDelete() async throws {
        let persistence = PersistenceController(inMemory: true)
        for _ in 0..<100 where !persistence.isReady && persistence.loadError == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertNil(persistence.loadError)
        XCTAssertTrue(persistence.isReady)
        let context = persistence.container.viewContext
        let item = Item(context: context)
        item.text = "🙂 script"
        try context.save()
        let request = NSFetchRequest<Item>(entityName: "Item")
        XCTAssertEqual(try context.fetch(request).first?.text, "🙂 script")
        context.delete(item)
        try context.save()
        XCTAssertEqual(try context.count(for: request), 0)
    }
}

@MainActor
extension EditorRegressionTests {
    func testSavedLibrarySurvivesReopeningStore() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("TypingPall.sqlite")
        let first = PersistenceController(storeURL: url)
        try await waitForStore(first)
        XCTAssertTrue(first.isReady)
        let item = Item(context: first.container.viewContext)
        item.text = "saved before upgrade 🙂"
        try first.container.viewContext.save()
        for store in first.container.persistentStoreCoordinator.persistentStores {
            try first.container.persistentStoreCoordinator.remove(store)
        }
        let reopened = PersistenceController(storeURL: url)
        try await waitForStore(reopened)
        XCTAssertTrue(reopened.isReady)
        XCTAssertEqual(try reopened.container.viewContext.fetch(NSFetchRequest<Item>(entityName: "Item")).first?.text,
                       "saved before upgrade 🙂")
    }

    func testFailedStoreLoadPreservesOriginalFile() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("TypingPall.sqlite")
        let original = Data("not a valid SQLite store".utf8)
        try original.write(to: url)
        let persistence = PersistenceController(storeURL: url)
        try await waitForStore(persistence)
        XCTAssertFalse(persistence.isReady)
        XCTAssertNotNil(persistence.loadError)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    private func waitForStore(_ persistence: PersistenceController) async throws {
        for _ in 0..<100 where !persistence.isReady && persistence.loadError == nil {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}

@MainActor
final class CommentSkippingTests: XCTestCase {
    func testPythonCommentsDoNotRemoveDivisionStringsOrDocstrings() {
        let source = ["# explanation", "half = 10 // 2 # floor division", "url = 'https://example.com/#anchor'", "text = \"\"\"", "# literal data", "\"\"\""]
        let filtered = CommentFilter.lines(source, language: .python)
        XCTAssertEqual(filtered.map(\.sourceIndex), [1, 2, 3, 4, 5])
        XCTAssertEqual(filtered.map(\.text), ["half = 10 // 2", source[2], source[3], source[4], source[5]])
    }

    func testCppIncludesBlockCommentsAndRawStrings() {
        let source = ["#include <vector>", "/* multi", " * line */", "int value = 1; // note", "auto url = \"https://example.com\";", "auto raw = R\"tag(/* literal */ // text)tag\"; // note"]
        let filtered = CommentFilter.lines(source, language: .cpp)
        XCTAssertEqual(filtered.map(\.sourceIndex), [0, 3, 4, 5])
        XCTAssertEqual(filtered.map(\.text), [source[0], "int value = 1;", source[4], "auto raw = R\"tag(/* literal */ // text)tag\";"])
    }

    func testRustNestedCommentsLifetimesAndRawStrings() {
        let source = ["/* outer /* nested */", "end */", "fn borrow<'a>(text: &'a str) -> &'a str { // note", "let raw = r##\"// data /* */\"##; // note"]
        let filtered = CommentFilter.lines(source, language: .rust)
        XCTAssertEqual(filtered.map(\.text), ["fn borrow<'a>(text: &'a str) -> &'a str {", "let raw = r##\"// data /* */\"##;"])
    }

    func testGoRawStringsAndPlainText() {
        let source = ["text := `", "// data", "` // comment", "// explanation"]
        XCTAssertEqual(CommentFilter.lines(source, language: .go).map(\.text), [source[0], source[1], "`"])
        XCTAssertEqual(CommentFilter.lines(source, language: .plainText).map(\.text), source)
    }

    func testRubyCommentsAndStrings() {
        let source = ["# explanation", "total = sum # inline comment", "url = 'https://example.com/#anchor'", "pattern = \"#literal\""]
        let filtered = CommentFilter.lines(source, language: .ruby)
        XCTAssertEqual(filtered.map(\.sourceIndex), [1, 2, 3])
        XCTAssertEqual(filtered.map(\.text), ["total = sum", source[2], source[3]])
    }

    func testShellCommentsAndStrings() {
        let source = ["# find files", "find . -name \"*.log\" # only logs", "grep -r 'error #1' /var/log"]
        let filtered = CommentFilter.lines(source, language: .shell)
        XCTAssertEqual(filtered.map(\.sourceIndex), [1, 2])
        XCTAssertEqual(filtered.map(\.text), ["find . -name \"*.log\"", source[2]])
    }

    func testCodeLanguageExtensions() {
        XCTAssertEqual(CodeLanguage.from(fileExtension: "rb"), .ruby)
        XCTAssertEqual(CodeLanguage.from(fileExtension: "sh"), .shell)
        XCTAssertEqual(CodeLanguage.from(fileExtension: "bash"), .shell)
        XCTAssertEqual(CodeLanguage.from(fileExtension: "zsh"), .shell)
        XCTAssertEqual(CodeLanguage.from(fileExtension: "lean"), .lean4)
    }

    func testLean4CommentsAndHighlighting() {
        let source = [
            "-- header comment",
            "/- nested /- block -/ comment -/",
            "theorem t (n : Nat) : n = n := by -- inline",
            "    rfl"
        ]
        let filtered = CommentFilter.lines(source, language: .lean4)
        XCTAssertEqual(filtered.map(\.sourceIndex), [2, 3])
        XCTAssertEqual(filtered.map(\.text), ["theorem t (n : Nat) : n = n := by", "    rfl"])
        let highlighted = CodeHighlighter.highlight(source, language: .lean4)
        XCTAssertEqual(highlighted.count, 4)
    }

    #if os(macOS)
    func testLeanVerifierChecksSnippetsWhenToolchainPresent() throws {
        XCTAssertEqual(LeanVerifier.verify("theorem ok : True := trivial\n", executablePath: nil), .toolchainUnavailable)
        XCTAssertEqual(LeanVerifier.interpretOutput(status: 0, stdout: "", stderr: ""), .passed)
        XCTAssertEqual(
            LeanVerifier.interpretOutput(status: 0, stdout: "", stderr: "warning: declaration uses 'sorry'"),
            .failed(diagnostics: "warning: declaration uses 'sorry'")
        )
        XCTAssertEqual(
            LeanVerifier.interpretOutput(status: 1, stdout: "<stdin>:1:1: error: unsolved goals", stderr: ""),
            .failed(diagnostics: "<stdin>:1:1: error: unsolved goals")
        )
        guard let leanPath = LeanVerifier.resolveLeanExecutable() else {
            throw XCTSkip("Lean 4 toolchain unavailable in sandboxed test host")
        }
        XCTAssertEqual(
            LeanVerifier.verify("theorem ok (n : Nat) : n + 0 = n := by rfl\n", executablePath: leanPath),
            .passed
        )
        let bad = LeanVerifier.verify("theorem bad (n : Nat) : n = n + 1 := by rfl\n", executablePath: leanPath)
        if case .failed(let diagnostics) = bad {
            XCTAssertFalse(diagnostics.isEmpty)
        } else {
            XCTFail("Expected LeanVerifier to fail on invalid proof, got \(bad)")
        }
    }
    #endif

    func testCommentsAreSkippedEvenWithTheOldPreferenceDisabled() throws {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "skipPracticeComments")
        let model = TypingScreenViewModel(defaults: defaults)
        try model.updatePlaceholder(with: "# intro\na = 1 # note\n# end", language: .python)
        XCTAssertEqual(model.currentLineIndex, 1)
        XCTAssertEqual(model.practiceLines.count, 1)
        XCTAssertEqual(model.currentLine, "a = 1")
        model.editorText = "a = 1"
        XCTAssertTrue(model.advanceLine())
        XCTAssertEqual(model.completedLineCount, 1)
        try model.updatePlaceholder(with: "# only a comment\n\n   ", language: .python)
        XCTAssertFalse(model.hasPracticeLines)
        XCTAssertFalse(model.advanceLine())
        XCTAssertFalse(model.isComplete)
    }

    func testBundledCatalogIsCompleteAndEveryLessonHasPracticeCode() throws {
        let lessons = try PracticeCatalog.load()
        XCTAssertEqual(PracticeCatalog.lessons.count, lessons.count)
        XCTAssertEqual(Set(lessons.map(\.id)).count, lessons.count)
        XCTAssertGreaterThanOrEqual(lessons.filter { $0.category == "Python interview patterns" }.count, 13)
        XCTAssertFalse(lessons.contains { $0.category.first?.isNumber == true }, "Category names carry no counts")
        for lesson in lessons {
            XCTAssertFalse(lesson.summary.isEmpty)
            let source = try PracticeText.validated(lesson.code, tabSpaces: 4).components(separatedBy: "\n")
            XCTAssertFalse(CommentFilter.lines(source, language: lesson.language).isEmpty, lesson.id)
        }
    }
}

@MainActor
extension EditorRegressionTests {
    func testLegacyLibraryMigratesWithoutLosingScripts() async throws {
        let modelDirectory = try XCTUnwrap(Bundle.main.url(forResource: "TypingPall", withExtension: "momd"))
        let legacyModel = try XCTUnwrap(NSManagedObjectModel(contentsOf: modelDirectory.appendingPathComponent("TypingPall.mom")))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("TypingPall.sqlite")
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: legacyModel)
        let store = try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url)
        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator
        let item = NSEntityDescription.insertNewObject(forEntityName: "Item", into: context)
        item.setValue("legacy script", forKey: "text")
        try context.save()
        try coordinator.remove(store)
        let migrated = PersistenceController(storeURL: url)
        try await waitForStore(migrated)
        XCTAssertTrue(migrated.isReady)
        XCTAssertNil(migrated.loadError)
        let saved = try XCTUnwrap(migrated.container.viewContext.fetch(NSFetchRequest<Item>(entityName: "Item")).first)
        XCTAssertEqual(saved.text, "legacy script")
        XCTAssertNil(saved.language)
        saved.language = CodeLanguage.python.rawValue
        try migrated.container.viewContext.save()
    }
}
