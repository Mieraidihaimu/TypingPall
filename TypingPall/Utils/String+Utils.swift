import Foundation
import SwiftUI

extension String {
    func extractMismatchedRange(comparedTo placeholder: String) -> NSRange? {
        guard !isEmpty else { return nil }
        let commonPrefix = self.commonPrefix(with: placeholder, options: .literal)
        guard commonPrefix.count < self.count else { return nil }
        return NSRange(location: commonPrefix.count, length: self.count - commonPrefix.count)
    }
}
