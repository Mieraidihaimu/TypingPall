import Foundation

struct LineDiff: Equatable {
    let typed: String
    let target: String
    /// Character offset in `typed`; nil while `typed` is a correct prefix of `target`.
    let firstMismatch: Int?

    init(typed: String, target: String) {
        self.typed = typed
        self.target = target
        var expected = target.makeIterator(), offset = 0, mismatch: Int?
        for character in typed {
            guard character == expected.next() else { mismatch = offset; break }
            offset += 1
        }
        firstMismatch = mismatch
    }

    var isMatch: Bool { typed == target }
    /// UTF-16 range from the first mismatch to the end of `typed`, for text-view styling.
    var mismatchRange: NSRange? {
        guard let firstMismatch else { return nil }
        let location = typed.prefix(firstMismatch).utf16.count
        return NSRange(location: location, length: typed.utf16.count - location)
    }
    /// The target character at the first mismatch, or the next one to type.
    var expected: Character? {
        let offset = firstMismatch ?? typed.count
        guard offset < target.count else { return nil }
        return target[target.index(target.startIndex, offsetBy: offset)]
    }
}
