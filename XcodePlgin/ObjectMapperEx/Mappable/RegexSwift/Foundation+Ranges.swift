internal extension NSTextCheckingResult {
  var ranges: [NSRange] {
    return stride(from: 0, to: numberOfRanges, by: 1).map(range)
  }
}

internal extension String {
  var entireRange: NSRange {
    return NSRange(location: 0, length: utf16.count)
  }
}

import Foundation
