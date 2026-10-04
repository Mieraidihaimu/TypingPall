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

enum LessonTrack: String, Codable, CaseIterable, Identifiable {
    case leetcode, lowLevelDesign, languages
    var id: String { rawValue }
    var title: String {
        switch self {
        case .leetcode: return "LeetCode"
        case .lowLevelDesign: return "Low-level design"
        case .languages: return "Languages & syntax"
        }
    }
}

struct PracticeLesson: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let track: LessonTrack
    let language: CodeLanguage
    let summary: String
    let code: String
    var family: String? = nil
    var triggers: [String]? = nil
    var prompts: [String]? = nil
    var invariant: String? = nil
    var mantra: String? = nil
    var pitfalls: [String]? = nil
    var anchors: [LessonAnchor]? = nil
    var keyLineIndices: [Int]? = nil
    var scaffoldLineIndices: [Int]? = nil
    var contrastWith: [String]? = nil
    var complexity: LessonComplexity? = nil
    var mutations: [LessonMutation]? = nil
}

enum PracticeCatalog {
    private static let loaded = loadResult()
    static var lessons: [PracticeLesson] { loaded.lessons }
    static var loadError: Error? { loaded.error }

    static func loadResult(bundle: Bundle = .main) -> (lessons: [PracticeLesson], error: Error?) {
        do { return (try load(bundle: bundle), nil) } catch { return ([], error) }
    }

    static func load(bundle: Bundle = .main) throws -> [PracticeLesson] {
        guard let url = bundle.url(forResource: "lessons", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode([PracticeLesson].self, from: Data(contentsOf: url))
    }

    /// Categories in catalog order, optionally limited to one track.
    static func categories(of lessons: [PracticeLesson], in track: LessonTrack? = nil) -> [String] {
        lessons.reduce(into: []) { result, lesson in
            if (track == nil || lesson.track == track) && !result.contains(lesson.category) { result.append(lesson.category) }
        }
    }

    /// The lessons that pass every filter, grouped by category in catalog order.
    static func sections(of lessons: [PracticeLesson], track: LessonTrack?, category: String?, search: String) -> [LessonSection] {
        let matching = lessons.filter {
            (track == nil || $0.track == track) && (category == nil || $0.category == category) &&
                (search.isEmpty || $0.searchableText.localizedCaseInsensitiveContains(search))
        }
        return categories(of: matching).map { title in LessonSection(title: title, lessons: matching.filter { $0.category == title }) }
    }
}

struct LessonSection: Identifiable, Equatable {
    let title: String
    let lessons: [PracticeLesson]
    var id: String { title }
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
