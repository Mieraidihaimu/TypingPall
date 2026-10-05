import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct TypingScreenView: View {
    private enum LibraryAction { case addScript, importFile }

    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = TypingScreenViewModel()
    @State private var isImporting = false
    @State private var isShowingOptions = false
    @State private var isShowingDrill = false
    @State private var isShowingQuickSwitcher = false
    @State private var pendingLibraryAction: LibraryAction?
    @State private var errorMessage: String?
    @State private var contrastStatement = ""   // unsaved
    @State private var isComparingMantras = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                Picker("Practice Mode", selection: Binding(get: { viewModel.mode }, set: { viewModel.setMode($0) })) {
                    ForEach(PracticeMode.allCases) { mode in
                        Text("\(mode.title) (⌘\(mode.rawValue + 1))").tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(maxWidth: 360)
                .accessibilityIdentifier("practiceLadderPicker")
                .disabled(viewModel.bugHunt != nil)

                Spacer()

                Label(viewModel.progressText, systemImage: viewModel.isComplete ? "checkmark.circle" : "text.line.first.and.arrowtriangle.forward")
                    .font(.headline)
                    .accessibilityIdentifier("patternProgress")
            }

            HStack(alignment: .firstTextBaseline) {
                Text(viewModel.displayedSummary)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer()
            }

            ProgressView(value: Double(viewModel.completedLineCount), total: Double(max(1, viewModel.practiceLines.count)))
                .accessibilityLabel("Lines practiced")
                .accessibilityValue(viewModel.progressText)
                .animation(.easeInOut(duration: 0.2), value: viewModel.completedLineCount)
            if let hunt = viewModel.bugHunt, hunt.phase != .solved {
                BugHuntBanner(hunt: hunt)
            }
            if let pair = viewModel.contrast {
                ContrastReferenceView(baseTitle: pair.base.title, baseRows: viewModel.contrastBaseRows,
                                      variantTitle: pair.variant.title, variantRows: viewModel.referenceRows,
                                      fontSize: safeFontSize, currentIndex: viewModel.currentLineIndex, contentKey: viewModel.placeholderText)
            } else {
                ReferenceCodeView(rows: viewModel.referenceRows, fontSize: safeFontSize,
                                  currentIndex: viewModel.currentLineIndex, contentKey: viewModel.placeholderText,
                                  language: viewModel.language,
                                  onSelectRow: viewModel.bugHunt?.phase == .finding ? viewModel.selectReferenceLine : nil)
            }
            if viewModel.isComplete {
                CompletionCard(title: viewModel.lessonTitle, nextLesson: viewModel.nextLesson,
                               isUserScript: !viewModel.isStarterPattern && viewModel.currentLessonID == nil,
                               accessoryOwnsDefaultAction: viewModel.contrast != nil,
                               onNext: { if let next = viewModel.nextLesson { loadLesson(next) } },
                               onRepeat: { viewModel.restart() },
                               onLibrary: { viewModel.isShowingHistoryUploads = true }) {
                    completionAccessory
                }
            } else {
                PracticeInputPanel(viewModel: viewModel, fontSize: safeFontSize)
            }
            if viewModel.isShowingKeyboard {
                KeyboardLayoutView(typedLetter: $viewModel.lastKeyboardType)
                    .frame(height: 250)
                    .accessibilityHidden(true)
            }
        }
        .padding(24)
        .background(modeShortcuts)
        .frame(minWidth: 760, idealWidth: 900, minHeight: 620, idealHeight: 740)
        .navigationTitle(viewModel.lessonTitle)
        .modifier(SubtitleModifier(text: viewModel.lessonSubtitle))
        .onChange(of: viewModel.editorText) { text in
            viewModel.lastKeyboardType = text.last.map(String.init)
        }
        .sheet(isPresented: $viewModel.isShowingPlaceholderText) { scriptSheet }
        .sheet(isPresented: $isShowingQuickSwitcher) {
            QuickSwitcherPaletteView(lessons: PracticeCatalog.lessons) { loadLesson($0) }
        }
        .sheet(isPresented: $isShowingDrill) {
            RecognitionDrillView { lesson in
                do { try viewModel.loadLesson(lesson); viewModel.setMode(.recall) }
                catch { errorMessage = error.localizedDescription }
            }
            .frame(minWidth: 560, minHeight: 460)
        }
        .sheet(isPresented: $viewModel.isShowingHistoryUploads, onDismiss: runPendingLibraryAction) {
            HistoryUploadsView(onSelect: { text, language in load(text, language: language) }, onSelectLesson: loadLesson,
                               onAddScript: { pendingLibraryAction = .addScript }, onImport: { pendingLibraryAction = .importFile },
                               onSelectBugHunt: { startBugHunt($0) }, onSelectContrast: startContrast)
                .frame(minWidth: 680, idealWidth: 860, minHeight: 460, idealHeight: 600)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first else { return }
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let handle = try FileHandle(forReadingFrom: url)
                defer { try? handle.close() }
                let data = try handle.read(upToCount: PracticeText.maximumFileBytes + 1) ?? Data()
                guard data.count <= PracticeText.maximumFileBytes else { throw PracticeText.ValidationError.tooLarge }
                guard let text = String(data: data, encoding: .utf8) else { throw PracticeText.ValidationError.binary }
                try saveAndLoad(text, language: CodeLanguage.from(fileExtension: url.pathExtension))
            } catch { errorMessage = error.localizedDescription }
        }
        .alert("Couldn’t complete that action", isPresented: Binding(get: { errorMessage != nil && !viewModel.isShowingPlaceholderText }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .toolbar {
            ToolbarItemGroup {
                Button { isShowingQuickSwitcher = true } label: { Label("Quick Switcher", systemImage: "magnifyingglass") }
                    .keyboardShortcut("k", modifiers: .command)
                    .accessibilityIdentifier("quickSwitcher")
                Button { isShowingOptions = true } label: { Label("Options", systemImage: "slider.horizontal.3") }
                    .accessibilityIdentifier("practiceOptions")
                    .popover(isPresented: $isShowingOptions, arrowEdge: .bottom) { PracticeOptionsPopover(viewModel: viewModel) }
                Button { viewModel.restart() } label: { Label("Repeat Pattern", systemImage: "arrow.counterclockwise") }
                    .keyboardShortcut("r", modifiers: .command)
                    .accessibilityIdentifier("restartPractice")
                Button(action: showScriptSheet) { Label("Add Script", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button { isImporting = true } label: { Label("Import File", systemImage: "square.and.arrow.down") }
                    .keyboardShortcut("o", modifiers: .command)
                Button { viewModel.isShowingHistoryUploads = true } label: { Label("Library", systemImage: "books.vertical") }
                    .keyboardShortcut("l", modifiers: .command)
                Button { isShowingDrill = true } label: { Label("Which Pattern?", systemImage: "questionmark.circle") }
                    .keyboardShortcut("d", modifiers: [.command, .shift])
                    .accessibilityIdentifier("whichPattern")
            }
        }
    }

    private var safeFontSize: Double {
        viewModel.textViewFontSize.isFinite ? min(30, max(12, viewModel.textViewFontSize)) : 25
    }

    // Interim ⌘1–⌘3 until menus exist; opacity 0 (not hidden) keeps the shortcuts registered.
    private var modeShortcuts: some View {
        ZStack {
            ForEach(PracticeMode.allCases) { mode in
                Button(mode.title) { viewModel.setMode(mode) }
                    .keyboardShortcut(KeyEquivalent(Character(String(mode.rawValue + 1))), modifiers: .command)
            }
            Button("Quick Switcher") { isShowingQuickSwitcher = true }
                .keyboardShortcut("p", modifiers: .command)
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private var scriptSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add a pattern to practice").font(.title2).fontWeight(.semibold)
            Text("Paste an algorithm, language idiom, or concurrency pattern. Up to 20,000 characters.").foregroundColor(.secondary)
            Picker("Language", selection: $viewModel.draftLanguage) {
                ForEach(CodeLanguage.allCases) { Text($0.title).tag($0) }
            }
            TextEditor(text: $viewModel.temPlaceholderText)
                .font(.system(.body, design: .monospaced))
                .accessibilityIdentifier("scriptText")
                .frame(height: 280)
            if let errorMessage { Text(errorMessage).foregroundColor(.red).font(.caption) }
            HStack {
                Button("Cancel") { viewModel.isShowingPlaceholderText = false }.keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save & Practice") {
                    do {
                        try saveAndLoad(viewModel.temPlaceholderText, language: viewModel.draftLanguage)
                        viewModel.isShowingPlaceholderText = false
                    } catch { errorMessage = error.localizedDescription }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.temPlaceholderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(24).frame(width: 620)
    }

    private func saveAndLoad(_ text: String, language: CodeLanguage) throws {
        let width = PracticeText.tabWidth(UserDefaults.standard.object(forKey: "tabEqualsToSpaces") as? Double ?? 4)
        let normalized = try PracticeText.validated(text, tabSpaces: width)
        let item = Item(context: viewContext)
        item.timestamp = Date()
        item.text = normalized
        item.language = language.rawValue
        do { try viewContext.save() }
        catch { viewContext.rollback(); throw error }
        load(normalized, language: language)
    }

    private func load(_ text: String, language: CodeLanguage) {
        do {
            try viewModel.updatePlaceholder(with: text, language: language)
        } catch { errorMessage = error.localizedDescription }
    }

    private func loadLesson(_ lesson: PracticeLesson) {
        do { try viewModel.loadLesson(lesson) }
        catch { errorMessage = error.localizedDescription }
    }

    private func startBugHunt(_ lesson: PracticeLesson, mutationIndex: Int? = nil) {
        do { try viewModel.startBugHunt(lesson, mutationIndex: mutationIndex) }
        catch { errorMessage = error.localizedDescription }
    }

    private func startContrast(_ pair: ContrastPair) {
        contrastStatement = ""
        isComparingMantras = false
        do { try viewModel.startContrast(pair) }
        catch { errorMessage = error.localizedDescription }
    }

    @ViewBuilder private var completionAccessory: some View {
        if let hunt = viewModel.bugHunt, hunt.phase == .solved, let lesson = viewModel.currentLesson {
            VStack(alignment: .leading, spacing: 8) {
                if hunt.wrongGuesses.isEmpty {
                    Text("Found on the first click.").font(.headline)
                } else {
                    Text("Found after checking ^[\(hunt.wrongGuesses.count) other line](inflect: true).").font(.headline)
                }
                Text(hunt.mutation.explanation)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("bugExplanation")
                HStack {
                    if (lesson.mutations?.count ?? 0) > 1 {
                        Button("Another Bug") {
                            let others = (lesson.mutations ?? []).indices.filter { lesson.mutations?[$0] != hunt.mutation }
                            startBugHunt(lesson, mutationIndex: others.randomElement())
                        }
                    }
                    Button("Practice Lesson") { loadLesson(lesson) }
                }
            }
        } else if let pair = viewModel.contrast {
            VStack(alignment: .leading, spacing: 8) {
                TextField("In one line, what's the difference?", text: $contrastStatement)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("contrastStatement")
                if isComparingMantras {
                    HStack(alignment: .top, spacing: 16) {
                        mantra(of: pair.base)
                        mantra(of: pair.variant)
                    }
                } else {
                    Button("Compare") { isComparingMantras = true }
                        .keyboardShortcut(.defaultAction)
                        .accessibilityIdentifier("contrastCompare")
                }
            }
        } else if viewModel.bugHunt == nil {
            AttemptOutcomeView(viewModel: viewModel)
            HStack(spacing: 12) {
                if let lesson = viewModel.currentLesson, let pair = ContrastPair.pairs(for: lesson).first {
                    Button("Contrast with \(pair.variant.title)") { startContrast(pair) }
                        .accessibilityIdentifier("completionContrast")
                }
                if let lesson = viewModel.currentLesson, (lesson.mutations?.count ?? 0) > 0 {
                    Button("Find the Bug 🐞") { startBugHunt(lesson) }
                        .accessibilityIdentifier("completionFindBug")
                }
            }
        }
    }

    private func mantra(of lesson: PracticeLesson) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(lesson.title).font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
            Text(lesson.mantra ?? lesson.summary).fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func showScriptSheet() {
        errorMessage = nil
        viewModel.temPlaceholderText = ""
        viewModel.isShowingPlaceholderText = true
    }

    // A sheet can't open while the library sheet is still presented.
    private func runPendingLibraryAction() {
        defer { pendingLibraryAction = nil }
        switch pendingLibraryAction {
        case .addScript?: showScriptSheet()
        case .importFile?: isImporting = true
        case nil: break
        }
    }
}

private struct SubtitleModifier: ViewModifier {
    let text: String

    func body(content: Content) -> some View {
        #if os(macOS)
        content.navigationSubtitle(text)
        #else
        content
        #endif
    }
}
