import SwiftUI
import CoreData

struct HistoryUploadsView: View {
    private enum Shelf: Hashable { case lessons(LessonTrack?), scripts }

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)], animation: .default)
    private var items: FetchedResults<Item>
    @State private var errorMessage: String?
    @State private var pendingDeletion: Item?
    @State private var search = ""
    @State private var shelf = Shelf.lessons(nil)
    @State private var category: String?
    @State private var selection: String?
    var onSelect: (String, CodeLanguage) -> Void
    var onSelectLesson: (PracticeLesson) -> Void
    var onAddScript: () -> Void = {}
    var onImport: () -> Void = {}
    var onSelectBugHunt: (PracticeLesson) -> Void = { _ in }
    var onSelectContrast: (ContrastPair) -> Void = { _ in }

    private var track: LessonTrack? {
        if case .lessons(let track) = shelf { return track }
        return nil
    }
    private var sections: [LessonSection] {
        PracticeCatalog.sections(of: PracticeCatalog.lessons, track: track, category: category, search: search)
    }
    private var selectedLesson: PracticeLesson? { sections.lazy.flatMap(\.lessons).first { $0.id == selection } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Practice library").font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Picker("Library", selection: $shelf) {
                Text("All lessons").tag(Shelf.lessons(nil))
                ForEach(LessonTrack.allCases.filter { track in PracticeCatalog.lessons.contains { $0.track == track } }) {
                    Text($0.title).tag(Shelf.lessons($0))
                }
                Text("My scripts").tag(Shelf.scripts)
            }
            .pickerStyle(.segmented).labelsHidden()
            .onChange(of: shelf) { _ in category = nil }
            if shelf == .scripts { savedScripts } else { builtInLessons }
        }.padding(24)
        .alert("Delete this script?", isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } })) {
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
            Button("Delete", role: .destructive) {
                guard let item = pendingDeletion else { return }
                viewContext.delete(item)
                do { try viewContext.save() }
                catch { viewContext.rollback(); errorMessage = error.localizedDescription }
                pendingDeletion = nil
            }
        } message: { Text("This removes the saved script from your library.") }
        .alert("Couldn’t delete the script", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private var builtInLessons: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("Search patterns, cues, languages…", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("lessonSearch")
                Picker("Topic", selection: $category) {
                    Text("All topics").tag(String?.none)
                    ForEach(PracticeCatalog.categories(of: PracticeCatalog.lessons, in: track), id: \.self) { Text($0).tag(String?.some($0)) }
                }.frame(width: 260)
            }
            HStack(spacing: 16) {
                List(selection: $selection) {
                    ForEach(sections) { section in
                        Section(header: Text(section.title)) {
                            ForEach(section.lessons) { lesson in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lesson.title).fontWeight(.medium)
                                    Text(lesson.language.title).font(.caption).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                .tag(lesson.id)
                            }
                        }
                    }
                }.frame(width: 250)
                if let lesson = selectedLesson {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(lesson.title).font(.title3).fontWeight(.semibold)
                        Text(lesson.summary).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        ScrollView {
                            LessonNotesView(lesson: lesson, onContrast: { onSelectContrast($0); dismiss() })
                        }
                        HStack {
                            Button("Practice Lesson") { onSelectLesson(lesson); dismiss() }
                                .keyboardShortcut(.defaultAction)
                                .accessibilityIdentifier("practiceLesson")
                            if !(lesson.mutations ?? []).isEmpty {
                                Button("Find the Bug") { onSelectBugHunt(lesson); dismiss() }
                                    .accessibilityIdentifier("findBug")
                            }
                        }
                    }
                } else if PracticeCatalog.lessons.isEmpty {
                    VStack(spacing: 8) {
                        Text("Built-in lessons couldn't be loaded.").font(.headline)
                        if let error = PracticeCatalog.loadError {
                            Text(error.localizedDescription).foregroundColor(.secondary).textSelection(.enabled)
                        }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sections.isEmpty {
                    VStack(spacing: 12) {
                        Text("No lessons match “\(search)”.").foregroundColor(.secondary)
                        Button("Clear Search") { search = "" }.accessibilityIdentifier("clearSearch")
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("Choose a lesson to preview its code and learning focus.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private var savedScripts: some View {
        Group {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "books.vertical").font(.largeTitle)
                    Text("Save your own patterns here").font(.headline)
                    Text("Add a script or import a text file. Built-in lessons are ready in the other tab.")
                        .foregroundColor(.secondary)
                    HStack {
                        Button("Add Script…") { onAddScript(); dismiss() }
                        Button("Import File…") { onImport(); dismiss() }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(items) { item in
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.text ?? "Untitled script").font(.system(.body, design: .monospaced)).lineLimit(2)
                                HStack {
                                    Text((CodeLanguage(rawValue: item.language ?? "") ?? .plainText).title)
                                    if let date = item.timestamp { Text(date, style: .date) }
                                }.font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button("Practice") {
                                onSelect(item.text ?? "", CodeLanguage(rawValue: item.language ?? "") ?? .plainText)
                                dismiss()
                            }.disabled((item.text ?? "").isEmpty)
                            Button { pendingDeletion = item } label: { Image(systemName: "trash") }
                                .accessibilityLabel("Delete script")
                        }.padding(.vertical, 8)
                    }
                }
            }
        }
    }
}
