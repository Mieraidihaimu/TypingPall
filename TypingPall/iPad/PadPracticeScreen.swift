import SwiftUI
import UniformTypeIdentifiers

struct PadPracticeScreen: View {
    private enum Sheet: String, Identifiable {
        case script, settings
        var id: Self { self }
    }

    @Environment(\.persistenceRepository) private var repository
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @StateObject private var model = TypingScreenViewModel(skipsBlankLines: true)
    @State private var columns: NavigationSplitViewVisibility = .detailOnly
    @State private var compactColumn: NavigationSplitViewColumn = .detail
    @State private var sheet: Sheet?
    @State private var focusAfterSavingDraft = false
    @State private var isImporting = false
    @State private var isSaving = false
    @State private var scriptsRevision = 0
    @State private var error: String?
    @State private var focusRequest = UUID()
    @AppStorage("tabEqualsToSpaces") private var tabSpaces = 4.0

    private var editorActive: Bool {
        scenePhase == .active && sheet == nil && !isImporting && !isSaving && error == nil
            && (horizontalSizeClass != .compact || compactColumn == .detail)
    }

    private var fontSize: Double {
        let size = model.textViewFontSize
        return size.isFinite ? min(30, max(12, size)) : 25
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columns, preferredCompactColumn: $compactColumn) {
            PadLibraryView(scriptsRevision: scriptsRevision, onLesson: load,
                           onScript: { script in
                               performLoad {
                                   try model.updatePlaceholder(with: script.text, language: CodeLanguage(rawValue: script.language) ?? .plainText)
                               }
                           },
                           onAdd: showScript, onImport: { isImporting = true },
                           onClose: { columns = .detailOnly; compactColumn = .detail })
                .toolbar(removing: .sidebarToggle)
        } detail: {
            practice
                .navigationTitle(model.lessonTitle)
                .navigationSubtitle(model.lessonSubtitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { practiceToolbar }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(item: $sheet, onDismiss: {
            if focusAfterSavingDraft {
                focusAfterSavingDraft = false
                focusRequest = UUID()
            }
        }) { item in
            NavigationStack {
                switch item {
                case .script: scriptForm
                case .settings: settings
                }
            }
            .interactiveDismissDisabled(isSaving)
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.data], allowsMultipleSelection: false) { result in
            do {
                guard let url = try result.get().first, !isSaving else { return }
                importScript(url)
            } catch {
                self.error = error.localizedDescription
            }
        }
        .alert("Couldn’t complete that action", isPresented: Binding(
            get: { error != nil && sheet != .script },
            set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private var practice: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Practice Mode", selection: Binding(get: { model.mode }, set: model.setMode)) {
                ForEach(PracticeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("practiceLadderPicker")
            Label(model.progressText, systemImage: model.isComplete ? "checkmark.circle" : "text.line.first.and.arrowtriangle.forward")
                .font(.headline)
                .accessibilityIdentifier("patternProgress")
            Text(model.displayedSummary)
                .font(.callout).foregroundStyle(.secondary).lineLimit(2)
            ProgressView(value: Double(model.completedLineCount), total: Double(max(1, model.practiceLines.count)))
                .accessibilityLabel("Lines practiced").accessibilityValue(model.progressText)
            if model.isComplete {
                ScrollView {
                    CompletionCard(title: model.lessonTitle, nextLesson: model.nextLesson,
                                   isUserScript: !model.isStarterPattern && model.currentLessonID == nil,
                                   onNext: { if let next = model.nextLesson { load(next) } },
                                   onRepeat: restart, onLibrary: showLibrary) {
                        AttemptOutcomeView(viewModel: model)
                    }
                }
            } else {
                ReferenceCodeView(rows: model.referenceRows, fontSize: fontSize, currentIndex: model.currentLineIndex,
                                  contentKey: model.placeholderText, language: model.language, minHeight: 0)
                    .frame(maxHeight: .infinity)
                PracticeInputPanel(viewModel: model, fontSize: fontSize, editorActive: editorActive, focusRequest: focusRequest)
                    .layoutPriority(1)
            }
        }
        .padding(12)
        .frame(maxWidth: 1_080, maxHeight: .infinity, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .background(modeShortcuts)
    }

    @ToolbarContentBuilder private var practiceToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: showLibrary) { Label("Library", systemImage: "books.vertical") }
                .keyboardShortcut("l", modifiers: .command)
                .accessibilityIdentifier("openLibrary")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: restart) { Label("Repeat Pattern", systemImage: "arrow.counterclockwise") }
                .keyboardShortcut("r", modifiers: .command)
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button(action: showScript) { Label("Add Script", systemImage: "plus") }
                    .keyboardShortcut("n", modifiers: [.command, .shift])
                Button { isImporting = true } label: { Label("Import File", systemImage: "folder") }
                    .keyboardShortcut("o", modifiers: .command)
                Button { sheet = .settings } label: { Label("Settings", systemImage: "slider.horizontal.3") }
            } label: {
                Label("Actions", systemImage: "ellipsis.circle")
            }
            .disabled(isSaving)
            .accessibilityIdentifier("practiceActions")
        }
    }

    private var modeShortcuts: some View {
        ZStack {
            ForEach(PracticeMode.allCases) { mode in
                Button(mode.title) {
                    model.setMode(mode)
                    focusRequest = UUID()
                }
                .keyboardShortcut(KeyEquivalent(Character(String(mode.rawValue + 1))), modifiers: .command)
            }
        }
        .disabled(!editorActive)
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private var scriptForm: some View {
        Form {
            Picker("Language", selection: $model.draftLanguage) {
                ForEach(CodeLanguage.allCases) { Text($0.title).tag($0) }
            }
            Section("Code") {
                TextEditor(text: $model.temPlaceholderText)
                    .font(.system(.body, design: .monospaced))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .frame(minHeight: 160)
                    .accessibilityIdentifier("scriptText")
            }
            if let error { Text(error).foregroundStyle(.red) }
            if isSaving { ProgressView("Saving script…") }
        }
        .navigationTitle("Add Script")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { error = nil; sheet = nil }.disabled(isSaving)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save & Practice", action: saveDraft)
                    .disabled(isSaving || model.temPlaceholderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("saveScript")
            }
        }
    }

    private var settings: some View {
        Form {
            Section("Appearance") {
                Slider(value: Binding(get: { fontSize }, set: { model.textViewFontSize = $0 }), in: 12...30, step: 1) {
                    Text("Code font size")
                } minimumValueLabel: {
                    Text("12")
                } maximumValueLabel: {
                    Text("30")
                }
                .accessibilityValue("\(Int(fontSize)) points")
                Picker("Spaces per Tab", selection: $tabSpaces) {
                    ForEach(1...8, id: \.self) { Text("\($0)").tag(Double($0)) }
                }
            }
            Section("Practice") {
                Toggle("Skip comments", isOn: Binding(get: { model.skipComments }, set: model.setSkipComments))
                    .disabled(model.mode.isGraded)
                Picker("Spacing", selection: Binding(get: { model.diffTolerance }, set: model.setDiffTolerance)) {
                    Text("Strict").tag(DiffTolerance.strictCharacter)
                    Text("Relaxed").tag(DiffTolerance.syntaxAwareTrivia)
                }
                if model.canEditLanguage {
                    Picker("Language", selection: Binding(get: { model.language }, set: model.setLanguage)) {
                        ForEach(CodeLanguage.allCases) { Text($0.title).tag($0) }
                    }
                }
            }
            Section("Privacy") {
                Text("Scripts and mastery stay on this iPad. TypingPall uses no accounts or analytics.")
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Settings")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { sheet = nil }
            }
        }
    }

    private func showLibrary() {
        columns = .all
        compactColumn = .sidebar
    }

    private func showScript() {
        error = nil
        model.temPlaceholderText = ""
        sheet = .script
    }

    private func restart() {
        model.restart()
        focusRequest = UUID()
    }

    private func load(_ lesson: PracticeLesson) {
        performLoad { try model.loadLesson(lesson) }
    }

    private func performLoad(_ action: () throws -> Void) {
        do {
            try action()
            compactColumn = .detail
            focusRequest = UUID()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveDraft() {
        let draft = model.temPlaceholderText
        let language = model.draftLanguage
        saveScript(language: language) { draft }
    }

    private func importScript(_ url: URL) {
        saveScript(language: CodeLanguage.from(fileExtension: url.pathExtension)) {
            try await Task.detached(priority: .userInitiated) {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let file = try FileHandle(forReadingFrom: url)
                defer { try? file.close() }
                let data = try file.read(upToCount: PracticeText.maximumFileBytes + 1) ?? Data()
                guard data.count <= PracticeText.maximumFileBytes else { throw PracticeText.ValidationError.tooLarge }
                guard let text = String(data: data, encoding: .utf8) else { throw PracticeText.ValidationError.binary }
                return text
            }.value
        }
    }

    private func saveScript(language: CodeLanguage, read: @escaping () async throws -> String) {
        guard !isSaving else { return }
        error = nil
        isSaving = true
        let width = PracticeText.tabWidth(tabSpaces)
        Task {
            defer { isSaving = false }
            do {
                let text = try await read()
                let normalized = try PracticeText.validated(text, tabSpaces: width)
                try await repository.saveScript(text: normalized, language: language.rawValue)
                scriptsRevision += 1
                try model.updatePlaceholder(with: normalized, language: language)
                compactColumn = .detail
                if sheet == .script {
                    focusAfterSavingDraft = true
                    sheet = nil
                } else {
                    focusRequest = UUID()
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
