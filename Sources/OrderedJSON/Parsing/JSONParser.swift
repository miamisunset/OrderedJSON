import Foundation
import OrderedCollections

extension JSON {
  /// Parses JSON from a string, preserving key order in objects.
  /// Uses a recursive descent parser for order-preserving decoding.
  public static func parse(_ jsonString: String) throws -> JSON {
    var pos = 0
    let chars = Array(jsonString)
    let value = try parseValue(chars, &pos)
    skipWhitespace(chars, &pos)
    if pos < chars.count {
      throw JSONParseError.unexpectedToken(pos)
    }
    return value
  }

  private static func parseValue(_ chars: [Character], _ pos: inout Int) throws -> JSON {
    skipWhitespace(chars, &pos)
    guard pos < chars.count else {
      throw JSONParseError.unexpectedEnd()
    }
    switch chars[pos] {
    case "{":
      return try parseObject(chars, &pos)
    case "[":
      return try parseArray(chars, &pos)
    case "\"":
      return try parseStringValue(chars, &pos)
    case "t", "f":
      return try parseBoolean(chars, &pos)
    case "n":
      return try parseNull(chars, &pos)
    case "-", "0"..."9":
      return try parseNumber(chars, &pos)
    default:
      throw JSONParseError.unexpectedToken(pos)
    }
  }

  private static func parseObject(_ chars: [Character], _ pos: inout Int) throws -> JSON {
    pos += 1  // skip '{'
    var object = OrderedDictionary<String, JSON>()
    skipWhitespace(chars, &pos)
    if pos < chars.count, chars[pos] == "}" {
      pos += 1
      return .object(object)
    }
    repeat {
      skipWhitespace(chars, &pos)
      let key = try parseString(chars, &pos)
      skipWhitespace(chars, &pos)
      guard pos < chars.count, chars[pos] == ":" else {
        throw JSONParseError.expectedColon(pos)
      }
      pos += 1
      let value = try parseValue(chars, &pos)
      object[key] = value
      skipWhitespace(chars, &pos)
      guard pos < chars.count, chars[pos] == "," else { break }
      pos += 1
    } while true
    guard pos < chars.count, chars[pos] == "}" else {
      throw JSONParseError.expectedCloseBrace(pos)
    }
    pos += 1
    return .object(object)
  }

  private static func parseArray(_ chars: [Character], _ pos: inout Int) throws -> JSON {
    pos += 1  // skip '['
    var elements: [JSON] = []
    skipWhitespace(chars, &pos)
    if pos < chars.count, chars[pos] == "]" {
      pos += 1
      return .array(elements)
    }
    repeat {
      elements.append(try parseValue(chars, &pos))
      skipWhitespace(chars, &pos)
      guard pos < chars.count, chars[pos] == "," else { break }
      pos += 1
    } while true
    guard pos < chars.count, chars[pos] == "]" else {
      throw JSONParseError.expectedCloseBracket(pos)
    }
    pos += 1
    return .array(elements)
  }

  private static func parseStringValue(_ chars: [Character], _ pos: inout Int) throws -> JSON {
    return .string(try parseString(chars, &pos))
  }

  private static func parseString(_ chars: [Character], _ pos: inout Int) throws -> String {
    guard pos < chars.count, chars[pos] == "\"" else {
      throw JSONParseError.expectedString(pos)
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
        guard pos < chars.count else {
          throw JSONParseError.unexpectedEnd()
        }
        switch chars[pos] {
        case "\"":
          result += "\""
          pos += 1
        case "\\":
          result += "\\"
          pos += 1
        case "/":
          result += "/"
          pos += 1
        case "n":
          result += "\n"
          pos += 1
        case "r":
          result += "\r"
          pos += 1
        case "t":
          result += "\t"
          pos += 1
        case "b":
          result += "\u{8}"
          pos += 1
        case "f":
          result += "\u{12}"
          pos += 1
        case "u":
          result += try parseUnicodeEscape(chars, &pos)
        default:
          throw JSONParseError.invalidEscape(pos)
        }
      } else {
        result.append(c)
        pos += 1
      }
    }
    throw JSONParseError.unexpectedEnd()
  }

  private static func parseUnicodeEscape(_ chars: [Character], _ pos: inout Int) throws -> String {
    pos += 1  // skip 'u'
    let end = Swift.min(pos + 4, chars.count)
    let hexDigits = String(chars[pos..<end])
    guard hexDigits.count == 4, let scalar = UInt16(hexDigits, radix: 16) else {
      throw JSONParseError.invalidUnicodeEscape(pos)
    }
    pos += 4
    return String(UnicodeScalar(scalar)!)
  }

  private static func parseBoolean(_ chars: [Character], _ pos: inout Int) throws -> JSON {
    if chars[pos] == "t" {
      guard chars[pos...].starts(with: "true") else {
        throw JSONParseError.unexpectedToken(pos)
      }
      pos += 4
      return .boolean(true)
    }
    guard chars[pos...].starts(with: "false") else {
      throw JSONParseError.unexpectedToken(pos)
    }
    pos += 5
    return .boolean(false)
  }

  private static func parseNull(_ chars: [Character], _ pos: inout Int) throws -> JSON {
    guard chars[pos...].starts(with: "null") else {
      throw JSONParseError.unexpectedToken(pos)
    }
    pos += 4
    return .null
  }

  private static func parseNumber(_ chars: [Character], _ pos: inout Int) throws -> JSON {
    let start = pos
    if pos < chars.count, chars[pos] == "-" { pos += 1 }
    while pos < chars.count, chars[pos] >= "0", chars[pos] <= "9" { pos += 1 }
    var isFloat = false
    if pos < chars.count, chars[pos] == "." {
      isFloat = true
      pos += 1
      guard pos < chars.count, chars[pos] >= "0", chars[pos] <= "9" else {
        throw JSONParseError.unexpectedEnd()
      }
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
      return .number(.float(try parseDouble(numString)))
    }
    if let intValue = Int64(numString) {
      return .number(.integer(intValue))
    }
    throw JSONParseError.invalidNumber(pos)
  }

  private static func parseDouble(_ s: String) throws -> Double {
    guard let d = Double(s) else {
      throw JSONParseError.invalidNumber(0)
    }
    return d
  }

  private static func skipWhitespace(_ chars: [Character], _ pos: inout Int) {
    while pos < chars.count {
      switch chars[pos] {
      case " ", "\n", "\r", "\t": pos += 1
      default: return
      }
    }
  }
}
