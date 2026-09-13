import Foundation

enum CodeLanguage: String, Codable, CaseIterable, Identifiable {
    case plainText, python, cpp, rust, go
    var id: String { rawValue }
    var title: String {
        switch self {
        case .plainText: return "Plain text"
        case .python: return "Python"
        case .cpp: return "C++"
        case .rust: return "Rust"
        case .go: return "Go"
        }
    }
    static func from(fileExtension: String) -> CodeLanguage {
        switch fileExtension.lowercased() {
        case "py", "pyw": return .python
        case "cpp", "cc", "cxx", "h", "hpp", "c": return .cpp
        case "rs": return .rust
        case "go": return .go
        default: return .plainText
        }
    }
}

struct PracticeLesson: Codable, Identifiable {
    let id: String
    let title: String
    let category: String
    let language: CodeLanguage
    let summary: String
    let code: String
}

enum PracticeCatalog {
    static let lessons: [PracticeLesson] = (try? load()) ?? []

    static func load(bundle: Bundle = .main) throws -> [PracticeLesson] {
        guard let url = bundle.url(forResource: "lessons", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([PracticeLesson].self, from: Data(contentsOf: url))
    }

    static var categories: [String] {
        lessons.reduce(into: []) { result, lesson in
            if !result.contains(lesson.category) { result.append(lesson.category) }
        }
    }
}

struct PracticeLine: Equatable {
    let sourceIndex: Int
    let text: String
}

/// A small lexical scanner, not a compiler. It removes comments while preserving
/// quoted strings, Python triple-quoted strings, raw strings and preprocessor lines.
/// Python docstrings remain code: they are string literals, not hash comments.
enum CommentFilter {
    static func lines(_ source: [String], language: CodeLanguage, skippingComments: Bool) -> [PracticeLine] {
        guard skippingComments, language != .plainText else {
            return source.enumerated().map { PracticeLine(sourceIndex: $0.offset, text: $0.element) }
        }
        var blockDepth = 0
        var stringEnd: [Character] = []
        var escapes = false
        var result: [PracticeLine] = []
        for (lineIndex, line) in source.enumerated() {
            let chars = Array(line)
            var output = ""
            var index = 0
            var hadComment = blockDepth > 0
            func matches(_ token: [Character], at position: Int) -> Bool {
                !token.isEmpty && position + token.count <= chars.count && Array(chars[position..<(position + token.count)]) == token
            }
            func matches(_ token: String, at position: Int) -> Bool { matches(Array(token), at: position) }
            while index < chars.count {
                if blockDepth > 0 {
                    hadComment = true
                    if matches("*/", at: index) {
                        blockDepth -= 1
                        index += 2
                    } else if language == .rust && matches("/*", at: index) {
                        blockDepth += 1
                        index += 2
                    } else { index += 1 }
                    continue
                }
                if !stringEnd.isEmpty {
                    if escapes && chars[index] == "\\" {
                        output.append(chars[index])
                        index += 1
                        if index < chars.count { output.append(chars[index]); index += 1 }
                    } else if matches(stringEnd, at: index) {
                        output += String(stringEnd)
                        index += stringEnd.count
                        stringEnd = []
                    } else { output.append(chars[index]); index += 1 }
                    continue
                }
                if (language == .python && chars[index] == "#") ||
                    (language != .python && matches("//", at: index)) {
                    hadComment = true
                    break
                }
                if language != .python && matches("/*", at: index) {
                    hadComment = true
                    blockDepth = 1
                    // Preserve token separation in expressions such as a/* note */+b.
                    output += " "
                    index += 2
                    continue
                }
                // C++ raw strings: R"delimiter(contents)delimiter".
                if language == .cpp && matches("R\"", at: index),
                   let opening = chars[(index + 2)...].firstIndex(of: "("), opening - index <= 18 {
                    let delimiter = String(chars[(index + 2)..<opening])
                    stringEnd = Array(")" + delimiter + "\"")
                    escapes = false
                    output += String(chars[index...opening])
                    index = opening + 1
                    continue
                }
                // Rust raw strings: r"..." or r###"..."### (also handles br prefixes).
                if language == .rust && chars[index] == "r" {
                    var opening = index + 1
                    while opening < chars.count && chars[opening] == "#" { opening += 1 }
                    if opening < chars.count && chars[opening] == "\"" {
                        stringEnd = Array("\"" + String(repeating: "#", count: opening - index - 1))
                        escapes = false
                        output += String(chars[index...opening])
                        index = opening + 1
                        continue
                    }
                }
                if language == .go && chars[index] == "`" {
                    stringEnd = ["`"]
                    escapes = false
                    output.append(chars[index]); index += 1
                    continue
                }
                if chars[index] == "\"" || chars[index] == "'" {
                    let quote = chars[index]
                    // Rust lifetimes are not character literals.
                    if language == .rust && quote == "'" && index + 1 < chars.count &&
                        (chars[index + 1].isLetter || chars[index + 1] == "_") &&
                        !(index + 2 < chars.count && chars[index + 2] == "'") {
                        output.append(quote); index += 1
                        continue
                    }
                    let triple = String(repeating: String(quote), count: 3)
                    stringEnd = language == .python && matches(triple, at: index) ? Array(triple) : [quote]
                    escapes = true
                    output += String(stringEnd)
                    index += stringEnd.count
                    continue
                }
                output.append(chars[index]); index += 1
            }
            if hadComment {
                while output.last == " " || output.last == "\t" { output.removeLast() }
                if output.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            }
            result.append(PracticeLine(sourceIndex: lineIndex, text: output))
        }
        return result
    }
}
