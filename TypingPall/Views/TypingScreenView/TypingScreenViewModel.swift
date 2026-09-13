import SwiftUI

final class TypingScreenViewModel: ObservableObject {
    static let starterPattern = """
    // Binary search: narrow a half-open interval [left, right).
    int lowerBound(const std::vector<int>& values, int target) {
        int left = 0;
        int right = static_cast<int>(values.size());
        while (left < right) {
            int mid = left + (right - left) / 2;
            if (values[mid] < target) {
                left = mid + 1;
            } else {
                right = mid;
            }
        }
        return left;
    }
    """

    @Published var editorText = ""
    @Published var isShowingPlaceholderText = false
    @Published var isShowingHistoryUploads = false
    @Published private(set) var placeholderText = starterPattern
    @Published private(set) var lines = starterPattern.components(separatedBy: "\n")
    @Published private(set) var practiceLines: [PracticeLine] = []
    @Published private(set) var practicePosition = 0
    @Published private(set) var language: CodeLanguage = .cpp
    @Published private(set) var lessonTitle = "C++ binary search"
    @Published private(set) var lessonSummary = "Narrow a half-open interval, one line at a time."
    @Published private(set) var skipComments: Bool
    @Published var draftLanguage: CodeLanguage = .plainText
    private let defaults: UserDefaults
    @Published private(set) var isComplete = false
    @Published var temPlaceholderText = ""
    @Published var lastKeyboardType: String?
    @Published private(set) var sessionID = UUID()
    @AppStorage("typingFontSize") var textViewFontSize: Double = 25
    @AppStorage("isShowingKeyboard") var isShowingKeyboard = false
    @AppStorage("tabEqualsToSpaces") private var spaces: Double = 4
    private(set) var sessionTabSpaces = 4

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        skipComments = defaults.object(forKey: "skipPracticeComments") as? Bool ?? true
        sessionTabSpaces = PracticeText.tabWidth(spaces)
        rebuildPracticeLines()
    }

    var hasPracticeLines: Bool { !practiceLines.isEmpty }
    var currentLineIndex: Int { hasPracticeLines ? practiceLines[practicePosition].sourceIndex : 0 }
    var currentLine: String {
        guard hasPracticeLines else { return "" }
        // Keep the source indentation visible, but start practice at the first content character.
        return String(practiceLines[practicePosition].text.drop(while: { $0 == " " || $0 == "\t" }))
    }
    var isLineMatched: Bool { hasPracticeLines && editorText == currentLine }
    var completedLineCount: Int { isComplete ? practiceLines.count : practicePosition }
    var isLastPracticeLine: Bool { practicePosition == practiceLines.count - 1 }
    var skippedLineIndices: Set<Int> { Set(lines.indices).subtracting(practiceLines.map(\.sourceIndex)) }

    func setSkipComments(_ enabled: Bool) {
        guard skipComments != enabled else { return }
        skipComments = enabled
        defaults.set(enabled, forKey: "skipPracticeComments")
        rebuildPracticeLines()
    }

    func setLanguage(_ value: CodeLanguage) {
        guard language != value else { return }
        language = value
        rebuildPracticeLines()
    }

    func loadLesson(_ lesson: PracticeLesson) throws {
        try updatePlaceholder(with: lesson.code, language: lesson.language)
        lessonTitle = lesson.title
        lessonSummary = lesson.summary
    }

    func updatePlaceholder(with text: String, language: CodeLanguage = .plainText) throws {
        let width = PracticeText.tabWidth(spaces)
        let validated = try PracticeText.validated(text, tabSpaces: width)
        sessionTabSpaces = width
        self.language = language
        lessonTitle = "Your pattern"
        lessonSummary = "Practice this code one line at a time."
        placeholderText = validated
        lines = validated.components(separatedBy: "\n")
        // A final newline terminates the last line; it isn't another exercise.
        if lines.last == "" { lines.removeLast() }
        rebuildPracticeLines()
    }

    /// Return advances only after the line's content matches; leading indentation is skipped.
    @discardableResult
    func advanceLine() -> Bool {
        guard !isComplete, isLineMatched else { return false }
        if isLastPracticeLine {
            isComplete = true
        } else {
            practicePosition += 1
            repeatLine()
        }
        return true
    }

    func repeatLine() {
        editorText = ""
        lastKeyboardType = nil
        isComplete = false
        sessionID = UUID()
    }

    private func rebuildPracticeLines() {
        practiceLines = CommentFilter.lines(lines, language: language, skippingComments: skipComments)
        restart()
    }

    func restart() {
        practicePosition = 0
        repeatLine()
    }
}
