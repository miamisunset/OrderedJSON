import Foundation
import OrderedCollections

/// Errors thrown during JSON parsing.
///
/// `JSONParseError` provides detailed error information including the
/// position at which the error occurred. The `CustomStringConvertible`
/// conformance gives human-readable descriptions with line and column
/// numbers.
///
/// ## Example
///
/// ```swift
/// do {
///   let json = try JSON.parse("invalid")
/// } catch let error as JSONParseError {
///   print(error)  // "Unexpected token at line 1, column 1"
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
    case unexpectedToken(line: Int, column: Int)
    /// Expected a string value at the given position.
    case expectedString(line: Int, column: Int)
    /// Expected a colon (`:`) at the given position.
    case expectedColon(line: Int, column: Int)
    /// Expected a closing brace (`}`) at the given position.
    case expectedCloseBrace(line: Int, column: Int)
    /// Expected a closing bracket (`]`) at the given position.
    case expectedCloseBracket(line: Int, column: Int)
    /// An invalid escape sequence was found at the given position.
    case invalidEscape(line: Int, column: Int)
    /// An invalid Unicode escape (`\\u` followed by non-hex) was found.
    case invalidUnicodeEscape(line: Int, column: Int)
    /// An invalid number literal was found at the given position.
    case invalidNumber(line: Int, column: Int)
    /// The JSON input contains invalid UTF-8 encoding.
    case invalidEncoding
    /// The nesting depth exceeded the maximum allowed.
    case depthExceeded(line: Int, column: Int, depth: Int, maxDepth: Int)
  }

  public init(_ kind: Kind) { self.kind = kind }

  /// Creates an "unexpected end" error.
  public static func unexpectedEnd() -> JSONParseError { JSONParseError(.unexpectedEnd) }

  /// Creates an "unexpected token" error at the given line and column.
  public static func unexpectedToken(line: Int, column: Int) -> JSONParseError {
    JSONParseError(.unexpectedToken(line: line, column: column))
  }

  /// Creates an "expected string" error at the given line and column.
  public static func expectedString(line: Int, column: Int) -> JSONParseError {
    JSONParseError(.expectedString(line: line, column: column))
  }

  /// Creates an "expected colon" error at the given line and column.
  public static func expectedColon(line: Int, column: Int) -> JSONParseError {
    JSONParseError(.expectedColon(line: line, column: column))
  }

  /// Creates an "expected close brace" error at the given line and column.
  public static func expectedCloseBrace(line: Int, column: Int) -> JSONParseError {
    JSONParseError(.expectedCloseBrace(line: line, column: column))
  }

  /// Creates an "expected close bracket" error at the given line and column.
  public static func expectedCloseBracket(line: Int, column: Int) -> JSONParseError {
    JSONParseError(.expectedCloseBracket(line: line, column: column))
  }

  /// Creates an "invalid escape" error at the given line and column.
  public static func invalidEscape(line: Int, column: Int) -> JSONParseError {
    JSONParseError(.invalidEscape(line: line, column: column))
  }

  /// Creates an "invalid unicode escape" error at the given line and column.
  public static func invalidUnicodeEscape(line: Int, column: Int) -> JSONParseError {
    JSONParseError(.invalidUnicodeEscape(line: line, column: column))
  }

  /// Creates an "invalid number" error at the given line and column.
  public static func invalidNumber(line: Int, column: Int) -> JSONParseError {
    JSONParseError(.invalidNumber(line: line, column: column))
  }

  /// Creates an "invalid encoding" error.
  public static func invalidEncoding() -> JSONParseError {
    JSONParseError(.invalidEncoding)
  }

  /// Creates a "depth exceeded" error at the given line and column.
  public static func depthExceeded(line: Int, column: Int, depth: Int, maxDepth: Int)
    -> JSONParseError
  {
    JSONParseError(.depthExceeded(line: line, column: column, depth: depth, maxDepth: maxDepth))
  }

  /// A human-readable description of this parse error.
  public var description: String {
    switch kind {
    case .unexpectedEnd:
      return "Unexpected end of JSON input"
    case .unexpectedToken(let line, let column):
      return "Unexpected token at line \(line), column \(column)"
    case .expectedString(let line, let column):
      return "Expected a string at line \(line), column \(column)"
    case .expectedColon(let line, let column):
      return "Expected ':' at line \(line), column \(column)"
    case .expectedCloseBrace(let line, let column):
      return "Expected '}' at line \(line), column \(column)"
    case .expectedCloseBracket(let line, let column):
      return "Expected ']' at line \(line), column \(column)"
    case .invalidEscape(let line, let column):
      return "Invalid escape sequence at line \(line), column \(column)"
    case .invalidUnicodeEscape(let line, let column):
      return "Invalid Unicode escape at line \(line), column \(column)"
    case .invalidNumber(let line, let column):
      return "Invalid number at line \(line), column \(column)"
    case .invalidEncoding:
      return "Invalid UTF-8 encoding in JSON input"
    case .depthExceeded(let line, let column, let depth, let maxDepth):
      return
        "Maximum nesting depth exceeded at line \(line), column \(column) (depth \(depth) > max \(maxDepth))"
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
