import SwiftUI

final class TypingScreenViewModel: ObservableObject {
    @Published var editorText = ""
    @Published var isShowingPlaceholderText = false
    @Published var isShowingHistoryUploads = false
    @Published var placeholderText = "This is a placeholder text for typing practice."
    @Published var temPlaceholderText = "This is a placeholder text for typing practice."
    @Published var lastKeyboardType: String?

    @AppStorage("typingFontSize") var textViewFontSize: Double = 25
    @AppStorage("isShowingKeyboard") var isShowingKeyboard = false
    @AppStorage("tabEqualsToSpaces") private var spaces: Double = 4

    func updatePlacholder(with text: String) {
        placeholderText = text.replacingOccurrences(of: "\t", with: Array(repeating: " ", count: Int(spaces)).joined())
        editorText = ""
    }
}
