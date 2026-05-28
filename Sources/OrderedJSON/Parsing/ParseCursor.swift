import Foundation

/// Shared cursor for recursive descent JSON parsing.
///
/// Tracks position in a source string by Unicode scalars (not grapheme clusters),
/// with line/column accounting. This ensures combining characters like U+302E
/// are treated as individual tokens rather than being merged with preceding
/// grapheme bases.
///
/// Note: `String.UnicodeScalarIndex` is not O(1) for arbitrary indexing (it's
/// O(n) in Unicode scalars), but `advance` is sequential so it's fine.
///
/// Used by both the tree-building parser (`JSONParser`) and the
/// SAX/callback parser (`JSONSAX`) to avoid duplicating position management.
struct ParseCursor {
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
    pos = string.unicodeScalars.startIndex
    line = 1
    column = 1
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
  var hasMore: Bool {
    pos < string.unicodeScalars.endIndex
  }

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

  // MARK: - Unicode scalar hex constants

  /// Named constants for common Unicode scalar values used in JSON parsing.
  /// Improves readability over raw hex literals throughout the parser.
  fileprivate enum UnicodeScalarHex {
    static let space: UInt32 = 0x20
    static let newline: UInt32 = 0x0A
    static let carriageReturn: UInt32 = 0x0D
    static let tab: UInt32 = 0x09
    static let quote: UInt32 = 0x22
    static let openBrace: UInt32 = 0x7B
    static let closeBrace: UInt32 = 0x7D
    static let openBracket: UInt32 = 0x5B
    static let closeBracket: UInt32 = 0x5D
    static let colon: UInt32 = 0x3A
    static let comma: UInt32 = 0x2C
    static let backslash: UInt32 = 0x5C
    static let minus: UInt32 = 0x2D
    static let dot: UInt32 = 0x2E
    static let eLower: UInt32 = 0x65
    static let eUpper: UInt32 = 0x45
    static let r: UInt32 = 0x72
    static let u: UInt32 = 0x75
    static let a: UInt32 = 0x61
    static let l: UInt32 = 0x6C
    static let s: UInt32 = 0x73
    static let b: UInt32 = 0x62
    static let f: UInt32 = 0x66
    static let n: UInt32 = 0x6E
    static let t: UInt32 = 0x74
    static let zero: UInt32 = 0x30
    static let nine: UInt32 = 0x39
    static let hexA: UInt32 = 0x41
    static let hexF: UInt32 = 0x46
    static let hexa: UInt32 = 0x61
    static let hexf: UInt32 = 0x66
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
