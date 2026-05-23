import Foundation

/// Event handler protocol for SAX-style JSON parsing.
/// Each method returns `true` to continue parsing or `false` to stop early.
public protocol JSONSAXEventHandler: AnyObject {
  func null() -> Bool
  func boolean(_ value: Bool) -> Bool
  func integer(_ value: Int64) -> Bool
  func float(_ value: Double, string: String) -> Bool
  func string(_ value: String) -> Bool
  func startObject() -> Bool
  func key(_ value: String) -> Bool
  func endObject() -> Bool
  func startArray() -> Bool
  func endArray() -> Bool
  func parseError(_ error: JSONParseError, data: Data) -> Bool
}

extension JSON {
  /// Parses JSON using a SAX event handler, without constructing the full tree.
  /// Returns `true` if parsing completed (handler didn't stop early).
  public static func saxParse(
    _ jsonString: String,
    handler: JSONSAXEventHandler
  ) -> Bool {
    var pos = 0
    let chars = Array(jsonString)
    let ok = saxParseValue(chars, &pos, handler)
    if !ok { return false }
    skipWhitespace(chars, &pos)
    if pos < chars.count {
      let data = Data(jsonString.utf8)
      return handler.parseError(.unexpectedToken(pos), data: data)
    }
    return true
  }

  /// Parses and validates JSON, returning `true` if the input is valid.
  /// Non-throwing equivalent of `parse()`.
  public static func accept(_ jsonString: String) -> Bool {
    var pos = 0
    let chars = Array(jsonString)
    guard saxAcceptValue(chars, &pos) else { return false }
    skipWhitespace(chars, &pos)
    return pos >= chars.count
  }

  // MARK: - SAX Parse internals

  private static func saxParseValue(
    _ chars: [Character],
    _ pos: inout Int,
    _ handler: JSONSAXEventHandler
  ) -> Bool {
    skipWhitespace(chars, &pos)
    guard pos < chars.count else {
      return handler.parseError(.unexpectedEnd(), data: Data())
    }
    switch chars[pos] {
    case "{":
      return saxParseObject(chars, &pos, handler)
    case "[":
      return saxParseArray(chars, &pos, handler)
    case "\"":
      return saxParseString(chars, &pos, handler)
    case "t", "f":
      return saxParseBoolean(chars, &pos, handler)
    case "n":
      return saxParseNull(chars, &pos, handler)
    case "-", "0"..."9":
      return saxParseNumber(chars, &pos, handler)
    default:
      let data = Data(String(chars[pos...]).utf8)
      return handler.parseError(.unexpectedToken(pos), data: data)
    }
  }

  private static func saxParseObject(
    _ chars: [Character],
    _ pos: inout Int,
    _ handler: JSONSAXEventHandler
  ) -> Bool {
    pos += 1  // skip '{'
    guard handler.startObject() else { return false }
    skipWhitespace(chars, &pos)
    if pos < chars.count, chars[pos] == "}" {
      pos += 1
      return handler.endObject()
    }
    repeat {
      skipWhitespace(chars, &pos)
      let key = saxParseStringValue(chars, &pos)
      guard handler.key(key) else { return false }
      skipWhitespace(chars, &pos)
      guard pos < chars.count, chars[pos] == ":" else {
        return handler.parseError(.expectedColon(pos), data: Data(String(chars[pos...]).utf8))
      }
      pos += 1
      guard saxParseValue(chars, &pos, handler) else { return false }
      skipWhitespace(chars, &pos)
      guard pos < chars.count, chars[pos] == "," else { break }
      pos += 1
    } while true
    guard pos < chars.count, chars[pos] == "}" else {
      return handler.parseError(.expectedCloseBrace(pos), data: Data(String(chars[pos...]).utf8))
    }
    pos += 1
    return handler.endObject()
  }

  private static func saxParseArray(
    _ chars: [Character],
    _ pos: inout Int,
    _ handler: JSONSAXEventHandler
  ) -> Bool {
    pos += 1  // skip '['
    guard handler.startArray() else { return false }
    skipWhitespace(chars, &pos)
    if pos < chars.count, chars[pos] == "]" {
      pos += 1
      return handler.endArray()
    }
    repeat {
      guard saxParseValue(chars, &pos, handler) else { return false }
      skipWhitespace(chars, &pos)
      guard pos < chars.count, chars[pos] == "," else { break }
      pos += 1
    } while true
    guard pos < chars.count, chars[pos] == "]" else {
      return handler.parseError(.expectedCloseBracket(pos), data: Data(String(chars[pos...]).utf8))
    }
    pos += 1
    return handler.endArray()
  }

  private static func saxParseString(
    _ chars: [Character],
    _ pos: inout Int,
    _ handler: JSONSAXEventHandler
  ) -> Bool {
    let string = saxParseStringValue(chars, &pos)
    return handler.string(string)
  }

  private static func saxParseBoolean(
    _ chars: [Character],
    _ pos: inout Int,
    _ handler: JSONSAXEventHandler
  ) -> Bool {
    if chars[pos] == "t" {
      guard chars[pos...].starts(with: "true") else {
        return handler.parseError(.unexpectedToken(pos), data: Data(String(chars[pos...]).utf8))
      }
      pos += 4
      return handler.boolean(true)
    }
    guard chars[pos...].starts(with: "false") else {
      return handler.parseError(.unexpectedToken(pos), data: Data(String(chars[pos...]).utf8))
    }
    pos += 5
    return handler.boolean(false)
  }

  private static func saxParseNull(
    _ chars: [Character],
    _ pos: inout Int,
    _ handler: JSONSAXEventHandler
  ) -> Bool {
    guard chars[pos...].starts(with: "null") else {
      return handler.parseError(.unexpectedToken(pos), data: Data(String(chars[pos...]).utf8))
    }
    pos += 4
    return handler.null()
  }

  private static func saxParseNumber(
    _ chars: [Character],
    _ pos: inout Int,
    _ handler: JSONSAXEventHandler
  ) -> Bool {
    let start = pos
    if pos < chars.count, chars[pos] == "-" { pos += 1 }
    while pos < chars.count, chars[pos] >= "0", chars[pos] <= "9" { pos += 1 }
    var isFloat = false
    if pos < chars.count, chars[pos] == "." {
      isFloat = true
      pos += 1
      while pos < chars.count, chars[pos] >= "0", chars[pos] <= "9" { pos += 1 }
    }
    if pos < chars.count, chars[pos] == "e" || chars[pos] == "E" {
      isFloat = true
      pos += 1
      if pos < chars.count, chars[pos] == "+" || chars[pos] == "-" { pos += 1 }
      while pos < chars.count, chars[pos] >= "0", chars[pos] <= "9" { pos += 1 }
    }
    let numString = String(chars[start..<pos])
    if isFloat {
      guard let d = Double(numString) else {
        return handler.parseError(.invalidNumber(0), data: Data(numString.utf8))
      }
      return handler.float(d, string: numString)
    }
    if let intValue = Int64(numString) {
      return handler.integer(intValue)
    }
    return handler.parseError(.invalidNumber(pos), data: Data(numString.utf8))
  }

  // MARK: - Local helpers (mirrors JSONParser but non-throwing for SAX)

  private static func skipWhitespace(_ chars: [Character], _ pos: inout Int) {
    while pos < chars.count {
      switch chars[pos] {
      case " ", "\n", "\r", "\t": pos += 1
      default: return
      }
    }
  }

  private static func saxParseStringValue(_ chars: [Character], _ pos: inout Int) -> String {
    guard pos < chars.count, chars[pos] == "\"" else {
      return ""
    }
    pos += 1
    var result = ""
    while pos < chars.count {
      let c = chars[pos]
      if c == "\"" {
        pos += 1
        return result
      }
      if c == "\\" {
        pos += 1
        guard pos < chars.count else { return "" }
        switch chars[pos] {
        case "\"":
          result += "\""
        case "\\":
          result += "\\"
        case "/":
          result += "/"
        case "n":
          result += "\n"
        case "r":
          result += "\r"
        case "t":
          result += "\t"
        case "b":
          result += "\u{8}"
        case "f":
          result += "\u{12}"
        case "u":
          result += parseUnicodeEscape(chars, &pos)
        default:
          return ""
        }
        pos += 1
      } else {
        result.append(c)
        pos += 1
      }
    }
    return result
  }

  private static func parseUnicodeEscape(_ chars: [Character], _ pos: inout Int) -> String {
    pos += 1  // skip 'u'
    let end = Swift.min(pos + 4, chars.count)
    let hexDigits = String(chars[pos..<end])
    guard hexDigits.count == 4, let scalar = UInt16(hexDigits, radix: 16) else {
      return ""
    }
    pos += 4
    return String(UnicodeScalar(scalar)!)
  }
}

// MARK: - Accept internals (non-callback, just validation)

extension JSON {
  private static func saxAcceptValue(
    _ chars: [Character],
    _ pos: inout Int
  ) -> Bool {
    skipWhitespace(chars, &pos)
    guard pos < chars.count else { return false }
    switch chars[pos] {
    case "{": return saxAcceptObject(chars, &pos)
    case "[": return saxAcceptArray(chars, &pos)
    case "\"":
      let _ = saxParseStringValue(chars, &pos)
      return true
    case "t":
      if chars[pos...].starts(with: "true") {
        pos += 4
        return true
      }
      return false
    case "f":
      if chars[pos...].starts(with: "false") {
        pos += 5
        return true
      }
      return false
    case "n":
      if chars[pos...].starts(with: "null") {
        pos += 4
        return true
      }
      return false
    case "-", "0"..."9":
      if chars[pos] == "-" { pos += 1 }
      while pos < chars.count, chars[pos] >= "0", chars[pos] <= "9" { pos += 1 }
      if pos < chars.count, chars[pos] == "." {
        pos += 1
        while pos < chars.count, chars[pos] >= "0", chars[pos] <= "9" { pos += 1 }
      }
      if pos < chars.count, chars[pos] == "e" || chars[pos] == "E" {
        pos += 1
        if pos < chars.count, chars[pos] == "+" || chars[pos] == "-" { pos += 1 }
        while pos < chars.count, chars[pos] >= "0", chars[pos] <= "9" { pos += 1 }
      }
      return true
    default:
      return false
    }
  }

  private static func saxAcceptObject(
    _ chars: [Character],
    _ pos: inout Int
  ) -> Bool {
    pos += 1  // skip '{'
    skipWhitespace(chars, &pos)
    if pos < chars.count, chars[pos] == "}" {
      pos += 1
      return true
    }
    repeat {
      skipWhitespace(chars, &pos)
      let _ = saxParseStringValue(chars, &pos)
      skipWhitespace(chars, &pos)
      guard pos < chars.count, chars[pos] == ":" else { return false }
      pos += 1
      guard saxAcceptValue(chars, &pos) else { return false }
      skipWhitespace(chars, &pos)
      guard pos < chars.count, chars[pos] == "," else { break }
      pos += 1
    } while true
    guard pos < chars.count, chars[pos] == "}" else { return false }
    pos += 1
    return true
  }

  private static func saxAcceptArray(
    _ chars: [Character],
    _ pos: inout Int
  ) -> Bool {
    pos += 1  // skip '['
    skipWhitespace(chars, &pos)
    if pos < chars.count, chars[pos] == "]" {
      pos += 1
      return true
    }
    repeat {
      guard saxAcceptValue(chars, &pos) else { return false }
      skipWhitespace(chars, &pos)
      guard pos < chars.count, chars[pos] == "," else { break }
      pos += 1
    } while true
    guard pos < chars.count, chars[pos] == "]" else { return false }
    pos += 1
    return true
  }
}
