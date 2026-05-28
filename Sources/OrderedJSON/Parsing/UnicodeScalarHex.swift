/// Named constants for common Unicode scalar values used in JSON parsing.
/// Improves readability over raw hex literals throughout the parser.
package enum UnicodeScalarHex {
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
  static let slash: UInt32 = 0x2F
  static let plus: UInt32 = 0x2B
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
