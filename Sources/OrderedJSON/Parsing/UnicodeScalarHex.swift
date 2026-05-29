/// Named constants for common Unicode scalar values used in JSON parsing.
/// Improves readability over raw hex literals throughout the parser.
/// Named constants for common Unicode scalar values used in JSON parsing.
/// Improves readability over raw hex literals throughout the parser.
package enum UnicodeScalarHex {
  /// Space character (U+0020).
  static let space: UInt32 = 0x20
  /// Newline character (U+000A).
  static let newline: UInt32 = 0x0A
  /// Carriage return character (U+000D).
  static let carriageReturn: UInt32 = 0x0D
  /// Tab character (U+0009).
  static let tab: UInt32 = 0x09
  /// Double-quote character (U+0022).
  static let quote: UInt32 = 0x22
  /// Left curly brace (U+007B).
  static let openBrace: UInt32 = 0x7B
  /// Right curly brace (U+007D).
  static let closeBrace: UInt32 = 0x7D
  /// Left square bracket (U+005B).
  static let openBracket: UInt32 = 0x5B
  /// Right square bracket (U+005D).
  static let closeBracket: UInt32 = 0x5D
  /// Colon character (U+003A).
  static let colon: UInt32 = 0x3A
  /// Comma character (U+002C).
  static let comma: UInt32 = 0x2C
  /// Backslash character (U+005C).
  static let backslash: UInt32 = 0x5C
  /// Minus/hyphen character (U+002D).
  static let minus: UInt32 = 0x2D
  /// Period/dot character (U+002E).
  static let dot: UInt32 = 0x2E
  /// Slash character (U+002F).
  static let slash: UInt32 = 0x2F
  /// Plus character (U+002B).
  static let plus: UInt32 = 0x2B
  /// Lowercase `e` (U+0065).
  static let eLower: UInt32 = 0x65
  /// Uppercase `E` (U+0045).
  static let eUpper: UInt32 = 0x45
  /// Lowercase `r` (U+0072).
  static let r: UInt32 = 0x72
  /// Lowercase `u` (U+0075).
  static let u: UInt32 = 0x75
  /// Lowercase `a` (U+0061).
  static let a: UInt32 = 0x61
  /// Lowercase `l` (U+006C).
  static let l: UInt32 = 0x6C
  /// Lowercase `s` (U+0073).
  static let s: UInt32 = 0x73
  /// Lowercase `b` (U+0062).
  static let b: UInt32 = 0x62
  /// Lowercase `f` (U+0066).
  static let f: UInt32 = 0x66
  /// Lowercase `n` (U+006E).
  static let n: UInt32 = 0x6E
  /// Lowercase `t` (U+0074).
  static let t: UInt32 = 0x74
  /// Zero character (U+0030).
  static let zero: UInt32 = 0x30
  /// Nine character (U+0039).
  static let nine: UInt32 = 0x39
  /// Uppercase `A` (U+0041), for hex parsing.
  static let hexA: UInt32 = 0x41
  /// Uppercase `F` (U+0046), for hex parsing.
  static let hexF: UInt32 = 0x46
  /// Lowercase `a` (U+0061), for hex parsing.
  static let hexa: UInt32 = 0x61
  /// Lowercase `f` (U+0066), for hex parsing.
  static let hexf: UInt32 = 0x66
}
