import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("DEBUG_TP: applicationDidFinishLaunching, windows count=%ld", NSApp.windows.count)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSLog("DEBUG_TP: delayed check, windows count=%ld, windows=%@", NSApp.windows.count, NSApp.windows)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSLog("DEBUG_TP: applicationShouldHandleReopen flag=%d windows=%ld", flag, sender.windows.count)
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
        NSLog("DEBUG_TP: TypingPallApp.init, args=%@", ProcessInfo.processInfo.arguments)
        UserDefaults.standard.register(defaults: [
            "NSQuitAlwaysKeepsWindows": false,
            "ApplePersistenceIgnoreState": true
        ])
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        _persistence = StateObject(wrappedValue: testing ? PersistenceController(inMemory: true) : .shared)
    }

    var body: some Scene {
        let _ = NSLog("DEBUG_TP: body evaluated, isReady=%d, loadError=%@", persistence.isReady ? 1 : 0, persistence.loadError ?? "nil")
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
