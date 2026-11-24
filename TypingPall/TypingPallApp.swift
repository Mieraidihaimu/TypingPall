import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        ensureWindowIsOpen()
        DispatchQueue.main.async { [weak self] in
            self?.ensureWindowIsOpen()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            ensureWindowIsOpen()
            for window in sender.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }

    private func ensureWindowIsOpen() {
        let keyWindows = NSApp.windows.filter { $0.canBecomeKey }
        if keyWindows.isEmpty {
            if let fileMenu = NSApp.mainMenu?.items.first(where: { $0.title == "File" })?.submenu,
               let newWindowItem = fileMenu.items.first(where: { $0.title == "New Window" && $0.action != nil }) {
                NSApp.sendAction(newWindowItem.action!, to: newWindowItem.target, from: newWindowItem)
            }
        }
    }
}

enum PracticeLibraryAction {
    case addScript, importFile, library
}

@MainActor
final class PracticeWindows {
    static let sceneID = "practice"
    private let attachments = NSMapTable<NSWindow, Attachment>(keyOptions: .weakMemory, valueOptions: .weakMemory)
    private var pendingAction: PracticeLibraryAction?

    func open(_ action: PracticeLibraryAction, createWindow: () -> Void) {
        let windows = NSApp.orderedWindows + NSApp.windows.filter(\.isMiniaturized)
        for window in windows {
            guard let attachment = attachments.object(forKey: window), attachment.window === window else { continue }
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            attachment.perform(action)
            return
        }
        let needsWindow = pendingAction == nil
        pendingAction = action
        if needsWindow { createWindow() }
    }

    func attach(_ attachment: Attachment, to window: NSWindow) {
        attachments.setObject(attachment, forKey: window)
        guard let action = pendingAction else { return }
        pendingAction = nil
        // Give SwiftUI time to install the new window's sheet presenter.
        DispatchQueue.main.async { [weak attachment] in attachment?.perform(action) }
    }

    final class Attachment: NSView {
        weak var practiceWindows: PracticeWindows?
        var perform: (PracticeLibraryAction) -> Void = { _ in }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { practiceWindows?.attach(self, to: window) }
        }
    }
}

struct PracticeWindowAttachment: NSViewRepresentable {
    let practiceWindows: PracticeWindows
    let perform: (PracticeLibraryAction) -> Void

    func makeNSView(context: Context) -> PracticeWindows.Attachment {
        let attachment = PracticeWindows.Attachment()
        attachment.practiceWindows = practiceWindows
        attachment.perform = perform
        return attachment
    }

    func updateNSView(_ attachment: PracticeWindows.Attachment, context: Context) {
        attachment.perform = perform
    }
}

@main
struct TypingPallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var persistence: PersistenceController
    @State private var practiceWindows = PracticeWindows()

    init() {
        UserDefaults.standard.register(defaults: [
            "NSQuitAlwaysKeepsWindows": false
        ])
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
        let testing = ProcessInfo.processInfo.arguments.contains("--ui-testing") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        _persistence = StateObject(wrappedValue: testing ? PersistenceController(inMemory: true) : .shared)
    }

    var body: some Scene {
        WindowGroup(id: PracticeWindows.sceneID) {
            Group {
                if persistence.isReady {
                    TypingScreenView(practiceWindows: practiceWindows)
                        .environment(\.managedObjectContext, persistence.container.viewContext)
                        .environment(\.persistenceRepository, PersistenceRepository(container: persistence.container))
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
        .defaultSize(width: 960, height: 760)
        Settings {
            SettingsView(practiceWindows: practiceWindows)
        }
    }
}
