import XCTest
@testable import TypingPall

final class LessonMetadataDecodingTests: XCTestCase {
    func testLessonWithoutMetadataStillDecodes() throws {
        let json = #"[{"id":"a","title":"A","category":"C","track":"leetcode","language":"python","summary":"S","code":"x = 1"}]"#
        let lesson = try XCTUnwrap(JSONDecoder().decode([PracticeLesson].self, from: Data(json.utf8)).first)
        XCTAssertNil(lesson.family)
        XCTAssertNil(lesson.keyLineIndices)
        XCTAssertNil(lesson.mutations)
    }

    func testMetadataDecodes() throws {
        let json = #"""
        {"id":"b","title":"B","category":"C","track":"lowLevelDesign","language":"python","summary":"S","code":"def f():\n    return 1",
         "family":"binary-search","triggers":["sorted input"],"prompts":["An original scenario."],"invariant":"I",
         "mantra":"M","pitfalls":["P"],"anchors":[{"name":"N","trick":"T"}],"keyLineIndices":[1],
         "scaffoldLineIndices":[0],"contrastWith":["a"],"complexity":{"time":"O(log n)","space":"O(1)"},
         "mutations":[{"line":1,"replacement":"    return 2","explanation":"E"}]}
        """#
        let lesson = try JSONDecoder().decode(PracticeLesson.self, from: Data(json.utf8))
        XCTAssertEqual(lesson.track, .lowLevelDesign)
        XCTAssertEqual(lesson.anchors, [LessonAnchor(name: "N", trick: "T")])
        XCTAssertEqual(lesson.complexity, LessonComplexity(time: "O(log n)", space: "O(1)"))
        XCTAssertEqual(lesson.mutations, [LessonMutation(line: 1, replacement: "    return 2", explanation: "E")])
        XCTAssertEqual(lesson.keyLineIndices, [1])
        XCTAssertEqual(lesson.scaffoldLineIndices, [0])
    }

    func testOneMalformedValueFailsTheWholeCatalog() {
        let json = #"[{"id":"a","title":"A","category":"C","track":"leetcode","language":"python","summary":"S","code":"x","keyLineIndices":["1"]}]"#
        XCTAssertThrowsError(try JSONDecoder().decode([PracticeLesson].self, from: Data(json.utf8)))
    }

    func testATrackIsRequired() {
        let json = #"[{"id":"a","title":"A","category":"C","language":"python","summary":"S","code":"x"}]"#
        XCTAssertThrowsError(try JSONDecoder().decode([PracticeLesson].self, from: Data(json.utf8)))
    }
}

final class LessonValidatorTests: XCTestCase {
    private func lesson(_ id: String = "a", keyLines: [Int]? = nil, scaffold: [Int]? = nil, contrast: [String]? = nil,
                        prompts: [String]? = nil, mutations: [LessonMutation]? = nil, family: String? = "f") -> PracticeLesson {
        PracticeLesson(id: id, title: id, category: "C", track: .leetcode, language: .python, summary: "S",
                       code: "# note\ndef f(values):\n\n    return values", family: family, prompts: prompts,
                       keyLineIndices: keyLines, scaffoldLineIndices: scaffold, contrastWith: contrast, mutations: mutations)
    }

    func testWellFormedMetadataHasNoProblems() {
        let bug = LessonMutation(line: 3, replacement: "    return None", explanation: "Drops the result.")
        XCTAssertEqual(LessonValidator.problems(in: [lesson("a", keyLines: [1, 3], contrast: ["b"], prompts: ["A scenario."], mutations: [bug]),
                                                     lesson("b", contrast: ["a"])]), [])
    }

    func testIndicesMustPointAtTypedLines() {
        XCTAssertEqual(LessonValidator.problems(in: [lesson(keyLines: [0, 2, 9, 1], scaffold: [1, 7])]), [
            "a: keyLineIndices 0 is not a practiced line", "a: keyLineIndices 2 is not a practiced line",
            "a: keyLineIndices 9 is not a practiced line", "a: keyLineIndices 1 is not a practiced line",
            "a: scaffoldLineIndices 7 is out of range"])
    }

    func testContrastMustNameAnotherLesson() {
        XCTAssertEqual(LessonValidator.problems(in: [lesson(contrast: ["a", "missing"])]),
                       ["a: contrastWith a is not another lesson", "a: contrastWith missing is not another lesson"])
    }

    func testMutationsMustChangeATypedLineAndKeepItsIndentation() {
        let mutations = [LessonMutation(line: 0, replacement: "# other", explanation: "E"),
                         LessonMutation(line: 3, replacement: "    return values", explanation: "E"),
                         LessonMutation(line: 3, replacement: "return values[0]", explanation: "E")]
        XCTAssertEqual(LessonValidator.problems(in: [lesson(mutations: mutations)]), [
            "a: mutation 0 is not a practiced line", "a: mutation 3 changes nothing", "a: mutation 3 changes indentation"])
    }

    func testPresentFieldsMustNotBeEmpty() {
        XCTAssertEqual(LessonValidator.problems(in: [lesson(prompts: [])]), ["a: prompts is empty"])
        XCTAssertEqual(LessonValidator.problems(in: [lesson(prompts: [" "])]), ["a: prompts is empty"])
        XCTAssertEqual(LessonValidator.problems(in: [lesson(prompts: ["P"], family: nil)]), ["a: prompts need a family"])
    }
}

final class LessonCatalogContentTests: XCTestCase {
    func testBundledCatalogLoadsCompletelyAndItsMetadataIsValid() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "lessons", withExtension: "json"))
        let raw = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [Any])
        let lessons = try PracticeCatalog.load()
        XCTAssertNil(PracticeCatalog.loadError)
        XCTAssertEqual(lessons.count, raw.count)
        XCTAssertEqual(PracticeCatalog.lessons.map(\.id), lessons.map(\.id))
        XCTAssertEqual(LessonValidator.problems(in: lessons), [])
    }

    func testMissingCatalogReportsAnError() {
        let result = PracticeCatalog.loadResult(bundle: Bundle(for: LessonCatalogContentTests.self))
        XCTAssertTrue(result.lessons.isEmpty)
        XCTAssertNotNil(result.error)
    }

    func testEveryPatternLessonHasRecallMetadata() throws {
        let patterns = try PracticeCatalog.load().filter { $0.track != .languages }
        XCTAssertGreaterThanOrEqual(patterns.filter { $0.track == .lowLevelDesign }.count, 11)
        for lesson in patterns {
            XCTAssertNotNil(lesson.family, lesson.id)
            XCTAssertNotNil(lesson.mantra, lesson.id)
            XCTAssertNotNil(lesson.invariant, lesson.id)
            if lesson.track == .leetcode { XCTAssertNotNil(lesson.complexity, lesson.id) }
            XCTAssertFalse((lesson.keyLineIndices ?? []).isEmpty, lesson.id)
            XCTAssertFalse((lesson.anchors ?? []).isEmpty, lesson.id)
            XCTAssertFalse((lesson.pitfalls ?? []).isEmpty, lesson.id)
            XCTAssertGreaterThanOrEqual(lesson.triggers?.count ?? 0, 2, lesson.id)
            XCTAssertGreaterThanOrEqual(lesson.prompts?.count ?? 0, 2, lesson.id)
        }
    }

    func testKnownMistakeRecognizesATypedPlantedBug() {
        let lesson = PracticeLesson(id: "a", title: "A", category: "C", track: .leetcode, language: .python, summary: "S",
                                    code: "def f(values):\n    while left < right:",
                                    mutations: [LessonMutation(line: 1, replacement: "    while left <= right:", explanation: "E")])
        XCTAssertEqual(lesson.knownMistake(on: 1, typed: "while left <= right:")?.explanation, "E")
        XCTAssertNil(lesson.knownMistake(on: 0, typed: "while left <= right:"))
        XCTAssertNil(lesson.knownMistake(on: 1, typed: "while left < right:"))
    }

    func testSearchTextIncludesTriggers() {
        let lesson = PracticeLesson(id: "m", title: "Monotonic stack", category: "C", track: .leetcode, language: .python, summary: "S",
                                    code: "x = 1", triggers: ["next greater element for every position"])
        XCTAssertTrue(lesson.searchableText.localizedCaseInsensitiveContains("Next Greater"))
        XCTAssertTrue(lesson.searchableText.contains("Python"))
        XCTAssertTrue(lesson.searchableText.contains("LeetCode"))
    }
}

final class LibrarySectionTests: XCTestCase {
    private let catalog = ([("window", .leetcode, "Arrays"), ("strategy", .lowLevelDesign, "Behavioral"),
                            ("heap", .leetcode, "Heaps"), ("state", .lowLevelDesign, "Behavioral"),
                            ("factory", .lowLevelDesign, "Creational"), ("loops", .languages, "Python")] as [(String, LessonTrack, String)])
        .map { id, track, category in
            PracticeLesson(id: id, title: id, category: category, track: track, language: .python, summary: "S", code: "x = 1")
        }
    private func ids(track: LessonTrack? = nil, category: String? = nil, search: String = "") -> [String] {
        PracticeCatalog.sections(of: catalog, track: track, category: category, search: search).flatMap { $0.lessons.map(\.id) }
    }

    func testSectionsGroupEachCategoryInCatalogOrder() {
        let sections = PracticeCatalog.sections(of: catalog, track: nil, category: nil, search: "")
        XCTAssertEqual(sections.map(\.title), ["Arrays", "Behavioral", "Heaps", "Creational", "Python"])
        XCTAssertEqual(sections[1].lessons.map(\.id), ["strategy", "state"])
    }

    func testTrackCategoryAndSearchNarrowTheLessons() {
        XCTAssertEqual(PracticeCatalog.categories(of: catalog, in: .lowLevelDesign), ["Behavioral", "Creational"])
        XCTAssertEqual(ids(track: .lowLevelDesign), ["strategy", "state", "factory"])
        XCTAssertEqual(ids(track: .lowLevelDesign, category: "Creational"), ["factory"])
        XCTAssertEqual(ids(search: "STATE"), ["state"])
        XCTAssertEqual(ids(search: "low-level"), ["strategy", "state", "factory"], "Search matches the track title")
        XCTAssertEqual(ids(track: .languages, search: "state"), [])
    }

    func testBundledCatalogFillsEveryTrackAndKeepsCategoriesInOneTrack() throws {
        let catalog = try PracticeCatalog.load()
        XCTAssertEqual(Set(catalog.map(\.track)), Set(LessonTrack.allCases))
        let tracks = LessonTrack.allCases.map { PracticeCatalog.categories(of: catalog, in: $0) }
        XCTAssertEqual(tracks.joined().count, PracticeCatalog.categories(of: catalog).count)
        XCTAssertEqual(PracticeCatalog.categories(of: catalog, in: .lowLevelDesign),
                       ["Creational patterns", "Structural patterns", "Behavioral patterns", "Design building blocks"])
    }
}

final class ScaffoldPracticeTests: XCTestCase {
    private func makeModel() throws -> TypingScreenViewModel {
        let name = UUID().uuidString
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: name) }
        return TypingScreenViewModel(defaults: try XCTUnwrap(UserDefaults(suiteName: name)))
    }

    func testScaffoldLinesAreShownButNotTyped() throws {
        let model = try makeModel()
        try model.loadLesson(PracticeLesson(id: "s", title: "S", category: "C", track: .leetcode, language: .python, summary: "S",
                                            code: "class Node:\n    pass\n\n# note\ndef f():\n    return 1", scaffoldLineIndices: [0, 1, 2]))
        XCTAssertEqual(model.lines.count, 6)
        XCTAssertEqual(model.practiceLines.map(\.sourceIndex), [4, 5])
        XCTAssertEqual(model.skippedLineIndices, [0, 1, 2, 3])
        model.setSkipComments(false)
        XCTAssertEqual(model.practiceLines.map(\.sourceIndex), [3, 4, 5])
        try model.updatePlaceholder(with: "a\nb\nc")
        XCTAssertEqual(model.practiceLines.count, 3, "Scripts have no scaffold")
    }

    func testBundledFastSlowStartsAtTheFunction() throws {
        let model = try makeModel()
        try model.loadLesson(try XCTUnwrap(PracticeCatalog.lessons.first { $0.id == "py-fast-slow" }))
        XCTAssertEqual(model.currentLine, "def has_cycle(head):")
        XCTAssertEqual(model.practiceLines.count, 8)
    }
}
