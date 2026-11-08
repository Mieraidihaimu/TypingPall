import SwiftUI

struct PadLibraryView: View {
    @Environment(\.persistenceRepository) private var repository
    @ObservedObject private var mastery = MasteryStore.shared
    @State private var search = ""
    @State private var track: LessonTrack?
    @State private var topic: String?
    @State private var showsScripts = false
    @State private var dueOnly = false
    @State private var scripts: [HistoryRecordDTO] = []
    @State private var pendingDeletion: HistoryRecordDTO?
    @State private var deletionRevision = 0
    @State private var error: String?

    let scriptsRevision: Int
    let onLesson: (PracticeLesson) -> Void
    let onScript: (HistoryRecordDTO) -> Void
    let onAdd: () -> Void
    let onImport: () -> Void
    let onClose: () -> Void

    private var topics: [String] { PracticeCatalog.categories(of: PracticeCatalog.lessons, in: track) }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Library", selection: $showsScripts) {
                Text("Lessons").tag(false)
                Text("My Scripts").tag(true)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("libraryShelf")
            .padding([.horizontal, .top], 12)
            List {
                if showsScripts {
                    scriptRows
                } else {
                    lessonRows
                }
            }
            .listStyle(.sidebar)
        }
        .navigationTitle("Library")
        .searchable(text: $search, prompt: showsScripts ? "Find scripts" : "Find patterns, cues, or languages")
        .searchToolbarBehavior(.minimize)
        .onChange(of: showsScripts) { search = "" }
        .onChange(of: track) { topic = nil }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Practice", action: onClose)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("closeLibrary")
            }
        }
        .task(id: scriptsRevision + deletionRevision) {
            do {
                let loaded = try await repository.fetchRecentScripts(limit: 0)
                try Task.checkCancellation()
                scripts = loaded
            } catch is CancellationError {
                return
            } catch {
                self.error = error.localizedDescription
            }
        }
        .confirmationDialog("Delete this script?", isPresented: Binding(
            get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }
        ), titleVisibility: .visible, presenting: pendingDeletion) { item in
            Button("Delete", role: .destructive) {
                Task {
                    do {
                        _ = try await repository.deleteScript(id: item.id)
                        deletionRevision += 1
                    } catch {
                        self.error = error.localizedDescription
                    }
                }
            }
        } message: { _ in
            Text("This removes the saved script from your library.")
        }
        .alert("Library unavailable", isPresented: Binding(
            get: { error != nil }, set: { if !$0 { error = nil } }
        )) {
            Button("OK", role: .cancel) { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    @ViewBuilder private var lessonRows: some View {
        Section {
            Picker("Track", selection: $track) {
                Text("All tracks").tag(LessonTrack?.none)
                ForEach(LessonTrack.allCases.filter { track in PracticeCatalog.lessons.contains { $0.track == track } }) {
                    Text($0.title).tag(Optional($0))
                }
            }
            Picker("Topic", selection: $topic) {
                Text("All topics").tag(String?.none)
                ForEach(topics, id: \.self) { Text($0).tag(Optional($0)) }
            }
            Toggle("Due for Recall", isOn: $dueOnly)
        }
        let lessons = dueOnly ? PracticeCatalog.lessons.filter { mastery.isDueForRecall(patternID: $0.id) } : PracticeCatalog.lessons
        let sections = PracticeCatalog.sections(of: lessons, track: track, category: topic, search: search)
        if let error = PracticeCatalog.loadError {
            Text("Built-in lessons couldn’t be loaded. \(error.localizedDescription)")
                .foregroundStyle(.secondary)
        } else if sections.isEmpty {
            Text("No lessons match the current filters.").foregroundStyle(.secondary)
        }
        ForEach(sections) { section in
            Section(section.title) {
                ForEach(section.lessons) { lesson in
                    Button {
                        onLesson(lesson)
                    } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text(lesson.title)
                                Text(lesson.language.title).font(.caption).foregroundStyle(.secondary)
                            }
                        } icon: {
                            TriRingMasteryGlyph(level: mastery.level(for: lesson.id),
                                                isDueForRecall: mastery.isDueForRecall(patternID: lesson.id), size: 14)
                        }
                    }
                    .accessibilityIdentifier("lesson-\(lesson.id)")
                }
            }
        }
    }

    @ViewBuilder private var scriptRows: some View {
        Section {
            Button(action: onAdd) { Label("Add Script", systemImage: "plus") }
            Button(action: onImport) { Label("Import File", systemImage: "folder") }
        }
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching = scripts.filter { script in
            query.isEmpty || script.text.localizedCaseInsensitiveContains(query)
                || (CodeLanguage(rawValue: script.language) ?? .plainText).title.localizedCaseInsensitiveContains(query)
        }
        if matching.isEmpty {
            Text(scripts.isEmpty ? "Saved scripts appear here." : "No scripts match your search.")
                .foregroundStyle(.secondary)
        }
        ForEach(matching) { script in
            Button {
                onScript(script)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(script.text).font(.system(.body, design: .monospaced)).lineLimit(2)
                    Text((CodeLanguage(rawValue: script.language) ?? .plainText).title)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("savedScript")
            .swipeActions {
                Button(role: .destructive) { pendingDeletion = script } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Button("Delete", systemImage: "trash", role: .destructive) { pendingDeletion = script }
            }
        }
    }
}
