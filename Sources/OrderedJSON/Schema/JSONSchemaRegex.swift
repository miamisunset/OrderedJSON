import Foundation

/// A thread-safe wrapper around `NSRegularExpression` that conforms to `Sendable`,
/// `Hashable`, and `Equatable`.  Equality is based on the pattern string only.
internal final class SendableRegex: @unchecked Sendable, Hashable {
  let pattern: String
  let regex: NSRegularExpression

  init(pattern: String) throws {
    self.pattern = pattern
    self.regex = try NSRegularExpression(pattern: pattern, options: [])
  }

  static func == (lhs: SendableRegex, rhs: SendableRegex) -> Bool {
    lhs.pattern == rhs.pattern
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(pattern)
  }
}
