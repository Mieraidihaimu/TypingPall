import SwiftUI

struct ReferenceRow: Identifiable, Equatable {
    enum Marker: Equatable { case neededSecondLook, notTheBug, plantedBug, differs }
    let sourceIndex: Int
    let text: String
    var isCurrent = false
    var isSkipped = false
    var isMasked = false
    var marker: Marker? = nil
    var id: Int { sourceIndex }
}

struct ReferenceCodeView: View {
    let rows: [ReferenceRow]
    let fontSize: Double          // the typing size; rows draw at referenceFontSize(for:)
    let currentIndex: Int
    let contentKey: String        // changes when a new pattern loads → scroll to top
    var language: CodeLanguage = .plainText
    var onSelectRow: ((Int) -> Void)? = nil
    var minHeight: CGFloat = 180

    static func referenceFontSize(for typingSize: Double) -> Double { min(22, max(11, (typingSize * 0.7).rounded())) }

    static func split(_ line: String) -> (indent: String, code: String) {
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        return (String(indent), String(line.dropFirst(indent.count)))
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(rows) { row in
                        Group {
                            if let onSelectRow {
                                Button { onSelectRow(row.sourceIndex) } label: { content(of: row) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("referenceLine\(row.sourceIndex)")
                            } else {
                                content(of: row).accessibilityElement(children: .ignore)
                            }
                        }
                        .accessibilityLabel(spokenLabel(for: row))
                        .id(row.sourceIndex)
                    }
                }.padding(.vertical, 12)
            }
            .onChange(of: currentIndex) { index in
                withAnimation { proxy.scrollTo(index, anchor: .center) }
            }
            .onChange(of: contentKey) { _ in proxy.scrollTo(currentIndex, anchor: .top) }
        }
        .frame(minHeight: minHeight, idealHeight: 300)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func content(of row: ReferenceRow) -> some View {
        let line = Self.split(row.text)
        let codeView: Text
        if row.isMasked || row.isSkipped || language == .plainText {
            let base = Text(line.code.isEmpty ? " " : line.code)
            codeView = row.isSkipped ? base.italic() : base
        } else {
            let highlighted = CodeHighlighter.highlight(code: line.code.isEmpty ? " " : line.code, language: language)
            codeView = Text(highlighted)
        }
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("\(row.sourceIndex + 1)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 30, alignment: .trailing)
            Text(glyph(for: row))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 14)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(line.indent)
                codeView.frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.system(size: Self.referenceFontSize(for: fontSize), design: .monospaced))
        }
        .foregroundColor(row.isSkipped || row.isMasked ? .secondary : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(row.isCurrent ? Color.accentColor.opacity(0.15) : Color.clear)
        .overlay(alignment: .leading) {
            if row.isCurrent { Rectangle().fill(Color.accentColor).frame(width: 3) }
        }
        .contentShape(Rectangle())
    }

    private func glyph(for row: ReferenceRow) -> String {
        switch row.marker {
        case .neededSecondLook?: return "•"
        case .notTheBug?: return "○"
        case .plantedBug?: return "✕"
        case .differs?: return "≠"
        case nil: return row.isSkipped ? "⤼" : ""
        }
    }

    private func spokenLabel(for row: ReferenceRow) -> String {
        var parts = ["Line \(row.sourceIndex + 1)"]
        if row.isCurrent { parts.append("current line") }
        switch row.marker {
        case .neededSecondLook?: parts.append("needed a second look")
        case .notTheBug?: parts.append("not the bug")
        case .plantedBug?: parts.append("the bug")
        case .differs?: parts.append("differs")
        case nil: if row.isSkipped { parts.append("skipped") }
        }
        guard row.isMasked else { return parts.joined(separator: ", ") + ": " + row.text }
        let revealed = row.text.filter { $0 != "━" }.trimmingCharacters(in: .whitespaces)
        parts.append(revealed.isEmpty ? "hidden" : "hint: \(revealed)")
        return parts.joined(separator: ", ")
    }
}

enum CodeHighlighter {
    static func highlight(code: String, language: CodeLanguage) -> AttributedString {
        var attributed = AttributedString(code)
        guard language != .plainText, !code.isEmpty else { return attributed }

        let trimmed = code.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("//") || trimmed.hasPrefix("#") {
            attributed.foregroundColor = .secondary
            return attributed
        }

        let kw = keywords(for: language)
        let tp = types(for: language)

        highlightPattern(in: &attributed, text: code, pattern: "\"[^\"]*\"|'[^']*'", color: Color.orange)
        highlightPattern(in: &attributed, text: code, pattern: "\\b\\d+(\\.\\d+)?\\b", color: Color.teal)

        for keyword in kw {
            highlightWord(in: &attributed, text: code, word: keyword, color: Color.purple)
        }

        for typeName in tp {
            highlightWord(in: &attributed, text: code, word: typeName, color: Color.blue)
        }

        return attributed
    }

    private static func highlightPattern(in attributed: inout AttributedString, text: String, pattern: String, color: Color) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches {
            if let stringRange = Range(match.range, in: text),
               let attrRange = Range(stringRange, in: attributed) {
                attributed[attrRange].foregroundColor = color
            }
        }
    }

    private static func highlightWord(in attributed: inout AttributedString, text: String, word: String, color: Color) {
        let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
        highlightPattern(in: &attributed, text: text, pattern: pattern, color: color)
    }

    private static func keywords(for language: CodeLanguage) -> Set<String> {
        switch language {
        case .python:
            return ["def", "class", "return", "if", "elif", "else", "while", "for", "in", "try", "except", "finally", "with", "as", "import", "from", "lambda", "yield", "raise", "pass", "break", "continue", "and", "or", "not", "is", "None", "True", "False", "self", "async", "await"]
        case .cpp:
            return ["auto", "const", "static", "class", "struct", "public", "private", "protected", "virtual", "override", "template", "typename", "static_cast", "return", "if", "else", "while", "for", "new", "delete", "nullptr", "true", "false", "namespace", "using"]
        case .rust:
            return ["fn", "let", "mut", "pub", "struct", "enum", "impl", "trait", "for", "in", "while", "loop", "match", "if", "else", "return", "true", "false", "self", "Self", "use", "mod", "crate", "as", "where", "type", "async", "await", "Some", "None", "Ok", "Err"]
        case .go:
            return ["func", "var", "const", "type", "struct", "interface", "package", "import", "return", "if", "else", "for", "range", "switch", "case", "default", "select", "go", "defer", "chan", "map", "make", "new", "nil", "true", "false"]
        case .ruby:
            return ["def", "end", "class", "module", "return", "if", "elsif", "else", "unless", "while", "until", "for", "in", "do", "yield", "self", "nil", "true", "false", "require", "include"]
        case .shell:
            return ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "return", "exit", "echo", "export", "local", "alias"]
        case .plainText:
            return []
        }
    }

    private static func types(for language: CodeLanguage) -> Set<String> {
        switch language {
        case .python:
            return ["int", "str", "bool", "float", "list", "dict", "set", "tuple", "Optional", "List", "Dict", "Set"]
        case .cpp:
            return ["int", "long", "float", "double", "bool", "char", "void", "std", "vector", "string", "size_t", "pair", "unordered_map", "unordered_set"]
        case .rust:
            return ["i32", "i64", "u32", "u64", "usize", "isize", "f32", "f64", "bool", "char", "str", "String", "Vec", "Result", "Option"]
        case .go:
            return ["int", "int32", "int64", "uint", "uint32", "uint64", "string", "bool", "byte", "rune", "float32", "float64", "error"]
        default:
            return []
        }
    }
}

