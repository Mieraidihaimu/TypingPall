import SwiftUI

@main
struct TypingPallPadApp: App {
    @StateObject private var persistence: PersistenceController

    init() {
        let process = ProcessInfo.processInfo
        let testing = process.arguments.contains("--ui-testing") || process.environment["XCTestConfigurationFilePath"] != nil
        _persistence = StateObject(wrappedValue: testing ? PersistenceController(inMemory: true) : .shared)
    }

    var body: some Scene {
        WindowGroup {
            if persistence.isReady {
                PadPracticeScreen()
                    .environment(\.persistenceRepository, PersistenceRepository(container: persistence.container))
            } else if let error = persistence.loadError {
                ContentUnavailableView {
                    Label("Unable to open your library", systemImage: "externaldrive.badge.exclamationmark")
                } description: {
                    Text(error)
                } actions: {
                    Button("Try Again") { persistence.loadStore() }
                }
            } else {
                ProgressView("Opening your library…")
            }
        }
    }
}
