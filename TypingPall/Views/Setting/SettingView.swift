import SwiftUI

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow
    let practiceWindows: PracticeWindows

    var body: some View {
        TabView {
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }

            Form {
                Button { open(.addScript) } label: { Label("Add Script", systemImage: "plus") }
                Button { open(.importFile) } label: { Label("Import File", systemImage: "square.and.arrow.down") }
                Button { open(.library) } label: { Label("Open Library", systemImage: "books.vertical") }
            }
            .padding()
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }

            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised")
                }
        }
        .padding()
        .frame(width: 480, height: 400)
    }

    private func open(_ action: PracticeLibraryAction) {
        practiceWindows.open(action) { openWindow(id: PracticeWindows.sceneID) }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(practiceWindows: PracticeWindows())
    }
}
