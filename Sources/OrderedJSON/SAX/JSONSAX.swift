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

  /// Tracks SAX parser state: position, line/column, and handler.
  private struct SAXContext {
    let string: String
    var pos: String.Index
    var line: Int
    var column: Int
    var handler: (any JSONSAXEventHandler)?
    var acceptMode: Bool

    init(string: String, handler: any JSONSAXEventHandler) {
      self.string = string
      self.pos = string.startIndex
      self.line = 1
      self.column = 1
      self.handler = handler
      self.acceptMode = false
    }

    init(string: String) {
      self.string = string
      self.pos = string.startIndex
      self.line = 1
      self.column = 1
      self.handler = nil
      self.acceptMode = true
    }

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

    /// Returns the current error data (bytes from current position onward).
    func errorData() -> Data {
      return Data(string[pos...].utf8)
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
    if ctx.string[ctx.pos] == "t" {
      guard ctx.string[ctx.pos...].starts(with: "true") else {
        return ctx.emitError(.unexpectedToken(line: ctx.line, column: ctx.column))
      }
      ctx.advance()
      ctx.advance()
      ctx.advance()
      ctx.advance()
      return ctx.handler?.boolean(true) ?? true
    }
    guard ctx.string[ctx.pos...].starts(with: "false") else {
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
    guard ctx.string[ctx.pos...].starts(with: "null") else {
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
    while ctx.pos < ctx.string.endIndex {
      switch ctx.string[ctx.pos] {
      case " ", "\n", "\r", "\t":
        ctx.advance()
      default:
        return
      }
    }
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
    var hexStr = ""
    for _ in 0..<4 {
      guard ctx.pos < ctx.string.endIndex else { break }
      let c = ctx.string[ctx.pos]
      guard c.isHexDigit else { break }
      hexStr.append(c)
      ctx.advance()
    }
    guard hexStr.count == 4, let scalar = UInt16(hexStr, radix: 16) else {
      // Lenient mode: consume up to 4 non-hex characters after \u
      // so they don't end up as literal characters in the string.
      let remaining = 4 - hexStr.count
      for _ in 0..<remaining {
        guard ctx.pos < ctx.string.endIndex else { break }
        ctx.advance()
      }
      return ""
    }

    // Check for high surrogate (U+D800..U+DBFF)
    if scalar >= 0xD800 && scalar <= 0xDBFF {
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "\\" else { return "" }
      ctx.advance()
      guard ctx.pos < ctx.string.endIndex, ctx.string[ctx.pos] == "u" else { return "" }
      ctx.advance()
      var lowHex = ""
      for _ in 0..<4 {
        guard ctx.pos < ctx.string.endIndex else { break }
        let c = ctx.string[ctx.pos]
        guard c.isHexDigit else { break }
        lowHex.append(c)
        ctx.advance()
      }
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
      if ctx.string[ctx.pos...].starts(with: "true") {
        ctx.advance()
        ctx.advance()
        ctx.advance()
        ctx.advance()
        return true
      }
      return false
    case "f":
      if ctx.string[ctx.pos...].starts(with: "false") {
        ctx.advance()
        ctx.advance()
        ctx.advance()
        ctx.advance()
        ctx.advance()
        return true
      }
      return false
    case "n":
      if ctx.string[ctx.pos...].starts(with: "null") {
        ctx.advance()
        ctx.advance()
        ctx.advance()
        ctx.advance()
        return true
      }
      return false
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
