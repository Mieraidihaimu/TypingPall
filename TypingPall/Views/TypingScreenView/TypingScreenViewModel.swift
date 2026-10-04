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

    @Published var editorText = "" {
        didSet { if editorText != oldValue { submitFeedback = nil; hintOffset = nil } }
    }
    @Published var isShowingPlaceholderText = false
    @Published var isShowingHistoryUploads = false
    @Published private(set) var placeholderText = starterPattern
    @Published private(set) var lines = starterPattern.components(separatedBy: "\n")
    @Published private(set) var practiceLines: [PracticeLine] = []
    @Published private(set) var practicePosition = 0
    @Published private(set) var language: CodeLanguage = .cpp
    @Published private(set) var lessonTitle = "C++ binary search"
    @Published private(set) var lessonSummary = "Narrow a half-open interval, one line at a time."
    @Published private(set) var currentLessonID: String?
    private(set) var isStarterPattern = true
    @Published private(set) var skipComments: Bool
    @Published var draftLanguage: CodeLanguage { didSet { defaults.set(draftLanguage.rawValue, forKey: "ux.lastScriptLanguage") } }
    private let defaults: UserDefaults
    @Published private(set) var isComplete = false
    @Published var temPlaceholderText = ""
    @Published var lastKeyboardType: String?
    @Published private(set) var sessionID = UUID()
    @Published private(set) var mode: PracticeMode = .copy
    @Published private(set) var lineAttempts: [Int: LineAttempt] = [:]   // current attempt, keyed by source line
    @Published private(set) var revealedLength = 0                        // characters of the current line shown by hints
    @Published private(set) var hintOffset: Int?
    @Published private(set) var submitFeedback: String?
    @Published private(set) var lastSummary: AttemptSummary?
    @Published private(set) var selfRating: SelfRating?
    @Published private(set) var bugHunt: BugHunt?
    @Published private(set) var contrast: ContrastPair?
    @AppStorage("typingFontSize") var textViewFontSize: Double = 25
    @AppStorage("isShowingKeyboard") var isShowingKeyboard = false
    @AppStorage("tabEqualsToSpaces") private var spaces: Double = 4
    private(set) var sessionTabSpaces = 4
    private var lesson: PracticeLesson?
    private var scaffoldLineIndices: Set<Int> = []
    private var weakLineIndices: Set<Int> = []
    private var resumeMode: PracticeMode?   // the learner's mode before a bug hunt or contrast pair

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        skipComments = defaults.object(forKey: "skipPracticeComments") as? Bool ?? true
        draftLanguage = CodeLanguage(rawValue: defaults.string(forKey: "ux.lastScriptLanguage") ?? "") ?? .plainText
        sessionTabSpaces = PracticeText.tabWidth(spaces)
        rebuildPracticeLines()
    }

    var hasPracticeLines: Bool { !practiceLines.isEmpty }
    var currentLesson: PracticeLesson? { lesson }
    var nextLesson: PracticeLesson? { nextLesson(in: PracticeCatalog.lessons) }
    var lessonSubtitle: String {
        currentLesson?.category ?? (isStarterPattern ? "Starter pattern" : "My script · \(language.title)")
    }
    /// Graded modes show the lesson's invariant or mantra, never its summary or drill prompts.
    var displayedSummary: String {
        mode.isGraded ? (lesson?.invariant ?? lesson?.mantra ?? "Recall each hidden line; comments stay visible as cues.") : lessonSummary
    }
    var currentLineIndex: Int { hasPracticeLines ? practiceLines[practicePosition].sourceIndex : 0 }
    var currentLine: String {
        guard hasPracticeLines else { return "" }
        // Keep the source indentation visible, but start practice at the first content character.
        return String(practiceLines[practicePosition].text.drop(while: { $0 == " " || $0 == "\t" }))
    }
    var isLineMatched: Bool { hasPracticeLines && editorText == currentLine }
    /// Graded modes also accept a line that differs only in spacing; Copy stays exact.
    private var isCurrentLineAccepted: Bool {
        isLineMatched || (mode.isGraded && hasPracticeLines && editorText.filter { !$0.isWhitespace } == currentLine.filter { !$0.isWhitespace })
    }
    /// The target strip: the line in Copy, else bars plus hint-revealed text.
    var visibleTarget: String {
        mode.isGraded ? MaskedLine.placeholder(source: currentLine, typed: currentLine, revealed: revealedLength) : currentLine
    }
    /// Replaces live guidance in graded modes.
    var learningStatus: String? {
        guard mode.isGraded, !isComplete else { return nil }
        if bugHunt?.phase == .finding { return "Click the line with the planted bug." }
        guard hasPracticeLines else { return "Only comments remain. Switch to Copy (⌘1) to practice them." }
        if bugHunt != nil { return submitFeedback ?? "Type the corrected line, then press Return." }
        return submitFeedback ?? (revealedLength > 0 ? "Hint shown. Type the line, then press Return to check."
                                                     : "Type the hidden line from memory, then press Return to check.")
    }
    var grade: ReviewGrade? { lastSummary?.grade(selfRating) }
    var completedLineCount: Int { isComplete ? practiceLines.count : practicePosition }
    var progressText: String {
        switch bugHunt?.phase {
        case .finding?: return "Find the bug"
        case .fixing?: return "Fix the bug"
        case .solved?: return "Bug fixed"
        case nil: break
        }
        let progress = !hasPracticeLines ? "No code to practice" : isComplete ? "Pattern complete" : "\(practicePosition + 1) of \(practiceLines.count)"
        return mode.isGraded ? "\(mode.title) · \(progress)" : progress
    }
    var isLastPracticeLine: Bool { practicePosition == practiceLines.count - 1 }
    var skippedLineIndices: Set<Int> { Set(lines.indices).subtracting(practiceLines.map(\.sourceIndex)) }
    /// Unfinished typed lines in graded modes.
    var maskedLineIndices: Set<Int> {
        mode.isGraded && !isComplete && hasPracticeLines ? Set(practiceLines[practicePosition...].map(\.sourceIndex)) : []
    }
    var referenceRows: [ReferenceRow] {
        let current = hasPracticeLines && !isComplete ? currentLineIndex : nil
        if let hunt = bugHunt {   // the whole planted version stays readable
            return lines.indices.map { index in
                let marker: ReferenceRow.Marker? = hunt.wrongGuesses.contains(index) ? .notTheBug
                    : hunt.phase != .finding && index == hunt.bugLine ? .plantedBug : nil
                return ReferenceRow(sourceIndex: index, text: lines[index], isCurrent: index == current, marker: marker)
            }
        }
        let skipped = skippedLineIndices, masked = maskedLineIndices
        let typed = Dictionary(uniqueKeysWithValues: practiceLines.map { ($0.sourceIndex, $0.text) })
        return lines.indices.map { index in
            guard masked.contains(index), let text = typed[index] else {
                return ReferenceRow(sourceIndex: index, text: lines[index], isCurrent: index == current, isSkipped: skipped.contains(index))
            }
            // The hidden text never reaches the view.
            let placeholder = MaskedLine.placeholder(source: lines[index], typed: String(text.drop(while: { $0 == " " || $0 == "\t" })),
                                                     revealed: index == current ? revealedLength : 0)
            return ReferenceRow(sourceIndex: index, text: placeholder, isCurrent: index == current, isMasked: true)
        }
    }

    func nextLesson(in catalog: [PracticeLesson]) -> PracticeLesson? {
        guard let currentLessonID else { return isStarterPattern ? catalog.first : nil }
        guard let index = catalog.firstIndex(where: { $0.id == currentLessonID }), index + 1 < catalog.count else { return nil }
        return catalog[index + 1]
    }

    func setSkipComments(_ enabled: Bool) {
        guard skipComments != enabled else { return }
        skipComments = enabled
        defaults.set(enabled, forKey: "skipPracticeComments")
        rebuildPracticeLines(keepingPosition: true)
    }

    func setLanguage(_ value: CodeLanguage) {
        guard language != value else { return }
        language = value
        rebuildPracticeLines(keepingPosition: true)
    }

    /// Restarts the attempt with the lines the mode types.
    func setMode(_ value: PracticeMode) {
        guard mode != value else { return }
        mode = value
        rebuildPracticeLines()
    }

    func loadLesson(_ lesson: PracticeLesson) throws {
        try load(lesson.code, language: lesson.language, lesson: lesson)
    }

    func updatePlaceholder(with text: String, language: CodeLanguage = .plainText) throws {
        try load(text, language: language, lesson: nil)
    }

    /// Shows the lesson with one planted bug; the learner clicks the wrong line, then types the fix from memory.
    func startBugHunt(_ lesson: PracticeLesson, mutationIndex: Int? = nil) throws {
        guard let count = lesson.mutations?.count, count > 0,
              let hunt = BugHunt(lesson: lesson, mutationIndex: mutationIndex ?? Int.random(in: 0..<count)) else { return }
        try loadLesson(lesson)
        resumeMode = mode
        setMode(.recall)          // hidden target, no live colouring, check on Return
        bugHunt = hunt
        lines = hunt.lines
        rebuildPracticeLines()
    }

    func selectReferenceLine(_ index: Int) {
        guard var hunt = bugHunt else { return }
        let found = hunt.select(line: index)
        bugHunt = hunt
        if found { rebuildPracticeLines() }
    }

    /// Practices the variant with only the lines that differ from its base hidden and typed.
    func startContrast(_ pair: ContrastPair) throws {
        var variant = pair.variant
        variant.keyLineIndices = pair.differingLines.sorted()
        try loadLesson(variant)   // ends any hunt or earlier pair and restores the suspended mode
        resumeMode = mode
        setMode(.keyLines)
        contrast = pair
    }

    var contrastBaseRows: [ReferenceRow] {
        guard let pair = contrast else { return [] }
        return pair.base.sourceLines.enumerated().map { index, text in
            ReferenceRow(sourceIndex: index, text: text, marker: pair.baseMarkedLines.contains(index) ? .differs : nil)
        }
    }

    private func endPatternSession() {
        bugHunt = nil
        contrast = nil
        if let mode = resumeMode {
            resumeMode = nil
            setMode(mode)
        }
    }

    private func load(_ text: String, language: CodeLanguage, lesson: PracticeLesson?) throws {
        let width = PracticeText.tabWidth(spaces)
        let validated = try PracticeText.validated(text, tabSpaces: width)
        endPatternSession()
        sessionTabSpaces = width
        self.language = language
        self.lesson = lesson
        currentLessonID = lesson?.id
        isStarterPattern = false
        lessonTitle = lesson?.title ?? "Your pattern"
        lessonSummary = lesson?.summary ?? "Practice this code one line at a time."
        placeholderText = validated
        lines = validated.components(separatedBy: "\n")
        // A final newline terminates the last line; it isn't another exercise.
        if lines.last == "" { lines.removeLast() }
        scaffoldLineIndices = Set(lesson?.scaffoldLineIndices ?? [])
        weakLineIndices = []
        rebuildPracticeLines()
    }

    /// Return advances only after the line is accepted; leading indentation is skipped.
    @discardableResult
    func advanceLine() -> Bool {
        guard !isComplete, hasPracticeLines else { return false }
        guard isCurrentLineAccepted else {
            if !editorText.isEmpty { lineAttempts[currentLineIndex, default: LineAttempt()].wrongSubmits += 1 }
            submitFeedback = SubmitFeedback.message(typed: editorText, target: currentLine,
                                                    explanation: lesson?.knownMistake(on: currentLineIndex, typed: editorText)?.explanation)
            return false
        }
        if isLastPracticeLine {
            complete()
        } else {
            practicePosition += 1
            revealedLength = 0
            resetInput()
        }
        return true
    }

    func repeatLine() {
        if !editorText.isEmpty, hasPracticeLines, !isComplete { lineAttempts[currentLineIndex, default: LineAttempt()].repeated = true }
        resetInput()
    }

    /// Graded modes reveal through the next token, and the third hint reveals the line; Copy points at the next character.
    func revealHint() {
        guard hasPracticeLines, !isComplete, !(mode.isGraded && revealedLength >= currentLine.count) else { return }
        let target = currentLine
        let typedPrefix = LineDiff(typed: editorText, target: target).firstMismatch ?? editorText.count
        guard typedPrefix < target.count else { return }   // everything typed so far is right; nothing to hint
        lineAttempts[currentLineIndex, default: LineAttempt()].hints += 1
        guard mode.isGraded else { hintOffset = typedPrefix; return }
        let hints = lineAttempts[currentLineIndex]?.hints ?? 1
        revealedLength = hints >= 3 ? target.count : max(revealedLength, CodeTokens.revealEnd(in: target, from: max(typedPrefix, revealedLength)))
        if revealedLength >= target.count { lineAttempts[currentLineIndex]?.revealed = true }
    }

    private func resetInput() {
        editorText = ""
        lastKeyboardType = nil
        hintOffset = nil
        submitFeedback = nil
        isComplete = false
        sessionID = UUID()
    }

    private func complete() {
        isComplete = true
        bugHunt?.markSolved()
        let summary = AttemptSummary(mode: mode, lines: Dictionary(uniqueKeysWithValues: practiceLines.map {
            ($0.sourceIndex, lineAttempts[$0.sourceIndex] ?? LineAttempt())
        }))
        lastSummary = summary
        if mode.isGraded { weakLineIndices = weakLineIndices.subtracting(summary.cleanLines).union(summary.weakLines) }
    }

    /// An optional rating of the finished graded attempt; it can be changed.
    func rate(_ rating: SelfRating) {
        guard isComplete, lastSummary?.mode.isGraded == true else { return }
        selfRating = rating
    }

    private func rebuildPracticeLines(keepingPosition: Bool = false) {
        if let hunt = bugHunt {
            practiceLines = hunt.phase == .finding ? [] : [PracticeLine(sourceIndex: hunt.bugLine, text: hunt.originalLine)]
            return restart()
        }
        let anchor = keepingPosition && hasPracticeLines && !isComplete ? currentLineIndex : nil
        // Graded modes keep comments visible as cues and never type them.
        let code = CommentFilter.lines(lines, language: language, skippingComments: skipComments || mode.isGraded)
            .filter { !scaffoldLineIndices.contains($0.sourceIndex) }
        practiceLines = PracticeLineSelection.lines(for: mode, from: code, keyLines: lesson?.keyLineIndices ?? [], weakLines: weakLineIndices)
        guard let anchor, let position = practiceLines.firstIndex(where: { $0.sourceIndex >= anchor }) else { return restart() }
        practicePosition = position
        revealedLength = 0
        resetInput()
    }

    func restart() {
        practicePosition = 0
        lineAttempts = [:]
        revealedLength = 0
        lastSummary = nil
        selfRating = nil
        resetInput()
    }
}
