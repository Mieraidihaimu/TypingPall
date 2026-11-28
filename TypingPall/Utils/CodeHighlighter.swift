import SwiftUI

enum CodeHighlighter {
    /// Tokenize the source as a whole so block comments and strings keep their style across rows.
    static func highlight(_ lines: [String], language: CodeLanguage) -> [AttributedString] {
        guard let grammar = grammars[language] else { return lines.map { AttributedString($0) } }
        let source = lines.joined(separator: "\n")
        let matches = grammar.pattern.matches(in: source, range: NSRange(source.startIndex..., in: source))
        var lineStart = 0
        var matchIndex = 0

        return lines.map { line in
            let lineEnd = lineStart + line.utf16.count
            var styled = AttributedString(line)
            while matchIndex < matches.count {
                let match = matches[matchIndex]
                guard match.range.location < lineEnd else { break }
                let matchEnd = NSMaxRange(match.range)
                let start = max(lineStart, match.range.location)
                let end = min(lineEnd, matchEnd)
                if start < end,
                   let color = grammar.color(for: match, in: source),
                   let range = Range(NSRange(location: start - lineStart, length: end - start), in: line),
                   let styledRange = Range(range, in: styled) {
                    styled[styledRange].foregroundColor = color
                }
                if matchEnd > lineEnd { break }
                matchIndex += 1
            }
            lineStart = lineEnd + 1
            return styled
        }
    }

    private static let grammars = Dictionary(uniqueKeysWithValues: CodeLanguage.allCases
        .filter { $0 != .plainText }
        .map { ($0, Grammar(language: $0)) })

    private struct Grammar {
        let pattern: NSRegularExpression
        let keywords: Set<String>
        let types: Set<String>
        let ignoresCase: Bool

        init(language: CodeLanguage) {
            keywords = CodeHighlighter.keywords(for: language)
            types = CodeHighlighter.types(for: language)
            ignoresCase = language == .sql

            let lineComment: String
            switch language {
            case .python, .ruby, .shell: lineComment = "#"
            case .sql, .lean4: lineComment = "--"
            default: lineComment = "//"
            }
            var comments = lineComment + #"[^\n]*"#
            if language == .lean4 {
                comments += #"|/-[\s\S]*?(?:-/|\z)"#
            } else if lineComment != "#" {
                comments += #"|/\*[\s\S]*?(?:\*/|\z)"#
            }

            var strings = [Self.quoted("\""), Self.quoted("'")]
            var directives: [String] = []
            switch language {
            case .python:
                let prefix = #"(?i:br|rb|fr|rf|tr|rt|[brfut])?"#
                strings = ["\"\"\"", "'''", "\"", "'"].map { prefix + Self.quoted($0, multiline: $0.count == 3) }
            case .cpp:
                let raw = #"(?:u8|u|U|L)?R"(?<delimiter>[^ ()\\\s]{0,16})\([\s\S]*?(?:\)\k<delimiter>"|\z)"#
                strings = [raw] + strings.map { "(?:u8|u|U|L)?" + $0 }
                directives = [#"(?<directive>(?m:^[ \t]*#[ \t]*[a-zA-Z_][a-zA-Z_0-9]*))"#]
            case .rust:
                // Require exactly one character or escape so lifetimes such as 'a are left alone.
                strings = [#"b?r(?<hashes>#{0,255})"[\s\S]*?(?:"\k<hashes>|\z)"#,
                           #"b?'(?:\\(?:u\{[0-9a-fA-F_]+\}|x[0-9a-fA-F]{2}|[^\n])|[^'\\\n])'"#,
                           "b?" + Self.quoted("\"", multiline: true)]
            case .go, .javascript, .typescript, .shell:
                strings.insert(Self.quoted("`", multiline: true, escapes: language != .go), at: 0)
            case .swift, .kotlin, .java:
                strings.insert(Self.quoted("\"\"\"", multiline: true, escapes: language != .kotlin), at: 0)
            case .sql:
                strings = [#"'(?:''|[^'])*+'?"#, #""(?:""|[^"])*+"?"#]
            default:
                break
            }

            let separator = language == .cpp ? "'" : "_"
            let digits = "[0-9][0-9\(separator)]*"
            let decimal = "(?:\(digits)(?:\\.\(digits)?)?|\\.\(digits))(?:[eE][+-]?\(digits))?"
            let based = "0(?:[xX][0-9a-fA-F][0-9a-fA-F\(separator)]*|[bB][01][01\(separator)]*|[oO][0-7][0-7\(separator)]*)"
            let suffix: String
            switch language {
            case .cpp: suffix = "[uUlLfF]*"
            case .python: suffix = "[jJ]?"
            default: suffix = ""
            }

            // Each match consumes a whole token, so later rules cannot recolor a string or comment.
            let tokens = directives + [
                "(?<comment>\(comments))",
                "(?<string>\(strings.joined(separator: "|")))",
                "(?<number>(?:\(based)|\(decimal))\(suffix))",
                #"(?<word>[\p{L}_$][\p{L}\p{M}\p{Nd}_$]*)"#
            ]
            pattern = try! NSRegularExpression(pattern: tokens.joined(separator: "|"))
        }

        private static func quoted(_ delimiter: String, multiline: Bool = false, escapes: Bool = true) -> String {
            let quote = NSRegularExpression.escapedPattern(for: delimiter)
            let character = multiline ? #"[\s\S]"# : #"[^\n]"#
            let escape = escapes ? #"\\[\s\S]?|"# : ""
            let excluded = escapes ? "\(quote)|\\\\" : quote
            return "\(quote)(?:\(escape)(?!\(excluded))\(character))*+\(quote)?"
        }

        func color(for match: NSTextCheckingResult, in source: String) -> Color? {
            if match.range(withName: "comment").location != NSNotFound { return TypingPalette.syntaxComment }
            if match.range(withName: "string").location != NSNotFound { return TypingPalette.syntaxString }
            if match.range(withName: "number").location != NSNotFound { return TypingPalette.syntaxNumber }
            if match.range(withName: "directive").location != NSNotFound { return TypingPalette.syntaxKeyword }
            guard let range = Range(match.range(withName: "word"), in: source) else { return nil }
            let word = ignoresCase ? source[range].uppercased() : String(source[range])
            if keywords.contains(word) { return TypingPalette.syntaxKeyword }
            if types.contains(word) { return TypingPalette.syntaxType }
            return nil
        }
    }

    private static func keywords(for language: CodeLanguage) -> Set<String> {
        switch language {
        case .python:
            return ["def", "class", "return", "if", "elif", "else", "while", "for", "in", "try", "except", "finally", "with", "as", "import", "from", "lambda", "yield", "raise", "pass", "break", "continue", "and", "or", "not", "is", "None", "True", "False", "self", "async", "await", "assert", "del", "global", "nonlocal"]
        case .cpp:
            return ["auto", "const", "static", "class", "struct", "public", "private", "protected", "virtual", "override", "template", "typename", "static_cast", "return", "if", "else", "while", "for", "new", "delete", "nullptr", "true", "false", "namespace", "using", "constexpr", "consteval", "constinit", "noexcept", "enum", "switch", "case", "default", "break", "continue", "do", "try", "catch", "throw", "concept", "requires", "co_await", "co_return", "co_yield"]
        case .rust:
            return ["fn", "let", "mut", "pub", "struct", "enum", "impl", "trait", "for", "in", "while", "loop", "match", "if", "else", "return", "true", "false", "self", "Self", "use", "mod", "crate", "as", "where", "type", "async", "await", "Some", "None", "Ok", "Err"]
        case .go:
            return ["func", "var", "const", "type", "struct", "interface", "package", "import", "return", "if", "else", "for", "range", "switch", "case", "default", "select", "go", "defer", "chan", "map", "make", "new", "nil", "true", "false"]
        case .ruby:
            return ["def", "end", "class", "module", "return", "if", "elsif", "else", "unless", "while", "until", "for", "in", "do", "yield", "self", "nil", "true", "false", "require", "include"]
        case .shell:
            return ["if", "then", "else", "elif", "fi", "for", "while", "do", "done", "case", "esac", "function", "return", "exit", "echo", "export", "local", "alias"]
        case .swift:
            return ["func", "var", "let", "class", "struct", "enum", "protocol", "extension", "init", "deinit", "return", "if", "guard", "else", "while", "for", "in", "switch", "case", "default", "break", "continue", "fallthrough", "import", "public", "private", "fileprivate", "internal", "open", "static", "mutating", "self", "Self", "super", "try", "catch", "throw", "throws", "async", "await", "true", "false", "nil"]
        case .typescript:
            return keywords(for: .javascript).union(["abstract", "as", "declare", "enum", "extends", "implements", "interface", "keyof", "namespace", "private", "protected", "public", "readonly", "satisfies", "type"])
        case .javascript:
            return ["function", "const", "let", "var", "class", "return", "if", "else", "while", "for", "of", "in", "switch", "case", "default", "break", "continue", "import", "export", "from", "default", "new", "this", "super", "try", "catch", "finally", "throw", "async", "await", "yield", "true", "false", "null", "undefined", "typeof", "instanceof"]
        case .sql:
            return ["SELECT", "FROM", "WHERE", "JOIN", "LEFT", "RIGHT", "INNER", "OUTER", "ON", "GROUP", "BY", "ORDER", "HAVING", "LIMIT", "OFFSET", "INSERT", "INTO", "VALUES", "UPDATE", "SET", "DELETE", "CREATE", "TABLE", "DROP", "ALTER", "AS", "DISTINCT", "AND", "OR", "NOT", "IN", "IS", "NULL", "WITH", "UNION", "CASE", "WHEN", "THEN", "ELSE", "END", "TRUE", "FALSE"]
        case .java:
            return ["public", "private", "protected", "class", "interface", "extends", "implements", "static", "final", "void", "return", "if", "else", "while", "for", "switch", "case", "default", "break", "continue", "new", "this", "super", "try", "catch", "finally", "throw", "throws", "import", "package", "true", "false", "null"]
        case .kotlin:
            return ["fun", "val", "var", "class", "interface", "object", "return", "if", "else", "while", "for", "in", "when", "is", "as", "break", "continue", "package", "import", "public", "private", "protected", "internal", "override", "open", "data", "sealed", "suspend", "this", "super", "null", "true", "false"]
        case .lean4:
            return ["theorem", "lemma", "def", "structure", "inductive", "class", "instance", "where", "by", "let", "have", "show", "fun", "match", "with", "if", "then", "else", "do", "return", "forall", "exists", "import", "open", "namespace", "section", "end", "private", "protected", "noncomputable", "deriving", "Prop", "Type", "Sort", "true", "false"]
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
        case .swift:
            return ["Int", "Double", "Float", "Bool", "String", "Character", "Array", "Dictionary", "Set", "Optional", "Result", "Any", "AnyObject"]
        case .javascript, .typescript:
            return ["number", "string", "boolean", "object", "symbol", "bigint", "any", "unknown", "never", "void", "Array", "Promise", "Map", "Set", "Record"]
        case .java:
            return ["int", "long", "float", "double", "boolean", "char", "byte", "short", "void", "String", "List", "Map", "Set", "ArrayList", "HashMap", "HashSet"]
        case .kotlin:
            return ["Int", "Long", "Float", "Double", "Boolean", "Char", "Byte", "Short", "String", "List", "Map", "Set", "Array"]
        case .sql:
            return ["INT", "INTEGER", "BIGINT", "VARCHAR", "TEXT", "BOOLEAN", "DATE", "TIMESTAMP", "FLOAT", "DECIMAL", "NUMERIC"]
        case .lean4:
            return ["Nat", "Int", "Bool", "String", "List", "Option", "Array", "ByteArray", "UInt32", "UInt64", "BitVec", "Fin", "PMF", "omega", "simp", "rcases", "rfl", "decide", "induction", "cases", "intro", "intros", "apply", "exact", "rw", "refine", "constructor", "split", "contradiction", "subst", "dsimp", "linarith", "ring", "positivity", "gcongr", "aesop", "norm_num"]
        default:
            return []
        }
    }
}
