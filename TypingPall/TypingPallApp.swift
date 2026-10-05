import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
}

@main
struct TypingPallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var persistence: PersistenceController

    init() {
        UserDefaults.standard.register(defaults: [
            "NSQuitAlwaysKeepsWindows": false,
            "ApplePersistenceIgnoreState": true
        ])
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        _persistence = StateObject(wrappedValue: testing ? PersistenceController(inMemory: true) : .shared)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if persistence.isReady {
                    TypingScreenView()
                        .environment(\.managedObjectContext, persistence.container.viewContext)
                } else if let error = persistence.loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "externaldrive.badge.exclamationmark").font(.largeTitle)
                        Text("Unable to open your library").font(.title2)
                        Text(error).textSelection(.enabled)
                        Button("Try Again") { persistence.loadStore() }
                    }
                    .padding(32)
                    .frame(width: 560)
                } else {
                    ProgressView("Opening your library…").frame(width: 560, height: 300)
                }
            }
        }
        Settings { SettingsView() }
    }
}
