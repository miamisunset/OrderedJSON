import Foundation

/// Shared cursor for recursive descent JSON parsing.
///
/// Tracks position in a source string, with line/column accounting.
/// Used by both the tree-building parser (`JSONParser`) and the
/// SAX/callback parser (`JSONSAX`) to avoid duplicating position
/// management.
///
/// ## Typical usage
///
/// Both parser files wrap `ParseCursor` in their own context struct:
///
/// ```swift
/// struct MyContext {
///   var cursor: ParseCursor
///   var extraField: T
///   mutating func advance() { cursor.advance() }
/// }
/// ```
internal struct ParseCursor {
  /// The source string being parsed.
  let string: String
  /// Current position in the string.
  var pos: String.Index
  /// Current line number (1-based).
  var line: Int
  /// Current column number (1-based).
  var column: Int

  /// Creates a cursor positioned at the start of `string`.
  init(string: String) {
    self.string = string
    self.pos = string.startIndex
    self.line = 1
    self.column = 1
  }

  /// Advance one character, updating line/column.
  mutating func advance() {
    let c = string[pos]
    pos = string.index(after: pos)
    if c == "\n" {
      line += 1
      column = 1
    } else {
      column += 1
    }
  }

  /// Returns `true` if there are more characters to read.
  var hasMore: Bool { pos < string.endIndex }

  /// The character at the current position, or `nil` if at end.
  var current: Character? {
    guard hasMore else { return nil }
    return string[pos]
  }
}

// MARK: - Shared parsing primitives

extension ParseCursor {
  /// Skips whitespace characters (space, newline, carriage return, tab).
  mutating func skipWhitespace() {
    while hasMore {
      switch string[pos] {
      case " ", "\n", "\r", "\t":
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
      let c = string[pos]
      guard c.isHexDigit else { break }
      result.append(c)
      advance()
    }
    return result
  }
}
