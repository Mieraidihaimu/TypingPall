import SwiftUI
import CoreData

struct HistoryUploadsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: false)], animation: .default)
    private var items: FetchedResults<Item>
    @State private var errorMessage: String?
    @State private var pendingDeletion: Item?
    @State private var search = ""
    @State private var category = "All topics"
    @State private var selection: String?
    @State private var showingSaved = false
    var onSelect: (String, CodeLanguage) -> Void
    var onSelectLesson: (PracticeLesson) -> Void

    private var lessons: [PracticeLesson] {
        PracticeCatalog.lessons.filter {
            (category == "All topics" || $0.category == category) &&
            (search.isEmpty || "\($0.title) \($0.category) \($0.summary) \($0.language.title)".localizedCaseInsensitiveContains(search))
        }
    }
    private var selectedLesson: PracticeLesson? { lessons.first { $0.id == selection } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Practice library").font(.title2).fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            Picker("Library", selection: $showingSaved) {
                Text("Built-in lessons (\(PracticeCatalog.lessons.count))").tag(false)
                Text("My scripts").tag(true)
            }.pickerStyle(.segmented)
            if showingSaved { savedScripts } else { builtInLessons }
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
                TextField("Search patterns, languages, concurrency…", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("lessonSearch")
                Picker("Topic", selection: $category) {
                    Text("All topics").tag("All topics")
                    ForEach(PracticeCatalog.categories, id: \.self) { Text($0).tag($0) }
                }.frame(width: 260)
            }
            HStack(spacing: 16) {
                List(selection: $selection) {
                    ForEach(lessons) { lesson in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(lesson.title).fontWeight(.medium)
                            Text(lesson.category).font(.caption).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .tag(lesson.id)
                    }
                }.frame(width: 250)
                if let lesson = selectedLesson {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(lesson.title).font(.title3).fontWeight(.semibold)
                        Text(lesson.summary).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                        ScrollView {
                            Text(lesson.code)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        Button("Practice Lesson") { onSelectLesson(lesson); dismiss() }
                            .accessibilityIdentifier("practiceLesson")
                    }
                } else {
                    Text(lessons.isEmpty ? "No lessons match your search." : "Choose a lesson to preview its code and learning focus.")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            Text("Original practice examples · 13 curated interview patterns, language fundamentals and concurrency")
                .font(.caption).foregroundColor(.secondary)
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
