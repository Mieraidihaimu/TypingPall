import SwiftUI

@main
struct TypingPallApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
                TypingScreenView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }

        Settings {
            SettingsView()
        }
    }
}
