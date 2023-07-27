import SwiftUI

final class TypingScreenViewModel: ObservableObject {
    @Published var editorText = ""
    @Published var isShowingPlaceholderText = false
    @Published var isShowingHistoryUploads = false
    @Published var isShowingKeyboard = true
    @Published var placeholderText = "This is a placeholder text for typing practice."
    @Published var temPlaceholderText = "This is a placeholder text for typing practice."
    @Published var lastKeyboardType: String?
    @Published var textViewFontSize: CGFloat = 25
}
