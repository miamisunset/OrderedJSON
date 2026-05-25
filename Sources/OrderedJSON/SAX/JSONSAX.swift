import Foundation

/// Event handler protocol for SAX-style JSON parsing.
///
/// SAX (Simple API for XML/JSON) parsing avoids constructing a full JSON
/// tree in memory. Instead, each structural element is reported to the
/// handler as it is encountered.
///
/// Each method returns `true` to continue parsing or `false` to stop early.
/// Returning `false` from any method immediately stops the parse without
/// reporting an error — useful for validation where you want to reject
/// at the first problem.
///
/// ## Example
///
/// ```swift
/// class Collector: JSONSAXEventHandler {
///   var events: [(String, String)] = []
///   func null() -> Bool { events.append(("null", "")); return true }
///   func string(_ v: String) -> Bool { events.append(("string", v)); return true }
///   // ... other callbacks
/// }
/// JSON.saxParse(#"{"key":"value"}"#, handler: Collector())
/// ```
public protocol JSONSAXEventHandler: AnyObject {
  /// Called when a JSON `null` value is parsed.
  func null() -> Bool
  /// Called when a JSON boolean value is parsed.
  func boolean(_ value: Bool) -> Bool
  /// Called when a JSON integer value is parsed.
  func integer(_ value: Int64) -> Bool
  /// Called when a JSON floating-point value is parsed.
  /// - Parameters:
  ///   - value: The parsed double value.
  ///   - string: The original string representation.
  func float(_ value: Double, string: String) -> Bool
  /// Called when a JSON string value is parsed.
  func string(_ value: String) -> Bool
  /// Called when a JSON object `{` is parsed.
  func startObject() -> Bool
  /// Called when a JSON object key is parsed.
  func key(_ value: String) -> Bool
  /// Called when a JSON object `}` is parsed.
  func endObject() -> Bool
  /// Called when a JSON array `[` is parsed.
  func startArray() -> Bool
  /// Called when a JSON array `]` is parsed.
  func endArray() -> Bool
  /// Called when a parse error is encountered.
  ///
  /// The error is recoverable — the handler can choose to continue
  /// or stop. Returning `false` stops parsing; returning `true`
  /// attempts to continue (may produce further errors).
  func parseError(_ error: JSONParseError, data: Data) -> Bool
}

extension JSON {
  /// Parses JSON using a SAX event handler, without constructing the full tree.
  ///
  /// Useful for large JSON documents where you want to process values
  /// as they are parsed, or for validation where you want early termination.
  ///
  /// - Parameters:
  ///   - jsonString: A valid JSON string.
  ///   - handler: The SAX event handler.
  /// - Returns: `true` if parsing completed (handler didn't stop early).
  ///
  /// ## Example
  ///
  /// ```swift
  /// let collector = SAXCollector()
  /// let ok = JSON.saxParse("null", handler: collector)
  /// ```
  public static func saxParse(
    _ jsonString: String,
    handler: JSONSAXEventHandler
  ) -> Bool {
    var ctx = SAXContext(string: jsonString, handler: handler)
    let ok = saxParseValue(&ctx)
    if !ok { return false }
    skipWhitespace(&ctx)
    if ctx.pos < ctx.string.endIndex {
      let data = Data(ctx.string.utf8)
      return handler.parseError(
        .unexpectedToken(line: ctx.line, column: ctx.column),
        data: data
      )
    }
    return true
  }

  /// Parses and validates JSON, returning `true` if the input is valid.
  ///
  /// This is a non-throwing equivalent of `parse()`. It validates the
  /// structure without constructing a `JSON` tree, making it suitable
  /// for quick validation where you don't need the parsed value.
  ///
  /// - Parameter jsonString: A JSON string to validate.
  /// - Returns: `true` if the input is valid JSON.
  ///
  /// ## Example
  ///
  /// ```swift
  /// JSON.accept("null")       // true
  /// JSON.accept("invalid")    // false
  /// ```
  public static func accept(_ jsonString: String) -> Bool {
    var ctx = SAXContext(string: jsonString)
    guard saxAcceptValue(&ctx) else { return false }
    skipWhitespace(&ctx)
    return ctx.pos >= ctx.string.endIndex
  }

  // MARK: - SAX Context

  /// Tracks SAX parser state: cursor position, handler, and accept mode.
  private struct SAXContext {
    /// Shared position cursor.
    var cursor: ParseCursor
    var handler: (any JSONSAXEventHandler)?
    var acceptMode: Bool

    /// The source string being parsed.
    var string: String { cursor.string }
    /// Current position in the string.
    var pos: String.Index { cursor.pos }
    /// Current line number (1-based).
    var line: Int { cursor.line }
    /// Current column number (1-based).
    var column: Int { cursor.column }

    /// Advance one character, updating line/column.
    mutating func advance() { cursor.advance() }

    init(string: String, handler: any JSONSAXEventHandler) {
      self.cursor = ParseCursor(string: string)
      self.handler = handler
      self.acceptMode = false
    }

    init(string: String) {
      self.cursor = ParseCursor(string: string)
      self.handler = nil
      self.acceptMode = true
    }

    /// Returns the current error data (bytes from current position onward).
    func errorData() -> Data {
      return Data(cursor.string[cursor.pos...].utf8)
    }

    /// Creates a parse error at the current position and calls handler.
    /// Returns `false` if handler says stop, `true` if handler wants to continue.
    mutating func emitError(_ kind: JSONParseError.Kind) -> Bool {
      guard let handler else { return false }
      let error = JSONParseError(kind)
      return handler.parseError(error, data: errorData())
    }
  }

  // MARK: - SAX Parse internals

  private static func saxParseValue(_ ctx: inout SAXContext) -> Bool {
    skipWhitespace(&ctx)
    guard ctx.pos < ctx.string.endIndex else {
      return ctx.emitError(.unexpectedEnd)
    }
    switch ctx.string[ctx.pos] {
    case "{":
      return saxParseObject(&ctx)
    case "[":
      return saxParseArray(&ctx)
    case "\"":
      return saxParseString(&ctx)
    case "t", "f":
      return saxParseBoolean(&ctx)
    case "n":
      return saxParseNull(&ctx)
    case "-", "0"..."9":
      return saxParseNumber(&ctx)
    default:
      return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
    }
  }

  private static func saxParseObject(_ ctx: inout SAXContext) -> Bool {
    ctx.advance()  // skip '{'
    guard ctx.handler?.startObject() ?? true else { return false }
    skipWhitespace(&ctx)
    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "}" {
      ctx.advance()
      return ctx.handler?.endObject() ?? true
    }
    repeat {
      skipWhitespace(&ctx)
      let key = saxParseStringValue(&ctx)
      guard ctx.handler?.key(key) ?? true else { return false }
      skipWhitespace(&ctx)
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == ":" else {
        return ctx.emitError(.expectedColon(line: ctx.line, column: ctx.column))
      }
      ctx.advance()
      guard saxParseValue(&ctx) else { return false }
      skipWhitespace(&ctx)
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "," else { break }
      ctx.advance()
    } while true
    guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "}" else {
      return ctx.emitError(.expectedCloseBrace(line: ctx.line, column: ctx.column))
    }
    ctx.advance()
    return ctx.handler?.endObject() ?? true
  }

  private static func saxParseArray(_ ctx: inout SAXContext) -> Bool {
    ctx.advance()  // skip '['
    guard ctx.handler?.startArray() ?? true else { return false }
    skipWhitespace(&ctx)
    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "]" {
      ctx.advance()
      return ctx.handler?.endArray() ?? true
    }
    repeat {
      guard saxParseValue(&ctx) else { return false }
      skipWhitespace(&ctx)
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "," else { break }
      ctx.advance()
    } while true
    guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "]" else {
      return ctx.emitError(.expectedCloseBracket(line: ctx.line, column: ctx.column))
    }
    ctx.advance()
    return ctx.handler?.endArray() ?? true
  }

  private static func saxParseString(_ ctx: inout SAXContext) -> Bool {
    let string = saxParseStringValue(&ctx)
    return ctx.handler?.string(string) ?? true
  }

  private static func saxParseBoolean(_ ctx: inout SAXContext) -> Bool {
    let end = ctx.string.endIndex
    if ctx.string[ctx.pos] == "t" {
      var idx = ctx.pos
      idx = ctx.string.index(after: idx)
      guard idx < end && ctx.string[idx] == "r" else {
        return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
      }
      idx = ctx.string.index(after: idx)
      guard idx < end && ctx.string[idx] == "u" else {
        return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
      }
      idx = ctx.string.index(after: idx)
      guard idx < end && ctx.string[idx] == "e" else {
        return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
      }
      ctx.advance()
      ctx.advance()
      ctx.advance()
      ctx.advance()
      return ctx.handler?.boolean(true) ?? true
    }
    var idx = ctx.pos
    idx = ctx.string.index(after: idx)
    guard idx < end && ctx.string[idx] == "a" else {
      return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
    }
    idx = ctx.string.index(after: idx)
    guard idx < end && ctx.string[idx] == "l" else {
      return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
    }
    idx = ctx.string.index(after: idx)
    guard idx < end && ctx.string[idx] == "s" else {
      return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
    }
    idx = ctx.string.index(after: idx)
    guard idx < end && ctx.string[idx] == "e" else {
      return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
    }
    ctx.advance()
    ctx.advance()
    ctx.advance()
    ctx.advance()
    ctx.advance()
    return ctx.handler?.boolean(false) ?? true
  }

  private static func saxParseNull(_ ctx: inout SAXContext) -> Bool {
    let end = ctx.string.endIndex
    var idx = ctx.pos
    idx = ctx.string.index(after: idx)
    guard idx < end && ctx.string[idx] == "u" else {
      return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
    }
    idx = ctx.string.index(after: idx)
    guard idx < end && ctx.string[idx] == "l" else {
      return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
    }
    idx = ctx.string.index(after: idx)
    guard idx < end && ctx.string[idx] == "l" else {
      return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
    }
    ctx.advance()
    ctx.advance()
    ctx.advance()
    ctx.advance()
    return ctx.handler?.null() ?? true
  }

  private static func saxParseNumber(_ ctx: inout SAXContext) -> Bool {
    let start = ctx.pos
    let startLine = ctx.line
    let startColumn = ctx.column

    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "-" {
      ctx.advance()
    }
    while ctx.pos < ctx.string.endIndex,
      ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9"
    {
      ctx.advance()
    }
    var isFloat = false
    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "." {
      isFloat = true
      ctx.advance()
      guard ctx.pos < ctx.string.endIndex,
        ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9"
      else {
        return ctx.emitError(.invalidNumber(line: ctx.line, column: ctx.column))
      }
      while ctx.pos < ctx.string.endIndex,
        ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9"
      {
        ctx.advance()
      }
    }
    if ctx.pos < ctx.string.endIndex,
      ctx.string[ctx.pos] == "e" || ctx.string[ctx.pos] == "E"
    {
      isFloat = true
      ctx.advance()
      if ctx.pos < ctx.string.endIndex,
        ctx.string[ctx.pos] == "+" || ctx.string[ctx.pos] == "-"
      {
        ctx.advance()
      }
      guard ctx.pos < ctx.string.endIndex,
        ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9"
      else {
        return ctx.emitError(.invalidNumber(line: ctx.line, column: ctx.column))
      }
      while ctx.pos < ctx.string.endIndex,
        ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9"
      {
        ctx.advance()
      }
    }

    let numString = String(ctx.string[start..<ctx.pos])
    if isFloat {
      guard let d = Double(numString) else {
        return ctx.emitError(.invalidNumber(line: startLine, column: startColumn))
      }
      return ctx.handler?.float(d, string: numString) ?? true
    }
    if let intValue = Int64(numString) {
      return ctx.handler?.integer(intValue) ?? true
    }
    return ctx.emitError(.invalidNumber(line: ctx.line, column: ctx.column))
  }

  // MARK: - Local helpers

  private static func skipWhitespace(_ ctx: inout SAXContext) {
    ctx.cursor.skipWhitespace()
  }

  private static func saxParseStringValue(_ ctx: inout SAXContext) -> String {
    guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "\"" else {
      return ""
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
        guard ctx.pos < ctx.string.endIndex else { return "" }
        switch ctx.string[ctx.pos] {
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
          result += parseUnicodeEscape(&ctx)
        default:
          return ""
        }
      } else {
        result.append(c)
        ctx.advance()
      }
    }
    return result
  }

  private static func parseUnicodeEscape(_ ctx: inout SAXContext) -> String {
    ctx.advance()  // skip 'u'
    let hexStr = ctx.cursor.readHexDigits()
    guard hexStr.count == 4, let scalar = UInt16(hexStr, radix: 16) else {
      // Lenient mode: consume up to 4 non-hex characters after \u
      // so they don't end up as literal characters in the string.
      let remaining = 4 - hexStr.count
      for _ in 0..<remaining {
        guard ctx.cursor.hasMore else { break }
        ctx.cursor.advance()
      }
      return ""
    }

    // Check for high surrogate (U+D800..U+DBFF)
    if scalar >= 0xD800 && scalar <= 0xDBFF {
      guard ctx.cursor.hasMore, ctx.cursor.current == "\\" else { return "" }
      ctx.cursor.advance()
      guard ctx.cursor.hasMore, ctx.cursor.current == "u" else { return "" }
      ctx.cursor.advance()
      let lowHex = ctx.cursor.readHexDigits()
      guard lowHex.count == 4, let low = UInt16(lowHex, radix: 16) else { return "" }
      guard low >= 0xDC00 && low <= 0xDFFF else { return "" }

      let highOffset = UInt32(scalar - 0xD800)
      let lowOffset = UInt32(low - 0xDC00)
      let codePoint = 0x10000 + (highOffset << 10) + lowOffset
      guard let unicodeScalar = UnicodeScalar(codePoint) else { return "" }
      return String(unicodeScalar)
    }

    guard let unicodeScalar = UnicodeScalar(scalar) else { return "" }
    return String(unicodeScalar)
  }
}

// MARK: - Accept internals (non-callback, just validation)

extension JSON {
  private static func saxAcceptValue(_ ctx: inout SAXContext) -> Bool {
    skipWhitespace(&ctx)
    guard ctx.pos < ctx.string.endIndex else { return false }
    switch ctx.string[ctx.pos] {
    case "{": return saxAcceptObject(&ctx)
    case "[": return saxAcceptArray(&ctx)
    case "\"":
      let _ = saxParseStringValue(&ctx)
      return true
    case "t":
      do {
        let end = ctx.string.endIndex
        var idx = ctx.pos
        idx = ctx.string.index(after: idx)
        guard idx < end && ctx.string[idx] == "r" else { return false }
        idx = ctx.string.index(after: idx)
        guard idx < end && ctx.string[idx] == "u" else { return false }
        idx = ctx.string.index(after: idx)
        guard idx < end && ctx.string[idx] == "e" else { return false }
        ctx.advance()
        ctx.advance()
        ctx.advance()
        ctx.advance()
        return true
      }
    case "f":
      do {
        let end = ctx.string.endIndex
        var idx = ctx.pos
        idx = ctx.string.index(after: idx)
        guard idx < end && ctx.string[idx] == "a" else { return false }
        idx = ctx.string.index(after: idx)
        guard idx < end && ctx.string[idx] == "l" else { return false }
        idx = ctx.string.index(after: idx)
        guard idx < end && ctx.string[idx] == "s" else { return false }
        idx = ctx.string.index(after: idx)
        guard idx < end && ctx.string[idx] == "e" else { return false }
        ctx.advance()
        ctx.advance()
        ctx.advance()
        ctx.advance()
        ctx.advance()
        return true
      }
    case "n":
      do {
        let end = ctx.string.endIndex
        var idx = ctx.pos
        idx = ctx.string.index(after: idx)
        guard idx < end && ctx.string[idx] == "u" else { return false }
        idx = ctx.string.index(after: idx)
        guard idx < end && ctx.string[idx] == "l" else { return false }
        idx = ctx.string.index(after: idx)
        guard idx < end && ctx.string[idx] == "l" else { return false }
        ctx.advance()
        ctx.advance()
        ctx.advance()
        ctx.advance()
        return true
      }
    case "-", "0"..."9":
      if ctx.string[ctx.pos] == "-" { ctx.advance() }
      while ctx.pos < ctx.string.endIndex,
        ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9"
      {
        ctx.advance()
      }
      if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "." {
        ctx.advance()
        while ctx.pos < ctx.string.endIndex,
          ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9"
        {
          ctx.advance()
        }
      }
      if ctx.pos < ctx.string.endIndex,
        ctx.string[ctx.pos] == "e" || ctx.string[ctx.pos] == "E"
      {
        ctx.advance()
        if ctx.pos < ctx.string.endIndex,
          ctx.string[ctx.pos] == "+" || ctx.string[ctx.pos] == "-"
        {
          ctx.advance()
        }
        while ctx.pos < ctx.string.endIndex,
          ctx.string[ctx.pos] >= "0", ctx.string[ctx.pos] <= "9"
        {
          ctx.advance()
        }
      }
      return true
    default:
      return false
    }
  }

  private static func saxAcceptObject(_ ctx: inout SAXContext) -> Bool {
    ctx.advance()  // skip '{'
    skipWhitespace(&ctx)
    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "}" {
      ctx.advance()
      return true
    }
    repeat {
      skipWhitespace(&ctx)
      let _ = saxParseStringValue(&ctx)
      skipWhitespace(&ctx)
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == ":" else { return false }
      ctx.advance()
      guard saxAcceptValue(&ctx) else { return false }
      skipWhitespace(&ctx)
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "," else { break }
      ctx.advance()
    } while true
    guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "}" else { return false }
    ctx.advance()
    return true
  }

  private static func saxAcceptArray(_ ctx: inout SAXContext) -> Bool {
    ctx.advance()  // skip '['
    skipWhitespace(&ctx)
    if ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "]" {
      ctx.advance()
      return true
    }
    repeat {
      guard saxAcceptValue(&ctx) else { return false }
      skipWhitespace(&ctx)
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "," else { break }
      ctx.advance()
    } while true
    guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "]" else { return false }
    ctx.advance()
    return true
  }
}
