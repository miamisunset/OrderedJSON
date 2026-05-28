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

  /// Tracks parser state: cursor position, depth, and options.
  struct ParseContext {
    /// Shared position cursor.
    var cursor: ParseCursor
    /// Parser options.
    let options: ParserOptions
    /// Current nesting depth (0 = root).
    var depth: Int

    /// The source string being parsed.
    var string: String {
      cursor.string
    }

    /// Current position in the Unicode scalar view.
    var pos: String.UnicodeScalarIndex {
      cursor.pos
    }

    /// Current line number (1-based).
    var line: Int {
      cursor.line
    }

    /// Current column number (1-based).
    var column: Int {
      cursor.column
    }

    /// Advance by one Unicode scalar, updating line/column.
    mutating func advance() {
      cursor.advance()
    }

    /// The Unicode scalar at the current position, or `nil` if at end.
    var currentScalar: UnicodeScalar? {
      cursor.current
    }

    /// Creates a parse context from a source string.
    init(
      string: String, pos: String.UnicodeScalarIndex,
      options: ParserOptions, line: Int, column: Int, depth: Int
    ) {
      cursor = ParseCursor(string: string)
      cursor.pos = pos
      cursor.line = line
      cursor.column = column
      self.options = options
      self.depth = depth
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
        depth: ctx.depth, maxDepth: ctx.options.maxDepth
      )
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
    guard let s = ctx.currentScalar else {
      throw JSONParseError.unexpectedEnd()
    }
    switch s.value {
    case UnicodeScalarHex.openBrace:  // {
      return try parseObject(&ctx)
    case UnicodeScalarHex.openBracket:  // [
      return try parseArray(&ctx)
    case UnicodeScalarHex.quote:  // "
      return try parseStringValue(&ctx)
    case UnicodeScalarHex.t, UnicodeScalarHex.f:  // t, f
      return try parseBoolean(&ctx)
    case UnicodeScalarHex.n:  // n
      return try parseNull(&ctx)
    case UnicodeScalarHex.minus, UnicodeScalarHex.zero...UnicodeScalarHex.nine:  // -, 0-9
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
    skipWhitespace(&ctx)
    if let s = ctx.currentScalar, s.value == UnicodeScalarHex.closeBrace {  // }
      ctx.depth -= 1
      ctx.advance()
      return .object(OrderedDictionary<String, JSON>())
    }
    var object = OrderedDictionary<String, JSON>()
    repeat {
      skipWhitespace(&ctx)
      let key = try parseString(&ctx)
      skipWhitespace(&ctx)
      guard let s = ctx.currentScalar, s.value == UnicodeScalarHex.colon else {  // :
        throw error(at: ctx, kind: .expectedColon)
      }
      ctx.advance()
      let value = try parseValue(&ctx)
      object[key] = value
      skipWhitespace(&ctx)
      guard let s = ctx.currentScalar, s.value == UnicodeScalarHex.comma else { break }  // ,
      ctx.advance()
      // Check for trailing comma: if next token (after whitespace) is }, stop.
      skipWhitespace(&ctx)
      if let s = ctx.currentScalar,
        s.value == UnicodeScalarHex.closeBrace,  // }
        ctx.options.allowTrailingCommas
      {
        break
      }
    } while true
    guard let s = ctx.currentScalar, s.value == UnicodeScalarHex.closeBrace else {  // }
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
    skipWhitespace(&ctx)
    if let s = ctx.currentScalar, s.value == UnicodeScalarHex.closeBracket {  // ]
      ctx.depth -= 1
      ctx.advance()
      return .array([])
    }
    var elements: [JSON] = []
    repeat {
      try elements.append(parseValue(&ctx))
      skipWhitespace(&ctx)
      guard let s = ctx.currentScalar, s.value == UnicodeScalarHex.comma else { break }  // ,
      ctx.advance()
      // Check for trailing comma: if next token (after whitespace) is ], stop.
      skipWhitespace(&ctx)
      if let s = ctx.currentScalar,
        s.value == UnicodeScalarHex.closeBracket,  // ]
        ctx.options.allowTrailingCommas
      {
        break
      }
    } while true
    guard let s = ctx.currentScalar, s.value == UnicodeScalarHex.closeBracket else {  // ]
      throw error(at: ctx, kind: .expectedCloseBracket)
    }
    ctx.depth -= 1
    ctx.advance()
    return .array(elements)
  }

  // MARK: - String

  private static func parseStringValue(_ ctx: inout ParseContext) throws -> JSON {
    return try .string(parseString(&ctx))
  }

  private static func parseString(_ ctx: inout ParseContext) throws -> String {
    guard let s = ctx.currentScalar, s.value == UnicodeScalarHex.quote else {  // "
      throw error(at: ctx, kind: .expectedString)
    }
    ctx.advance()
    var result = ""
    while let s = ctx.currentScalar {
      if s.value == UnicodeScalarHex.quote {  // "
        ctx.advance()
        return result
      }
      if s.value == UnicodeScalarHex.backslash {  // \
        ctx.advance()
        guard let es = ctx.currentScalar else {
          throw JSONParseError.unexpectedEnd()
        }
        switch es.value {
        case UnicodeScalarHex.quote:  // "
          result += "\""
          ctx.advance()
        case UnicodeScalarHex.backslash:  // \
          result += "\\"
          ctx.advance()
        case UnicodeScalarHex.slash:  // /
          result += "/"
          ctx.advance()
        case UnicodeScalarHex.n:  // n
          result += "\n"
          ctx.advance()
        case UnicodeScalarHex.r:  // r
          result += "\r"
          ctx.advance()
        case UnicodeScalarHex.t:  // t
          result += "\t"
          ctx.advance()
        case UnicodeScalarHex.b:  // b
          result += "\u{8}"
          ctx.advance()
        case UnicodeScalarHex.f:  // f
          result += "\u{0C}"
          ctx.advance()
        case UnicodeScalarHex.u:  // u
          result += try parseUnicodeEscape(&ctx)
        default:
          throw error(at: ctx, kind: .invalidEscape)
        }
      } else {
        result.append(String(s))
        ctx.advance()
      }
    }
    throw JSONParseError.unexpectedEnd()
  }

  // MARK: - Unicode escape with surrogate pair support

  private static func parseUnicodeEscape(_ ctx: inout ParseContext) throws -> String {
    ctx.advance()  // skip 'u'
    let hexDigits = ctx.cursor.readHexDigits()
    guard hexDigits.count == 4, let scalar = UInt16(hexDigits, radix: 16) else {
      throw error(at: ctx, kind: .invalidUnicodeEscape)
    }

    // Check for high surrogate (U+D800..U+DBFF)
    if scalar >= 0xD800 && scalar <= 0xDBFF {
      // Expect a low surrogate (U+DC00..U+DFFF) following as \uXXXX
      guard ctx.cursor.hasMore, ctx.cursor.current?.value == UnicodeScalarHex.backslash else {  // \
        throw error(at: ctx, kind: .invalidUnicodeEscape)
      }
      ctx.cursor.advance()
      guard ctx.cursor.hasMore, ctx.cursor.current?.value == UnicodeScalarHex.u else {  // u
        throw error(at: ctx, kind: .invalidUnicodeEscape)
      }
      ctx.cursor.advance()
      let lowHex = ctx.cursor.readHexDigits()
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

    guard let unicodeScalar = UnicodeScalar(scalar) else {
      throw error(at: ctx, kind: .invalidUnicodeEscape)
    }
    return String(unicodeScalar)
  }

  /// Reads 4 hex digits from the current position (or fewer if at end).
  private static func readHexDigits(_ ctx: inout ParseContext) -> String {
    ctx.cursor.readHexDigits()
  }

  // MARK: - Boolean

  private static func parseBoolean(_ ctx: inout ParseContext) throws -> JSON {
    let end = ctx.string.unicodeScalars.endIndex
    if ctx.currentScalar?.value == UnicodeScalarHex.t {  // t
      // Manual lookahead for "true" — no Substring creation
      var idx = ctx.pos
      idx = ctx.string.unicodeScalars.index(after: idx)
      guard idx < end && ctx.string.unicodeScalars[idx].value == UnicodeScalarHex.r else {  // r
        throw error(at: ctx, kind: .unexpectedToken)
      }
      idx = ctx.string.unicodeScalars.index(after: idx)
      guard idx < end && ctx.string.unicodeScalars[idx].value == UnicodeScalarHex.u else {
        throw error(at: ctx, kind: .unexpectedToken)
      }
      idx = ctx.string.unicodeScalars.index(after: idx)
      guard idx < end && ctx.string.unicodeScalars[idx].value == UnicodeScalarHex.eLower else {
        throw error(at: ctx, kind: .unexpectedToken)
      }
      ctx.advance()
      ctx.advance()
      ctx.advance()
      ctx.advance()
      return .boolean(true)
    }
    // Manual lookahead for "false" — no Substring creation
    var idx = ctx.pos
    idx = ctx.string.unicodeScalars.index(after: idx)
    guard idx < end && ctx.string.unicodeScalars[idx].value == UnicodeScalarHex.a else {  // a
      throw error(at: ctx, kind: .unexpectedToken)
    }
    idx = ctx.string.unicodeScalars.index(after: idx)
    guard idx < end && ctx.string.unicodeScalars[idx].value == UnicodeScalarHex.l else {  // l
      throw error(at: ctx, kind: .unexpectedToken)
    }
    idx = ctx.string.unicodeScalars.index(after: idx)
    guard idx < end && ctx.string.unicodeScalars[idx].value == UnicodeScalarHex.s else {  // s
      throw error(at: ctx, kind: .unexpectedToken)
    }
    idx = ctx.string.unicodeScalars.index(after: idx)
    guard idx < end, ctx.string.unicodeScalars[idx].value == UnicodeScalarHex.eLower else {
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
    let end = ctx.string.unicodeScalars.endIndex
    var idx = ctx.pos
    idx = ctx.string.unicodeScalars.index(after: idx)
    guard idx < end && ctx.string.unicodeScalars[idx].value == UnicodeScalarHex.u else {  // u
      throw error(at: ctx, kind: .unexpectedToken)
    }
    idx = ctx.string.unicodeScalars.index(after: idx)
    guard idx < end && ctx.string.unicodeScalars[idx].value == UnicodeScalarHex.l else {  // l
      throw error(at: ctx, kind: .unexpectedToken)
    }
    idx = ctx.string.unicodeScalars.index(after: idx)
    guard idx < end && ctx.string.unicodeScalars[idx].value == UnicodeScalarHex.l else {  // l
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

    if let s = ctx.currentScalar, s.value == UnicodeScalarHex.minus {  // -
      ctx.advance()
    }
    // Integer part
    while let s = ctx.currentScalar, s.value >= UnicodeScalarHex.zero,
      s.value <= UnicodeScalarHex.nine
    {  // 0-9
      ctx.advance()
    }
    var isFloat = false
    // Fractional part
    if let s = ctx.currentScalar, s.value == UnicodeScalarHex.dot {  // .
      isFloat = true
      ctx.advance()
      guard let s = ctx.currentScalar, s.value >= UnicodeScalarHex.zero,
        s.value <= UnicodeScalarHex.nine
      else {  // 0-9
        throw JSONParseError.unexpectedEnd()
      }
      while let s = ctx.currentScalar, s.value >= UnicodeScalarHex.zero,
        s.value <= UnicodeScalarHex.nine
      {
        ctx.advance()
      }
    }
    // Exponent part
    if let s = ctx.currentScalar,
      s.value == UnicodeScalarHex.eLower || s.value == UnicodeScalarHex.eUpper
    {  // e, E
      isFloat = true
      ctx.advance()
      if let s = ctx.currentScalar,
        s.value == UnicodeScalarHex.plus || s.value == UnicodeScalarHex.minus
      {  // +, -
        ctx.advance()
      }
      guard let s = ctx.currentScalar, s.value >= UnicodeScalarHex.zero,
        s.value <= UnicodeScalarHex.nine
      else {  // 0-9
        throw JSONParseError.unexpectedEnd()
      }
      while let s = ctx.currentScalar, s.value >= UnicodeScalarHex.zero,
        s.value <= UnicodeScalarHex.nine
      {
        ctx.advance()
      }
    }

    // Substring slice on UnicodeScalar indices.
    let numString = String(ctx.string.unicodeScalars[start..<ctx.pos])
    if isFloat {
      return try .number(.float(parseDouble(numString, line: startLine, column: startColumn)))
    }
    if let intValue = Int64(numString) {
      return .number(.integer(intValue))
    }
    // Values > Int64.max or < Int64.min are still valid JSON numbers.
    // Fall back to Double (matching nlohmann/json's behavior).
    // Note: values near Int64.max (e.g., 9223372036854775808 = Int64.max + 1)
    // lose precision when stored as Double(9.22e18) — this is intentional
    // and documented. Binary format decoders follow the same policy.
    guard let floatValue = Double(numString), floatValue.isFinite else {
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
    ctx.cursor.skipWhitespace()
  }
}

// MARK: - Character extension for hex digit check

extension Character {
  /// Returns `true` if this character is a hexadecimal digit (0-9, A-F, a-f).
  package var isHexDigit: Bool {
    return ("0"..."9" ~= self) || ("A"..."F" ~= self) || ("a"..."f" ~= self)
  }
}
