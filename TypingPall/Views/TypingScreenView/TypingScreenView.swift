import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct TypingScreenView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = TypingScreenViewModel()
    @State private var isImporting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Make the pattern familiar.").font(.title2).fontWeight(.semibold)
                    Text(viewModel.lessonTitle)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button { viewModel.restart() } label: { Label("Repeat Pattern", systemImage: "arrow.counterclockwise") }
                    .keyboardShortcut("r", modifiers: .command)
                    .accessibilityIdentifier("restartPractice")
            }
            HStack {
                Toggle("Skip comments", isOn: Binding(get: { viewModel.skipComments }, set: { viewModel.setSkipComments($0) }))
                    .accessibilityIdentifier("skipComments")
                Picker("Language", selection: Binding(get: { viewModel.language }, set: { viewModel.setLanguage($0) })) {
                    ForEach(CodeLanguage.allCases) { Text($0.title).tag($0) }
                }.frame(width: 180)
                Text("Changing these options restarts the pattern.").font(.caption).foregroundColor(.secondary)
                Spacer()
            }
            Text(viewModel.lessonSummary).font(.callout).foregroundColor(.secondary).lineLimit(3)
            HStack {
                Label(!viewModel.hasPracticeLines ? "No code to practice" : viewModel.isComplete ? "Pattern complete" : "Step \(viewModel.practicePosition + 1) of \(viewModel.practiceLines.count) · line \(viewModel.currentLineIndex + 1)",
                      systemImage: viewModel.isComplete ? "checkmark.circle" : "text.line.first.and.arrowtriangle.forward")
                    .font(.headline)
                    .accessibilityIdentifier("patternProgress")
                Spacer()
                Text("\(viewModel.completedLineCount) lines practiced")
                    .foregroundColor(.secondary)
            }
            ProgressView(value: Double(viewModel.completedLineCount), total: Double(max(1, viewModel.practiceLines.count)))
                .accessibilityLabel("Lines practiced")
            referenceView
            HStack {
                Text(viewModel.isComplete ? "Pattern complete. Repeat it to reinforce the sequence." : "TYPE THE HIGHLIGHTED LINE")
                    .font(.caption).fontWeight(.semibold).foregroundColor(.secondary)
                Spacer()
                Text("Tab = \(viewModel.sessionTabSpaces) spaces")
                    .font(.caption).foregroundColor(.secondary)
            }
            TextKit2TypingEditor(typedText: $viewModel.editorText, targetText: .constant(viewModel.currentLine),
                                 fontSize: safeFontSize, tabSpaces: viewModel.sessionTabSpaces,
                                 isEnabled: viewModel.hasPracticeLines && !viewModel.isComplete, resetID: viewModel.sessionID,
                                 onSubmit: { viewModel.advanceLine() })
                .frame(minHeight: 100, idealHeight: 130, maxHeight: 160)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.25)))
            HStack {
                Text(lineGuidance)
                    .font(.callout)
                    .foregroundColor(viewModel.isLineMatched ? .green : .secondary)
                    .accessibilityIdentifier("lineGuidance")
                Spacer()
                Button("Repeat Line") { viewModel.repeatLine() }
                    .disabled(!viewModel.hasPracticeLines || viewModel.isComplete)
                    .accessibilityIdentifier("repeatLine")
                Button(viewModel.isLastPracticeLine ? "Finish Pattern" : "Next Line") {
                    viewModel.advanceLine()
                }
                .disabled(!viewModel.isLineMatched || viewModel.isComplete)
                .accessibilityIdentifier("nextLine")
            }
            if viewModel.isShowingKeyboard {
                KeyboardLayoutView(typedLetter: $viewModel.lastKeyboardType)
                    .frame(height: 250)
            }
        }
        .padding(24)
        .frame(minWidth: 760, idealWidth: 900, minHeight: 620, idealHeight: 740)
        .navigationTitle("TypingPall")
        .onChange(of: viewModel.editorText) { text in
            viewModel.lastKeyboardType = text.last.map(String.init)
        }
        .sheet(isPresented: $viewModel.isShowingPlaceholderText) { scriptSheet }
        .sheet(isPresented: $viewModel.isShowingHistoryUploads) {
            HistoryUploadsView(onSelect: { text, language in load(text, language: language) }, onSelectLesson: { lesson in
                do { try viewModel.loadLesson(lesson) }
                catch { errorMessage = error.localizedDescription }
            })
                .frame(width: 900, height: 600)
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
                Button { errorMessage = nil; viewModel.temPlaceholderText = ""; viewModel.isShowingPlaceholderText = true } label: {
                    Label("Add Script", systemImage: "plus")
                }.keyboardShortcut("n", modifiers: [.command, .shift])
                Button { isImporting = true } label: { Label("Import File", systemImage: "square.and.arrow.down") }
                    .keyboardShortcut("o", modifiers: .command)
                Button { viewModel.isShowingHistoryUploads = true } label: { Label("Library", systemImage: "books.vertical") }
                    .keyboardShortcut("l", modifiers: .command)
            }
        }
    }

    private var safeFontSize: Double {
        viewModel.textViewFontSize.isFinite ? min(30, max(12, viewModel.textViewFontSize)) : 25
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

    private var lineGuidance: String {
        if !viewModel.hasPracticeLines { return "Only comments remain. Turn off Skip comments to practice them." }
        if viewModel.isComplete { return "Take a moment to recall what each step does." }
        if viewModel.currentLine.isEmpty { return "Blank line — press Return to continue." }
        if viewModel.isLineMatched { return "Line matched. Press Return to continue, or repeat this line." }
        return viewModel.skipComments && viewModel.language != .plainText ? "Type code only. Leading indentation and comments are skipped." : "Leading indentation is skipped. Correct any underlined differences, then press Return."
    }

    private var referenceView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(viewModel.lines.indices, id: \.self) { index in
                        HStack(alignment: .firstTextBaseline, spacing: 16) {
                            Text("\(index + 1)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            Text(viewModel.lines[index].isEmpty ? " " : viewModel.lines[index])
                                .font(.system(size: safeFontSize, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundColor(viewModel.skippedLineIndices.contains(index) ? .secondary : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(index == viewModel.currentLineIndex && !viewModel.isComplete ? Color.accentColor.opacity(0.15) : Color.clear)
                        .overlay(alignment: .leading) {
                            if index == viewModel.currentLineIndex && !viewModel.isComplete {
                                Rectangle().fill(Color.accentColor).frame(width: 3)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Line \(index + 1)\(index == viewModel.currentLineIndex ? ", current line" : ""): \(viewModel.lines[index])")
                        .id(index)
                    }
                }.padding(.vertical, 12)
            }
            .onChange(of: viewModel.currentLineIndex) { index in
                withAnimation { proxy.scrollTo(index, anchor: .center) }
            }
            .onChange(of: viewModel.placeholderText) { _ in proxy.scrollTo(viewModel.currentLineIndex, anchor: .top) }
        }
        .frame(minHeight: 180, idealHeight: 300)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}
