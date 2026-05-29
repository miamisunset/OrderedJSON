import Foundation

/// A thread-safe wrapper around `NSRegularExpression` that conforms to `Sendable`,
/// `Hashable`, and `Equatable`. Equality is based on the pattern string only.
///
/// `@unchecked Sendable` is safe because `NSRegularExpression` is only read
/// after initialization — it is never mutated. The regex is compiled once in
/// `init(pattern:)` and thereafter only accessed via `firstMatch(in:range:)`,
/// which is thread-safe for read-only use. No data races are introduced.
final class LockedRegex: @unchecked Sendable, Hashable {
  let pattern: String
  let regex: NSRegularExpression

  init(pattern: String) throws {
    self.pattern = pattern
    regex = try NSRegularExpression(pattern: pattern, options: [])
  }

  static func == (lhs: LockedRegex, rhs: LockedRegex) -> Bool {
    lhs.pattern == rhs.pattern
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(pattern)
  }
}
