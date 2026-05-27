import Foundation

/// Shared cursor for recursive descent JSON parsing.
///
/// Tracks position in a source string by Unicode scalars (not grapheme clusters),
/// with line/column accounting. This ensures combining characters like U+302E
/// are treated as individual tokens rather than being merged with preceding
/// grapheme bases.
///
/// Used by both the tree-building parser (`JSONParser`) and the
/// SAX/callback parser (`JSONSAX`) to avoid duplicating position management.
internal struct ParseCursor {
  /// The source string being parsed.
  let string: String
  /// Current position in the Unicode scalar view.
  var pos: String.UnicodeScalarIndex
  /// Current line number (1-based).
  var line: Int
  /// Current column number (1-based).
  var column: Int

  /// Creates a cursor positioned at the start of `string`.
  init(string: String) {
    self.string = string
    self.pos = string.unicodeScalars.startIndex
    self.line = 1
    self.column = 1
  }

  /// Advance by one Unicode scalar, updating line/column.
  mutating func advance() {
    let s = string.unicodeScalars[pos]
    pos = string.unicodeScalars.index(after: pos)
    if s == "\n" {
      line += 1
      column = 1
    } else {
      column += 1
    }
  }

  /// Returns `true` if there are more Unicode scalars to read.
  var hasMore: Bool { pos < string.unicodeScalars.endIndex }

  /// The Unicode scalar at the current position, or `nil` if at end.
  var current: UnicodeScalar? {
    guard hasMore else { return nil }
    return string.unicodeScalars[pos]
  }
}

// MARK: - Shared parsing primitives

extension ParseCursor {
  /// Skips whitespace characters (space, newline, carriage return, tab).
  mutating func skipWhitespace() {
    while hasMore {
      let s = string.unicodeScalars[pos]
      switch s.value {
      case 0x20, 0x0A, 0x0D, 0x09:  // space, \n, \r, \t
        advance()
      default:
        return
      }
    }
  }

  /// Reads up to 4 hexadecimal digits from the current position.
  /// Returns the hex string (fewer than 4 characters if end-of-input
  /// or non-hex character is encountered).
  mutating func readHexDigits() -> String {
    var result = ""
    for _ in 0..<4 {
      guard hasMore else { break }
      let s = string.unicodeScalars[pos]
      guard isHexScalar(s.value) else { break }
      result.append(String(s))
      advance()
    }
    return result
  }

  /// Returns true if the given Unicode scalar value is a hex digit (0-9, A-F, a-f).
  private func isHexScalar(_ value: UInt32) -> Bool {
    return (value >= 0x30 && value <= 0x39) || (value >= 0x41 && value <= 0x46)
      || (value >= 0x61 && value <= 0x66)
  }
}
