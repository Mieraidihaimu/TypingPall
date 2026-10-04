import Foundation

extension String {
    /// The mismatching suffix in AppKit's UTF-16 coordinate space.
    func extractMismatchedRange(comparedTo placeholder: String) -> NSRange? {
        LineDiff(typed: self, target: placeholder).mismatchRange
    }
}

enum PracticeText {
    static let maximumCharacters = 20_000
    static let maximumFileBytes = 1_000_000

    static func tabWidth(_ value: Double) -> Int {
        value.isFinite ? Int(min(8, max(1, value))) : 4
    }

    static func normalize(_ text: String, tabSpaces: Int) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\t", with: String(repeating: " ", count: min(8, max(1, tabSpaces))))
    }

    static func validated(_ text: String, tabSpaces: Int) throws -> String {
        let normalized = normalize(text, tabSpaces: tabSpaces)
        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.empty
        }
        guard normalized.count <= maximumCharacters else { throw ValidationError.tooLarge }
        guard !normalized.contains("\0") else { throw ValidationError.binary }
        return normalized
    }

    enum ValidationError: LocalizedError {
        case empty, tooLarge, binary
        var errorDescription: String? {
            switch self {
            case .empty: return "Add some text before starting a practice session."
            case .tooLarge: return "Choose a shorter excerpt (up to 20,000 characters and a file under 1 MB)."
            case .binary: return "Choose a plain-text or source-code file saved as UTF-8."
            }
        }
    }

    enum InputRejection: Equatable {
        case invalidRange, multipleLines, tooLong
        var message: String? {
            switch self {
            case .invalidRange: return nil
            case .multipleLines: return "Type one line at a time. Paste whole snippets into Add Script."
            case .tooLong: return "That line would pass the 20,000-character limit."
            }
        }
    }
}
