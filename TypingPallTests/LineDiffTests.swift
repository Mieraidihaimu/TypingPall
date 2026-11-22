import AppKit
import Foundation
import SwiftUI
import Testing
@testable import TypingPall

@Suite("LineDiff Engine & UTF-16 Boundary Verification")
struct LineDiffTests {

    @Test(
        "Canonical Unicode equivalence (NFC vs NFD) matches without error",
        arguments: [
            ("let café = 1", "let cafe\u{301} = 1"),
            ("const naïve = true;", "const nai\u{308}ve = true;"),
            ("// résumé", "// re\u{301}sume\u{301}")
        ]
    )
    func unicodeCanonicalEquivalence(expected: String, typed: String) {
        let target = PreparedTargetLine(rawLine: expected)
        let result = LineDiff.evaluate(target: target, typed: typed, tolerance: .strictCharacter)

        #expect(result.errorUTF16Range == nil)
        #expect(result.isComplete == true)
    }

    @Test("Syntax-aware trivia mode ignores optional spaces around operators but preserves string literals")
    func syntaxAwareTriviaMatching() {
        let target = PreparedTargetLine(rawLine: "    int left = 0, right = n - 1;")
        let compactTyped = "int left=0,right=n-1;"

        let strictResult = LineDiff.evaluate(target: target, typed: compactTyped, tolerance: .strictCharacter)
        #expect(strictResult.errorUTF16Range != nil)

        let relaxedResult = LineDiff.evaluate(target: target, typed: compactTyped, tolerance: .syntaxAwareTrivia)
        #expect(relaxedResult.errorUTF16Range == nil)
        #expect(relaxedResult.isComplete == true)

        // Ensure spaces inside string literals are NEVER collapsed
        let stringTarget = PreparedTargetLine(rawLine: #"print("hello  world")"#)
        let wrongStringTyped = #"print("hello world")"#
        let stringResult = LineDiff.evaluate(target: stringTarget, typed: wrongStringTyped, tolerance: .syntaxAwareTrivia)
        #expect(stringResult.errorUTF16Range != nil)
    }

    @Test("Property-based fuzzing: errorUTF16Range never exceeds NSString UTF-16 bounds")
    func fuzzUTF16BoundsSafety() {
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
                #expect(errorRange.location >= 0)
                #expect(NSMaxRange(errorRange) <= utf16Length)
            }
        }
    }

    @Test("Headless visual snapshot capture produces deterministic image")
    @MainActor
    func headlessSnapshotCapture() {
        let view = TextKit2TypingView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
        view.configure(targetLine: "func test() -> Int {", resetToken: 1, fontSize: 16)
        view.appearance = NSAppearance(named: .darkAqua)

        guard let snapshot = view.snapshotImage() else {
            Issue.record("Failed to generate headless snapshot bitmap")
            return
        }

        #expect(snapshot.size.width == 400)
        #expect(snapshot.size.height == 120)
    }

    @Test("Headless visual snapshot of ReferenceCodeView in dark mode")
    @MainActor
    func headlessSnapshotReferenceCodeView() {
        let source = [
            "func binarySearch(values: [Int], target: Int) -> Int {",
            "    var left = 0",
            "    var right = values.count",
            "    return left"
        ]
        let highlighted = CodeHighlighter.highlight(source, language: .swift)
        let rows = source.enumerated().map { index, line in
            ReferenceRow(sourceIndex: index, text: line, isCurrent: index == 1, highlightedText: highlighted[index])
        }
        let view = ReferenceCodeView(
            rows: rows,
            fontSize: 16,
            currentIndex: 1,
            contentKey: "testContent"
        )
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 600, height: 240)
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.layoutSubtreeIfNeeded()

        guard let snapshot = hosting.snapshotImage() else {
            Issue.record("Failed to generate headless snapshot for ReferenceCodeView")
            return
        }

        #expect(snapshot.size.width == 600)
        #expect(snapshot.size.height == 240)
        #expect(snapshot.isValid)
    }

    @Test("Headless visual snapshot of BugHuntBanner in dark mode")
    @MainActor
    func headlessSnapshotBugHuntBanner() {
        let lesson = PracticeLesson(
            id: "snapshot-hunt",
            title: "Snapshot Hunt",
            category: "Algorithms",
            track: .algorithms,
            language: .python,
            summary: "Testing hunt",
            code: "x = 1\ny = 2\nz = 3",
            mutations: [LessonMutation(line: 1, replacement: "y = 99", explanation: "Planted bug for testing")]
        )
        let hunt = BugHunt(lesson: lesson, mutationIndex: 0)!
        let banner = BugHuntBanner(hunt: hunt)

        let hosting = NSHostingView(rootView: banner)
        hosting.frame = NSRect(x: 0, y: 0, width: 500, height: 60)
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.layoutSubtreeIfNeeded()

        guard let snapshot = hosting.snapshotImage() else {
            Issue.record("Failed to generate headless snapshot for BugHuntBanner")
            return
        }

        #expect(snapshot.size.width == 500)
        #expect(snapshot.size.height == 60)
        #expect(snapshot.isValid)
    }

    @Test("Headless visual snapshot of CompletionCard in dark mode")
    @MainActor
    func headlessSnapshotCompletionCard() {
        let card = CompletionCard(
            title: "C++ binary search",
            nextLesson: nil,
            isUserScript: false,
            onNext: {},
            onRepeat: {},
            onLibrary: {}
        ) {
            Text("Completed with 100% accuracy")
        }

        let hosting = NSHostingView(rootView: card)
        hosting.frame = NSRect(x: 0, y: 0, width: 550, height: 180)
        hosting.appearance = NSAppearance(named: .darkAqua)
        hosting.layoutSubtreeIfNeeded()

        guard let snapshot = hosting.snapshotImage() else {
            Issue.record("Failed to generate headless snapshot for CompletionCard")
            return
        }

        #expect(snapshot.size.width == 550)
        #expect(snapshot.size.height == 180)
        #expect(snapshot.isValid)
    }

    @Test("TextKit 2 engine uses rendering attributes without mutating text storage layout")
    @MainActor
    func textKit2RenderingAttributesZeroLayoutInvalidation() {
        let view = TextKit2TypingView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
        view.configure(targetLine: "abcd", resetToken: 1, fontSize: 16, liveFeedback: true)

        view.textView.string = "abxd"
        view.textDidChange(Notification(name: NSText.didChangeNotification, object: view.textView))

        // Ensure TextKit 2 rendering attributes were applied
        let lm = view.textView.textLayoutManager
        #expect(lm != nil)
        if let lm = lm {
            let docRange = lm.documentRange
            var foundErrorAttribute = false
            lm.enumerateRenderingAttributes(from: docRange.location, reverse: false) { _, attrs, _ in
                if attrs[.foregroundColor] != nil || attrs[.underlineStyle] != nil {
                    foundErrorAttribute = true
                    return false
                }
                return true
            }
            #expect(foundErrorAttribute == true)
        }

        // TextContentStorage (raw text attributes) should remain unmutated (zero layout invalidation)
        if let storage = view.textView.textStorage {
            let underline = storage.attribute(.underlineStyle, at: 0, effectiveRange: nil)
            #expect(underline == nil)
        }
    }

    @Test("Active IME composition guards prevent premature diffing and newline submission")
    @MainActor
    func imeMarkedTextGuards() {
        let view = TextKit2TypingView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
        view.configure(targetLine: "cafe", resetToken: 1, fontSize: 16)

        final class TestDelegate: TextKit2TypingViewDelegate {
            var progressUpdates: [DiffResult] = []
            var returnPressed = false
            var rejectedReasons: [PracticeText.InputRejection] = []

            func typingView(_ view: TextKit2TypingView, didUpdateProgress result: DiffResult) {
                progressUpdates.append(result)
            }
            func typingViewDidPressReturn(_ view: TextKit2TypingView) {
                returnPressed = true
            }
            func typingView(_ view: TextKit2TypingView, didRejectInput reason: PracticeText.InputRejection) {
                rejectedReasons.append(reason)
            }
        }

        let delegate = TestDelegate()
        view.delegate = delegate

        // Simulate marked text (active composition)
        view.textView.setMarkedText("caf", selectedRange: NSRange(location: 3, length: 0), replacementRange: NSRange(location: 0, length: 0))
        #expect(view.textView.hasMarkedText() == true)

        // 1. textDidChange must not evaluate or notify delegate while composing
        view.textDidChange(Notification(name: NSText.didChangeNotification, object: view.textView))
        #expect(delegate.progressUpdates.isEmpty)

        // 2. Return key during composition must not submit
        let handledReturn = view.textView(view.textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))
        #expect(handledReturn == false)
        #expect(delegate.returnPressed == false)

        // 3. shouldChangeTextIn must allow IME changes without validation rejection
        let allowed = view.textView(view.textView, shouldChangeTextIn: NSRange(location: 0, length: 3), replacementString: "café\n")
        #expect(allowed == true)
        #expect(delegate.rejectedReasons.isEmpty)

        // Commit composition (unmark) - AppKit's unmarkText commits marked text and triggers textDidChange
        delegate.progressUpdates.removeAll()
        view.textView.unmarkText()
        #expect(view.textView.hasMarkedText() == false)
        #expect(delegate.progressUpdates.count == 1)
    }

    @Test("Deferred feedback suppresses live errors and reveals on Return")
    @MainActor
    func deferredFeedbackBehavior() {
        let view = TextKit2TypingView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
        view.configure(targetLine: "swift", resetToken: 1, fontSize: 16, liveFeedback: false)

        view.textView.string = "swxxx"
        view.textDidChange(Notification(name: NSText.didChangeNotification, object: view.textView))

        // Rendering attributes must NOT be set during typing in deferred mode
        if let lm = view.textView.textLayoutManager {
            var foundError = false
            lm.enumerateRenderingAttributes(from: lm.documentRange.location, reverse: false) { _, attrs, _ in
                if attrs[.foregroundColor] != nil || attrs[.underlineStyle] != nil {
                    foundError = true
                    return false
                }
                return true
            }
            #expect(foundError == false)
        }

        // On Return, error styling is revealed
        let handled = view.textView(view.textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))
        #expect(handled == true)

        if let lm = view.textView.textLayoutManager {
            var foundError = false
            lm.enumerateRenderingAttributes(from: lm.documentRange.location, reverse: false) { _, attrs, _ in
                if attrs[.foregroundColor] != nil || attrs[.underlineStyle] != nil {
                    foundError = true
                    return false
                }
                return true
            }
            #expect(foundError == true)
        }
    }

    @Test("Buffer reset token clears text and rendering attributes")
    @MainActor
    func resetTokenBehavior() {
        let view = TextKit2TypingView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
        view.configure(targetLine: "hello", resetToken: 1, fontSize: 16, liveFeedback: true)
        view.textView.string = "hex"
        view.textDidChange(Notification(name: NSText.didChangeNotification, object: view.textView))

        #expect(view.textView.string == "hex")

        // Increment reset token
        view.configure(targetLine: "world", resetToken: 2, fontSize: 16, liveFeedback: true)
        #expect(view.textView.string == "")

        if let lm = view.textView.textLayoutManager {
            var foundError = false
            lm.enumerateRenderingAttributes(from: lm.documentRange.location, reverse: false) { _, attrs, _ in
                if !attrs.isEmpty {
                    foundError = true
                    return false
                }
                return true
            }
            #expect(foundError == false)
        }
    }
}

// MARK: - Headless Snapshot Testing Helper

extension NSView {
    /// Renders an NSView into a deterministic sRGB bitmap image rep without window attachment.
    @MainActor
    func snapshotImage() -> NSImage? {
        guard bounds.width > 0 && bounds.height > 0 else { return nil }
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return nil }
        rep.colorSpaceName = NSColorSpaceName.calibratedRGB
        cacheDisplay(in: bounds, to: rep)
        let image = NSImage(size: bounds.size)
        image.addRepresentation(rep)
        return image
    }
}
