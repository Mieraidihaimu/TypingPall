import SwiftUI

struct TypingScreenView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var editorText = ""
    @State private var isShowingPlaceholderText = false
    @State private var isShowingHistoryUploads = false
    @State private var placeholderText = "This is a placeholder text for typing practice."
    @State private var lastKeyboardType: String?

    var body: some View {
        VStack {
            // Section 1: Text Editor
            TypingEditor(text: $editorText, placeholder: $placeholderText)
                .frame(minWidth: 500, minHeight: 250)
                .padding(.vertical)
                .border(Color.gray, width: 1)

            // Section 2: Keyboard Layout
            KeyboardLayoutView(typedLetter: $lastKeyboardType)
                .frame(minWidth: 500, minHeight: 250)
                .border(Color.gray, width: 1)
        }
        .frame(minWidth: 500, minHeight: 50)
        .onChange(of: editorText, perform: { newValue in
            lastKeyboardType = newValue.last.flatMap { String($0) }
        })
        .sheet(isPresented: $isShowingPlaceholderText, onDismiss: {
            addItem(with: placeholderText)
            editorText = ""
        }) {
            VStack {
                TextEditor(text: $placeholderText)
                    .font(.headline)
                    .frame(minWidth: 600, minHeight: 300)
                    .padding(.vertical)
                    .border(Color.gray, width: 1)
                    .padding(.all)

                Button("Update!", action: { isShowingPlaceholderText.toggle() })
            }
            .padding(.all)
        }
        .sheet(isPresented: $isShowingHistoryUploads, onDismiss: {
            print("dismiss")
        }) {
            HistoryUploadsView(placeholderText: $placeholderText, isShowingHistoryUploads: $isShowingHistoryUploads)
                .frame(minWidth: 600, minHeight: 300)
        }
        .toolbar {
            ToolbarItem {
                Button("Add text or code") {
                    isShowingPlaceholderText = true
                }.disabled(isShowingPlaceholderText)
            }

            ToolbarItem {
                Button("History") {
                    isShowingHistoryUploads = true
                }.disabled(isShowingHistoryUploads)
            }
        }
    }

    private func addItem(with text: String) {
        withAnimation {
            let newItem = Item(context: viewContext)
            newItem.timestamp = Date()
            newItem.text = text

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct TypingScreenView_Previews: PreviewProvider {
    static var previews: some View {
        TypingScreenView()
    }
}
