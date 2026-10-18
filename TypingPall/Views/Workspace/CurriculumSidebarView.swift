import SwiftUI

public enum SidebarSelection: Hashable {
    case smartCollection(SmartFilter)
    case drill(DrillDestination)
    case lesson(String)
    case script(String)
}

public enum SmartFilter: String, CaseIterable, Identifiable {
    case dueForRecall = "Due for Recall"
    case allPatterns = "All Patterns"
    case leetcode = "LeetCode"
    case lld = "Low-Level Design"
    case myScripts = "My Scripts"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .dueForRecall: return "clock.badge.checkmark"
        case .allPatterns: return "books.vertical"
        case .leetcode: return "brain.head.profile"
        case .lld: return "slider.horizontal.3"
        case .myScripts: return "doc.text"
        }
    }
}

public enum DrillDestination: String, CaseIterable, Identifiable {
    case whichPattern = "Which Pattern?"
    case bugHunt = "Bug Hunt"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .whichPattern: return "questionmark.circle"
        case .bugHunt: return "ladybug"
        }
    }
}

struct CurriculumSidebarView: View {
    @ObservedObject var viewModel: TypingScreenViewModel
    @ObservedObject var masteryStore = MasteryStore.shared

    @Binding var selection: SidebarSelection?
    @Binding var activeSmartFilter: SmartFilter
    @Binding var selectedDrill: DrillDestination?

    @State private var searchQuery = ""

    var savedScripts: [HistoryRecordDTO]
    var onSelectScript: (HistoryRecordDTO) -> Void
    var onSelectLesson: (PracticeLesson) -> Void
    var onSelectBugHunt: (PracticeLesson) -> Void
    var onSelectDrill: (DrillDestination) -> Void
    var onAddScript: () -> Void

    init(
        viewModel: TypingScreenViewModel,
        selection: Binding<SidebarSelection?>,
        activeSmartFilter: Binding<SmartFilter>,
        selectedDrill: Binding<DrillDestination?>,
        savedScripts: [HistoryRecordDTO],
        onSelectScript: @escaping (HistoryRecordDTO) -> Void,
        onSelectLesson: @escaping (PracticeLesson) -> Void,
        onSelectBugHunt: @escaping (PracticeLesson) -> Void,
        onSelectDrill: @escaping (DrillDestination) -> Void,
        onAddScript: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self._selection = selection
        self._activeSmartFilter = activeSmartFilter
        self._selectedDrill = selectedDrill
        self.savedScripts = savedScripts
        self.onSelectScript = onSelectScript
        self.onSelectLesson = onSelectLesson
        self.onSelectBugHunt = onSelectBugHunt
        self.onSelectDrill = onSelectDrill
        self.onAddScript = onAddScript
    }

    private var allLessons: [PracticeLesson] { PracticeCatalog.lessons }

    private var filteredScripts: [HistoryRecordDTO] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return savedScripts }
        return savedScripts.filter {
            $0.text.localizedCaseInsensitiveContains(query) ||
            (CodeLanguage(rawValue: $0.language) ?? .plainText).title.localizedCaseInsensitiveContains(query)
        }
    }

    private var filteredLessons: [PracticeLesson] {
        let base: [PracticeLesson]
        switch activeSmartFilter {
        case .dueForRecall:
            let dueIDs = masteryStore.dueForRecallPatternIDs()
            base = allLessons.filter { dueIDs.contains($0.id) }
        case .allPatterns:
            base = allLessons
        case .leetcode:
            base = allLessons.filter { $0.track == .leetcode }
        case .lld:
            base = allLessons.filter { $0.track == .lowLevelDesign }
        case .myScripts:
            base = []
        }

        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return base }
        return base.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.language.title.localizedCaseInsensitiveContains(query) ||
            $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    public var body: some View {
        List(selection: $selection) {
            // Search field
            Section {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    TextField(activeSmartFilter == .myScripts ? "Filter scripts…" : "Filter patterns…", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.callout)
                        .accessibilityIdentifier("sidebarSearch")
                }
                .padding(.vertical, 4)
            }

            // Smart Collections
            Section(header: Text("CURRICULUM").font(.caption2).fontWeight(.bold).foregroundColor(.secondary)) {
                ForEach(SmartFilter.allCases) { filter in
                    HStack {
                        Label(filter.rawValue, systemImage: filter.icon)
                            .foregroundColor(filter == .dueForRecall && masteryStore.dueForRecallCount > 0 ? Color.orange : .primary)

                        Spacer()

                        if filter == .dueForRecall {
                            let count = masteryStore.dueForRecallCount
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .accessibilityIdentifier("collection-\(filter.id)")
                    .tag(SidebarSelection.smartCollection(filter))
                }
            }

            // Dedicated Practice Drills
            Section(header: Text("PRACTICE DRILLS").font(.caption2).fontWeight(.bold).foregroundColor(.secondary)) {
                ForEach(DrillDestination.allCases) { drill in
                    HStack {
                        Label(drill.rawValue, systemImage: drill.icon)
                            .foregroundColor(drill == .bugHunt ? .orange : Color.accentColor)
                        Spacer()
                    }
                    .tag(SidebarSelection.drill(drill))
                }
            }

            // Patterns List under selected Smart Filter
            Section(header: Text(activeSmartFilter.rawValue.uppercased()).font(.caption2).fontWeight(.bold).foregroundColor(.secondary)) {
                if activeSmartFilter == .myScripts {
                    if filteredScripts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(savedScripts.isEmpty ? "No saved scripts yet." : "No scripts match your search.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if savedScripts.isEmpty {
                                Button("Add Script…", action: onAddScript)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        ForEach(filteredScripts) { script in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(script.text.trimmingCharacters(in: .whitespacesAndNewlines))
                                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                                    .lineLimit(2)
                                HStack {
                                    Text((CodeLanguage(rawValue: script.language) ?? .plainText).title)
                                    Text(script.timestamp, style: .date)
                                }
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 3)
                            .accessibilityIdentifier("savedScript-\(script.id)")
                            .tag(SidebarSelection.script(script.id))
                        }
                    }
                } else if filteredLessons.isEmpty {
                    Text(activeSmartFilter == .dueForRecall ? "All patterns fresh! No recall due." : "No patterns found.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                } else {
                    ForEach(filteredLessons) { lesson in
                        let level = masteryStore.level(for: lesson.id)
                        let isDue = masteryStore.isDueForRecall(patternID: lesson.id)

                        HStack(spacing: 8) {
                            TriRingMasteryGlyph(level: level, isDueForRecall: isDue, size: 14)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(lesson.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .lineLimit(1)
                                Text(lesson.language.title)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if !(lesson.mutations ?? []).isEmpty {
                                Image(systemName: "ladybug")
                                    .font(.system(size: 10))
                                    .foregroundColor(.orange.opacity(0.8))
                                    .help("Has Bug Hunt")
                            }
                        }
                        .padding(.vertical, 3)
                        .tag(SidebarSelection.lesson(lesson.id))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 280)
        .onChange(of: activeSmartFilter) { _ in searchQuery = "" }
        .onChange(of: selection) { newSelection in
            switch newSelection {
            case .smartCollection(let filter):
                if activeSmartFilter != filter { searchQuery = "" }
                activeSmartFilter = filter
                selectedDrill = nil
            case .drill(let drill):
                selectedDrill = drill
                onSelectDrill(drill)
            case .lesson(let id):
                if let lesson = allLessons.first(where: { $0.id == id }) {
                    selectedDrill = nil
                    onSelectLesson(lesson)
                }
            case .script(let id):
                if let script = savedScripts.first(where: { $0.id == id }) {
                    if !filteredScripts.contains(where: { $0.id == id }) { searchQuery = "" }
                    selectedDrill = nil
                    onSelectScript(script)
                }
            case nil:
                break
            }
        }
    }
}
