import Foundation
import OrderedCollections

extension JSON {
  /// Options for configuring JSON parser behavior.
  ///
  /// Use `ParserOptions` to customize parsing behavior such as
  /// allowing trailing commas or setting a maximum nesting depth.
  ///
  /// ## Example
  ///
  /// ```swift
  /// var opts = JSON.ParserOptions()
  /// opts.allowTrailingCommas = true
  /// opts.maxDepth = 512
  /// let json = try JSON.parse("[1,2,3,]", options: opts)
  /// ```
  public struct ParserOptions: Sendable {
    /// Whether to allow trailing commas in objects and arrays.
    /// When `true`, inputs like `[1,2,]` will parse successfully.
    /// Default: `false`
    public var allowTrailingCommas: Bool

    /// The maximum nesting depth allowed during parsing.
    /// Inputs deeper than this limit will throw `depthExceeded`.
    /// Default: `1024`
    public var maxDepth: Int

    /// Creates a parser options configuration.
    /// - Parameters:
    ///   - allowTrailingCommas: Whether to allow trailing commas in objects and arrays.
    ///   - maxDepth: The maximum nesting depth allowed during parsing.
    public init(allowTrailingCommas: Bool = false, maxDepth: Int = 1024) {
      self.allowTrailingCommas = allowTrailingCommas
      self.maxDepth = maxDepth
    }

    /// Default parser options (no trailing commas, max depth 1024).
    public static let `default` = ParserOptions()
  }

  // MARK: - Parse from String

  /// Parses JSON from a string, preserving key order in objects.
  ///
  /// Uses a recursive descent parser that iterates through the input
  /// character-by-character. Unlike `Codable`, this method directly
  /// constructs `JSON` values without going through an intermediate
  /// representation, preserving the original key order from the input.
  ///
  /// - Parameter jsonString: A valid JSON string.
  /// - Returns: A `JSON` value parsed from the string.
  /// - Throws: `JSONParseError` if the input is not valid JSON.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = try JSON.parse(#"{"b":1,"a":2}"#)
  /// json["b"]  // 1
  /// json["a"]  // 2
  /// // Keys are in order: "b", "a"
  /// ```
  public static func parse(_ jsonString: String) throws -> JSON {
    try parse(jsonString, options: .default)
  }

  /// Parses JSON from a string with custom parser options.
  ///
  /// - Parameters:
  ///   - jsonString: A valid JSON string.
  ///   - options: Parser configuration (trailing commas, max depth, etc.).
  /// - Returns: A `JSON` value parsed from the string.
  /// - Throws: `JSONParseError` if the input is not valid JSON.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let opts = JSON.ParserOptions(allowTrailingCommas: true)
  /// let json = try JSON.parse("[1,2,]", options: opts)
  /// ```
  public static func parse(_ jsonString: String, options: ParserOptions) throws -> JSON {
    var context = ParseContext(
      string: jsonString,
      pos: jsonString.startIndex,
      options: options,
      line: 1,
      column: 1,
      depth: 0
    )
    let value = try parseValue(&context)
    skipWhitespace(&context)
    if context.pos != context.string.endIndex {
      throw error(at: context, kind: .unexpectedToken)
    }
    return value
  }

  // MARK: - Parse from Data

  /// Parses JSON from a `Data` value, preserving key order in objects.
  ///
  /// The data is decoded as UTF-8 text before parsing.
  ///
  /// - Parameter data: A `Data` value containing UTF-8 encoded JSON.
  /// - Returns: A `JSON` value parsed from the data.
  /// - Throws: `JSONParseError` if the input is not valid JSON or not valid UTF-8.
  ///
  /// ## Example
  /// ```swift
  /// let data = Data(#"{"a":1}"#.utf8)
  /// let json = try JSON.parse(data)
  /// ```
  public static func parse(_ data: Data) throws -> JSON {
    try parse(data, options: .default)
  }

  /// Parses JSON from a `Data` value with custom parser options.
  ///
  /// - Parameters:
  ///   - data: A `Data` value containing UTF-8 encoded JSON.
  ///   - options: Parser configuration (trailing commas, max depth, etc.).
  /// - Returns: A `JSON` value parsed from the data.
  /// - Throws: `JSONParseError` if the input is not valid JSON or not valid UTF-8.
  public static func parse(_ data: Data, options: ParserOptions) throws -> JSON {
    guard let string = String(data: data, encoding: .utf8) else {
      throw JSONParseError.invalidEncoding()
    }
    return try parse(string, options: options)
  }

  // MARK: - Internal parse context

  /// Tracks parser state: current position, line/column, depth, and options.
  internal struct ParseContext {
    /// The source string being parsed.
    let string: String
    /// Current position in the string.
    var pos: String.Index
    /// Parser options.
    let options: ParserOptions
    /// Current line number (1-based).
    private(set) var line: Int
    /// Current column number (1-based).
    private(set) var column: Int
    /// Current nesting depth (0 = root).
    var depth: Int

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
  }

  /// Creates a `JSONParseError` at the current context position.
  private static func error(at ctx: ParseContext, kind: ErrorKind) -> JSONParseError {
    switch kind {
    case .unexpectedToken:
      return JSONParseError.unexpectedToken(line: ctx.line, column: ctx.column)
    case .expectedString:
      return JSONParseError.expectedString(line: ctx.line, column: ctx.column)
    case .expectedColon:
      return JSONParseError.expectedColon(line: ctx.line, column: ctx.column)
    case .expectedCloseBrace:
      return JSONParseError.expectedCloseBrace(line: ctx.line, column: ctx.column)
    case .expectedCloseBracket:
      return JSONParseError.expectedCloseBracket(line: ctx.line, column: ctx.column)
    case .invalidEscape:
      return JSONParseError.invalidEscape(line: ctx.line, column: ctx.column)
    case .invalidUnicodeEscape:
      return JSONParseError.invalidUnicodeEscape(line: ctx.line, column: ctx.column)
    case .invalidNumber:
      return JSONParseError.invalidNumber(line: ctx.line, column: ctx.column)
    case .depthExceeded:
      return JSONParseError.depthExceeded(
        line: ctx.line, column: ctx.column,
        depth: ctx.depth, maxDepth: ctx.options.maxDepth)
    }
  }

  private enum ErrorKind {
    case unexpectedToken, expectedString, expectedColon, expectedCloseBrace
    case expectedCloseBracket, invalidEscape, invalidUnicodeEscape, invalidNumber
    case depthExceeded
  }

  // MARK: - Value dispatch

  private static func parseValue(_ ctx: inout ParseContext) throws -> JSON {
    skipWhitespace(&ctx)
    guard ctx.pos < ctx.string.endIndex else {
      throw JSONParseError.unexpectedEnd()
    }
    let c = ctx.string[ctx.pos]
    switch c {
    case "{":
      return try parseObject(&ctx)
    case "[":
      return try parseArray(&ctx)
    case "\"":
      return try parseStringValue(&ctx)
    case "t", "f":
      return try parseBoolean(&ctx)
    case "n":
      return try parseNull(&ctx)
    case "-", "0"..."9":
      return try parseNumber(&ctx)
    default:
      throw error(at: ctx, kind: .unexpectedToken)
    }
  }

  // MARK: - Object

  private static func parseObject(_ ctx: inout ParseContext) throws -> JSON {
    ctx.advance()  // skip '{'
    ctx.depth += 1
    if ctx.depth > ctx.options.maxDepth {
      throw error(at: ctx, kind: .depthExceeded)
    }
    var object = OrderedDictionary<String, JSON>()
    skipWhitespace(&ctx)
    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "}" {
      ctx.depth -= 1
      ctx.advance()
      return .object(object)
    }
    repeat {
      skipWhitespace(&ctx)
      let key = try parseString(&ctx)
      skipWhitespace(&ctx)
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == ":" else {
        throw error(at: ctx, kind: .expectedColon)
      }
      ctx.advance()
      let value = try parseValue(&ctx)
      object[key] = value
      skipWhitespace(&ctx)
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "," else { break }
      ctx.advance()
      // Check for trailing comma: if next token (after whitespace) is }, stop.
      skipWhitespace(&ctx)
      if ctx.pos < ctx.string.endIndex,
        ctx.string[ctx.pos] == "}",
        ctx.options.allowTrailingCommas
      {
        break
      }
    } while true
    guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "}" else {
      throw error(at: ctx, kind: .expectedCloseBrace)
    }
    ctx.depth -= 1
    ctx.advance()
    return .object(object)
  }

  // MARK: - Array

  private static func parseArray(_ ctx: inout ParseContext) throws -> JSON {
    ctx.advance()  // skip '['
    ctx.depth += 1
    if ctx.depth > ctx.options.maxDepth {
      throw error(at: ctx, kind: .depthExceeded)
    }
    var elements: [JSON] = []
    skipWhitespace(&ctx)
    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "]" {
      ctx.depth -= 1
      ctx.advance()
      return .array(elements)
    }
    repeat {
      elements.append(try parseValue(&ctx))
      skipWhitespace(&ctx)
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "," else { break }
      ctx.advance()
      // Check for trailing comma: if next token (after whitespace) is ], stop.
      skipWhitespace(&ctx)
      if ctx.pos < ctx.string.endIndex,
        ctx.string[ctx.pos] == "]",
        ctx.options.allowTrailingCommas
      {
        break
      }
    } while true
    guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "]" else {
      throw error(at: ctx, kind: .expectedCloseBracket)
    }
    ctx.depth -= 1
    ctx.advance()
    return .array(elements)
  }

  // MARK: - String

  private static func parseStringValue(_ ctx: inout ParseContext) throws -> JSON {
    return .string(try parseString(&ctx))
  }

  private static func parseString(_ ctx: inout ParseContext) throws -> String {
    guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "\"" else {
      throw error(at: ctx, kind: .expectedString)
    }
    ctx.advance()
    var result = ""
    while ctx.pos < ctx.string.endIndex {
      let c = ctx.string[ctx.pos]
      if c == "\"" {
        ctx.advance()
        return result
      }
      if c == "\\" {
        ctx.advance()
        guard ctx.pos < ctx.string.endIndex else {
          throw JSONParseError.unexpectedEnd()
        }
        let escaped = ctx.string[ctx.pos]
        switch escaped {
        case "\"":
          result += "\""
          ctx.advance()
        case "\\":
          result += "\\"
          ctx.advance()
        case "/":
          result += "/"
          ctx.advance()
        case "n":
          result += "\n"
          ctx.advance()
        case "r":
          result += "\r"
          ctx.advance()
        case "t":
          result += "\t"
          ctx.advance()
        case "b":
          result += "\u{8}"
          ctx.advance()
        case "f":
          result += "\u{0C}"
          ctx.advance()
        case "u":
          result += try parseUnicodeEscape(&ctx)
        default:
          throw error(at: ctx, kind: .invalidEscape)
        }
      } else {
        result.append(c)
        ctx.advance()
      }
    }
    throw JSONParseError.unexpectedEnd()
  }

  // MARK: - Unicode escape with surrogate pair support

  private static func parseUnicodeEscape(_ ctx: inout ParseContext) throws -> String {
    ctx.advance()  // skip 'u'
    let hexDigits = readHexDigits(&ctx)
    guard hexDigits.count == 4, let scalar = UInt16(hexDigits, radix: 16) else {
      throw error(at: ctx, kind: .invalidUnicodeEscape)
    }

    // Check for high surrogate (U+D800..U+DBFF)
    if scalar >= 0xD800 && scalar <= 0xDBFF {
      // Expect a low surrogate (U+DC00..U+DFFF) following as \uXXXX
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "\\" else {
        throw error(at: ctx, kind: .invalidUnicodeEscape)
      }
      ctx.advance()
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "u" else {
        throw error(at: ctx, kind: .invalidUnicodeEscape)
      }
      ctx.advance()
      let lowHex = readHexDigits(&ctx)
      guard lowHex.count == 4, let low = UInt16(lowHex, radix: 16) else {
        throw error(at: ctx, kind: .invalidUnicodeEscape)
      }
      guard low >= 0xDC00 && low <= 0xDFFF else {
        throw error(at: ctx, kind: .invalidUnicodeEscape)
      }

      // Combine high and low surrogates into a single Unicode scalar
      let highOffset = UInt32(scalar - 0xD800)
      let lowOffset = UInt32(low - 0xDC00)
      let codePoint = 0x10000 + (highOffset << 10) + lowOffset
      guard let unicodeScalar = UnicodeScalar(codePoint) else {
        throw error(at: ctx, kind: .invalidUnicodeEscape)
      }
      return String(unicodeScalar)
    }

    return String(UnicodeScalar(scalar)!)
  }

  /// Reads 4 hex digits from the current position (or fewer if at end).
  private static func readHexDigits(_ ctx: inout ParseContext) -> String {
    var result = ""
    for _ in 0..<4 {
      guard ctx.pos < ctx.string.endIndex else { break }
      let c = ctx.string[ctx.pos]
      guard c.isHexDigit else { break }
      result.append(c)
      ctx.advance()
    }
    return result
  }

  // MARK: - Boolean

  private static func parseBoolean(_ ctx: inout ParseContext) throws -> JSON {
    if ctx.string[ctx.pos] == "t" {
      guard ctx.string[ctx.pos...].starts(with: "true") else {
        throw error(at: ctx, kind: .unexpectedToken)
      }
      ctx.advance()
      ctx.advance()
      ctx.advance()
      ctx.advance()
      return .boolean(true)
    }
    guard ctx.string[ctx.pos...].starts(with: "false") else {
      throw error(at: ctx, kind: .unexpectedToken)
    }
    ctx.advance()
    ctx.advance()
    ctx.advance()
    ctx.advance()
    ctx.advance()
    return .boolean(false)
  }

  // MARK: - Null

  private static func parseNull(_ ctx: inout ParseContext) throws -> JSON {
    guard ctx.string[ctx.pos...].starts(with: "null") else {
      throw error(at: ctx, kind: .unexpectedToken)
    }
    ctx.advance()
    ctx.advance()
    ctx.advance()
    ctx.advance()
    return .null
  }

  // MARK: - Number

  private static func parseNumber(_ ctx: inout ParseContext) throws -> JSON {
    let start = ctx.pos
    let startLine = ctx.line
    let startColumn = ctx.column

    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "-" {
      ctx.advance()
    }
    // Integer part
    while ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9" {
      ctx.advance()
    }
    var isFloat = false
    // Fractional part
    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "." {
      isFloat = true
      ctx.advance()
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9"
      else {
        throw JSONParseError.unexpectedEnd()
      }
      while ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9" {
        ctx.advance()
      }
    }
    // Exponent part
    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "e" || ctx.string[ctx.pos] == "E" {
      isFloat = true
      ctx.advance()
      if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "+" || ctx.string[ctx.pos] == "-" {
        ctx.advance()
      }
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9"
      else {
        throw JSONParseError.unexpectedEnd()
      }
      while ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9" {
        ctx.advance()
      }
    }

    // Substring slice on String.Index is O(1); no copying.
    let numString = String(ctx.string[start..<ctx.pos])
    if isFloat {
      return .number(.float(try parseDouble(numString, line: startLine, column: startColumn)))
    }
    if let intValue = Int64(numString) {
      return .number(.integer(intValue))
    }
    // Values > Int64.max or < Int64.min are still valid JSON numbers.
    // Fall back to Double (matching nlohmann/json's behavior).
    // Note: values near Int64.max (e.g., 9223372036854775808 = Int64.max + 1)
    // lose precision when stored as Double(9.22e18) — this is intentional
    // and documented. Binary format decoders follow the same policy.
    guard let floatValue = Double(numString) else {
      throw error(at: ctx, kind: .invalidNumber)
    }
    return .number(.float(floatValue))
  }

  private static func parseDouble(_ s: String, line: Int, column: Int) throws -> Double {
    guard let d = Double(s), d.isFinite else {
      throw JSONParseError.invalidNumber(line: line, column: column)
    }
    return d
  }

  // MARK: - Whitespace

  private static func skipWhitespace(_ ctx: inout ParseContext) {
    while ctx.pos < ctx.string.endIndex {
      switch ctx.string[ctx.pos] {
      case " ", "\n", "\r", "\t":
        ctx.advance()
      default:
        return
      }
    }
  }
}

// MARK: - Character extension for hex digit check

extension Character {
  /// Returns `true` if this character is a hexadecimal digit (0-9, A-F, a-f).
  package var isHexDigit: Bool {
    return ("0"..."9" ~= self) || ("A"..."F" ~= self) || ("a"..."f" ~= self)
  }
}
