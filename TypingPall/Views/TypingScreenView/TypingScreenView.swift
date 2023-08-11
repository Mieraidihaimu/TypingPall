import SwiftUI

struct TypingScreenView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel = TypingScreenViewModel()

    var body: some View {
        VStack {
            // Section 1: Text Editor
            TypingEditor(text: $viewModel.editorText, placeholder: $viewModel.placeholderText, fontSize: viewModel.textViewFontSize)
                .frame(minWidth: 500, minHeight: 250)
                .padding(.vertical)
                .border(Color.gray, width: 1)

            if viewModel.isShowingKeyboard {
                // Section 2: Keyboard Layout
                KeyboardLayoutView(typedLetter: $viewModel.lastKeyboardType)
                    .frame(minWidth: 500, minHeight: 250)
                    .border(Color.gray, width: 1)
            }
        }
        .frame(minWidth: 500, minHeight: 50)
        .onChange(of: viewModel.editorText, perform: { newValue in
            viewModel.lastKeyboardType = newValue.last.flatMap { String($0) }
        })
        .sheet(isPresented: $viewModel.isShowingPlaceholderText) {
            VStack {
                TextEditor(text: $viewModel.temPlaceholderText)
                    .font(.headline)
                    .frame(minWidth: 600, minHeight: 300)
                    .padding(.vertical)
                    .border(Color.gray, width: 1)
                    .padding(.all)

                HStack {
                    Button("Update!") {
                        viewModel.placeholderText = viewModel.temPlaceholderText
                        addItem(with: viewModel.placeholderText)
                        viewModel.editorText = ""
                        viewModel.isShowingPlaceholderText.toggle()
                    }

                    Spacer()

                    Button("Dismiss") {
                        viewModel.isShowingPlaceholderText.toggle()
                    }
                }
            }
            .padding(.all)
        }
        .sheet(isPresented: $viewModel.isShowingHistoryUploads) {
            HistoryUploadsView(placeholderText: $viewModel.placeholderText, isShowingHistoryUploads: $viewModel.isShowingHistoryUploads)
                .frame(minWidth: 600, minHeight: 300)
        }
        .toolbar {
            ToolbarItem {
                Button("Add Script") {
                    viewModel.isShowingPlaceholderText = true
                    viewModel.temPlaceholderText = viewModel.placeholderText
                }.disabled(viewModel.isShowingPlaceholderText)
            }

            ToolbarItem {
                Button("See History") {
                    viewModel.isShowingHistoryUploads = true
                }.disabled(viewModel.isShowingHistoryUploads)
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
