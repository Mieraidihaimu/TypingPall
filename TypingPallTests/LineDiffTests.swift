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
