import Foundation
import OrderedCollections

public struct JSONParseError: Error, CustomStringConvertible, Hashable, Sendable {
  public let kind: Kind

  public enum Kind: Hashable, Sendable {
    case unexpectedEnd
    case unexpectedToken(Int)
    case expectedString(Int)
    case expectedColon(Int)
    case expectedCloseBrace(Int)
    case expectedCloseBracket(Int)
    case invalidEscape(Int)
    case invalidUnicodeEscape(Int)
    case invalidNumber(Int)
  }

  public init(_ kind: Kind) { self.kind = kind }

  public static func unexpectedEnd() -> JSONParseError { JSONParseError(.unexpectedEnd) }
  public static func unexpectedToken(_ pos: Int) -> JSONParseError {
    JSONParseError(.unexpectedToken(pos))
  }
  public static func expectedString(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedString(pos))
  }
  public static func expectedColon(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedColon(pos))
  }
  public static func expectedCloseBrace(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedCloseBrace(pos))
  }
  public static func expectedCloseBracket(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedCloseBracket(pos))
  }
  public static func invalidEscape(_ pos: Int) -> JSONParseError {
    JSONParseError(.invalidEscape(pos))
  }
  public static func invalidUnicodeEscape(_ pos: Int) -> JSONParseError {
    JSONParseError(.invalidUnicodeEscape(pos))
  }
  public static func invalidNumber(_ pos: Int) -> JSONParseError {
    JSONParseError(.invalidNumber(pos))
  }

  public var description: String {
    switch kind {
    case .unexpectedEnd: return "Unexpected end of JSON input"
    case .unexpectedToken(let pos): return "Unexpected token at position \(pos)"
    case .expectedString(let pos): return "Expected a string at position \(pos)"
    case .expectedColon(let pos): return "Expected ':' at position \(pos)"
    case .expectedCloseBrace(let pos): return "Expected '}' at position \(pos)"
    case .expectedCloseBracket(let pos): return "Expected ']' at position \(pos)"
    case .invalidEscape(let pos): return "Invalid escape sequence at position \(pos)"
    case .invalidUnicodeEscape(let pos): return "Invalid Unicode escape at position \(pos)"
    case .invalidNumber(let pos): return "Invalid number at position \(pos)"
    }
  }
}

public enum JSONError: Error, Sendable, Hashable {
  case invalidString
  case expectedObject
  case keyNotFound(String)
  case indexOutOfBounds(Int)
  case typeError(expected: String, actual: String)
  case invalidPatch(String)
}
