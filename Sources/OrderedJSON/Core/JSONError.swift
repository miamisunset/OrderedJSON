import Foundation
import OrderedCollections

/// Errors thrown during JSON parsing.
///
/// `JSONParseError` provides detailed error information including the
/// position at which the error occurred. The `CustomStringConvertible`
/// conformance gives human-readable descriptions.
///
/// ## Example
///
/// ```swift
/// do {
///   let json = try JSON.parse("invalid")
/// } catch let error as JSONParseError {
///   print(error)  // "Unexpected token at position 0"
/// }
/// ```
public struct JSONParseError: Error, CustomStringConvertible, Hashable, Sendable {
  /// The kind of parse error.
  public let kind: Kind

  /// Describes the specific category of parse error.
  public enum Kind: Hashable, Sendable {
    /// The JSON input ended unexpectedly.
    case unexpectedEnd
    /// An unexpected token was encountered at the given position.
    case unexpectedToken(Int)
    /// Expected a string value at the given position.
    case expectedString(Int)
    /// Expected a colon (`:`) at the given position.
    case expectedColon(Int)
    /// Expected a closing brace (`}`) at the given position.
    case expectedCloseBrace(Int)
    /// Expected a closing bracket (`]`) at the given position.
    case expectedCloseBracket(Int)
    /// An invalid escape sequence was found at the given position.
    case invalidEscape(Int)
    /// An invalid Unicode escape (`\\u` followed by non-hex) was found.
    case invalidUnicodeEscape(Int)
    /// An invalid number literal was found at the given position.
    case invalidNumber(Int)
  }

  public init(_ kind: Kind) { self.kind = kind }

  /// Creates an "unexpected end" error.
  public static func unexpectedEnd() -> JSONParseError { JSONParseError(.unexpectedEnd) }
  /// Creates an "unexpected token" error at the given position.
  public static func unexpectedToken(_ pos: Int) -> JSONParseError {
    JSONParseError(.unexpectedToken(pos))
  }
  /// Creates an "expected string" error at the given position.
  public static func expectedString(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedString(pos))
  }
  /// Creates an "expected colon" error at the given position.
  public static func expectedColon(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedColon(pos))
  }
  /// Creates an "expected close brace" error at the given position.
  public static func expectedCloseBrace(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedCloseBrace(pos))
  }
  /// Creates an "expected close bracket" error at the given position.
  public static func expectedCloseBracket(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedCloseBracket(pos))
  }
  /// Creates an "invalid escape" error at the given position.
  public static func invalidEscape(_ pos: Int) -> JSONParseError {
    JSONParseError(.invalidEscape(pos))
  }
  /// Creates an "invalid unicode escape" error at the given position.
  public static func invalidUnicodeEscape(_ pos: Int) -> JSONParseError {
    JSONParseError(.invalidUnicodeEscape(pos))
  }
  /// Creates an "invalid number" error at the given position.
  public static func invalidNumber(_ pos: Int) -> JSONParseError {
    JSONParseError(.invalidNumber(pos))
  }

  /// A human-readable description of this parse error.
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

/// General JSON errors not specific to parsing.
///
/// These errors are thrown by subscript accessors, pointer resolution,
/// patch operations, and binary format decoders.
///
/// ## Cases
///
/// - `invalidString` — invalid JSON pointer string format.
/// - `expectedObject` — operation requires an object value.
/// - `keyNotFound(String)` — a key was not found in a JSON object.
/// - `indexOutOfBounds(Int)` — an index was out of bounds for a JSON array.
/// - `typeError(expected:, actual:)` — type mismatch between expected and actual types.
/// - `invalidPatch(String)` — a JSON Patch or binary format error with a message.
public enum JSONError: Error, Sendable, Hashable {
  /// Invalid JSON pointer string format.
  case invalidString
  /// An operation that requires an object was given a non-object value.
  case expectedObject
  /// A key was not found in a JSON object.
  case keyNotFound(String)
  /// An index was out of bounds for a JSON array.
  case indexOutOfBounds(Int)
  /// A type mismatch occurred: `expected` and `actual` describe the conflict.
  case typeError(expected: String, actual: String)
  /// A JSON Patch or binary format error with a human-readable message.
  case invalidPatch(String)
}
