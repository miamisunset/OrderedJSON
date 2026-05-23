import Foundation
import OrderedCollections

/// A JSON number that preserves whether the original value was an integer or a float.
package enum JSONNumber: Hashable, Sendable {
  case integer(Int64)
  case float(Double)
}

/// An ordered dictionary typealias used for JSON object representations.
package typealias OrderedJSONObject = OrderedDictionary<String, JSONValue>

/// A JSON value that preserves key order for objects.
package enum JSONValue: Hashable, Sendable {
  case object(OrderedJSONObject)
  case array([JSONValue])
  case string(String)
  case number(JSONNumber)
  case boolean(Bool)
  case null

  package func flatten() -> [(key: String, value: JSONValue)] {
    flattenInternal(prefix: "")
  }

  private func flattenInternal(prefix: String) -> [(key: String, value: JSONValue)] {
    switch self {
    case .null, .boolean, .number, .string:
      return [(prefix, self)]
    case .array(let elements):
      var result: [(String, JSONValue)] = []
      for (index, element) in elements.enumerated() {
        let key = prefix.isEmpty ? "[\(index)]" : "\(prefix)[\(index)]"
        result.append(contentsOf: element.flattenInternal(prefix: key))
      }
      return result
    case .object(let dict):
      var result: [(String, JSONValue)] = []
      for (key, value) in dict {
        let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
        result.append(contentsOf: value.flattenInternal(prefix: fullKey))
      }
      return result
    }
  }

  /// Parses JSON from a string, preserving key order in objects.
  /// Uses a recursive descent parser for order-preserving decoding.
  package static func parse(_ jsonString: String) throws -> JSONValue {
    var pos = 0
    let chars = Array(jsonString)
    let value = try parseValue(chars, &pos)
    skipWhitespace(chars, &pos)
    if pos < chars.count {
      throw JSONParseError.unexpectedToken(pos)
    }
    return value
  }

  private static func parseValue(_ chars: [Character], _ pos: inout Int) throws -> JSONValue {
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

  private static func parseObject(_ chars: [Character], _ pos: inout Int) throws -> JSONValue {
    pos += 1  // skip '{'
    var object = OrderedJSONObject()
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

  private static func parseArray(_ chars: [Character], _ pos: inout Int) throws -> JSONValue {
    pos += 1  // skip '['
    var elements: [JSONValue] = []
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

  private static func parseStringValue(_ chars: [Character], _ pos: inout Int) throws -> JSONValue {
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
        case "\"": result += "\""
        case "\\": result += "\\"
        case "/": result += "/"
        case "n": result += "\n"
        case "r": result += "\r"
        case "t": result += "\t"
        case "b": result += "\u{8}"
        case "f": result += "\u{12}"
        case "u":
          result += try parseUnicodeEscape(chars, &pos)
        default:
          throw JSONParseError.invalidEscape(pos)
        }
        pos += 1
      } else {
        result.append(c)
        pos += 1
      }
    }
    throw JSONParseError.unexpectedEnd()
  }

  private static func parseUnicodeEscape(_ chars: [Character], _ pos: inout Int) throws -> String {
    pos += 1  // skip 'u'
    let hexDigits = String(chars[pos..<min(pos + 4, chars.count)])
    guard hexDigits.count == 4, let scalar = UInt16(hexDigits, radix: 16) else {
      throw JSONParseError.invalidUnicodeEscape(pos)
    }
    pos += 4
    return String(UnicodeScalar(scalar)!)
  }

  private static func parseBoolean(_ chars: [Character], _ pos: inout Int) throws -> JSONValue {
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

  private static func parseNull(_ chars: [Character], _ pos: inout Int) throws -> JSONValue {
    guard chars[pos...].starts(with: "null") else {
      throw JSONParseError.unexpectedToken(pos)
    }
    pos += 4
    return .null
  }

  private static func parseNumber(_ chars: [Character], _ pos: inout Int) throws -> JSONValue {
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

package struct JSONParseError: Error, CustomStringConvertible, Hashable, Sendable {
  package let kind: Kind

  package enum Kind: Hashable, Sendable {
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

  package init(_ kind: Kind) { self.kind = kind }

  package static func unexpectedEnd() -> JSONParseError { JSONParseError(.unexpectedEnd) }
  package static func unexpectedToken(_ pos: Int) -> JSONParseError {
    JSONParseError(.unexpectedToken(pos))
  }
  package static func expectedString(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedString(pos))
  }
  package static func expectedColon(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedColon(pos))
  }
  package static func expectedCloseBrace(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedCloseBrace(pos))
  }
  package static func expectedCloseBracket(_ pos: Int) -> JSONParseError {
    JSONParseError(.expectedCloseBracket(pos))
  }
  package static func invalidEscape(_ pos: Int) -> JSONParseError {
    JSONParseError(.invalidEscape(pos))
  }
  package static func invalidUnicodeEscape(_ pos: Int) -> JSONParseError {
    JSONParseError(.invalidUnicodeEscape(pos))
  }
  package static func invalidNumber(_ pos: Int) -> JSONParseError {
    JSONParseError(.invalidNumber(pos))
  }

  package var description: String {
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

package enum JSONError: Error, Sendable, Hashable {
  case invalidString
  case expectedObject
}

// MARK: - Standard JSON Encoding

extension JSONValue {
  /// Encodes this JSON value as a standard JSON data object (keyed containers).
  /// Key order is preserved via `OrderedDictionary` insertion order.
  package func encodeStandard() throws -> Data {
    var string = ""
    serializeJSON(self, into: &string)
    return Data(string.utf8)
  }

  private func serializeJSON(_ value: JSONValue, into string: inout String) {
    switch value {
    case .null:
      string += "null"
    case .boolean(let bool):
      string += bool ? "true" : "false"
    case .number(let num):
      serializeJSONNumber(num, into: &string)
    case .string(let s):
      serializeJSONString(s, into: &string)
    case .array(let arr):
      string += "["
      for (i, el) in arr.enumerated() {
        if i > 0 { string += "," }
        serializeJSON(el, into: &string)
      }
      string += "]"
    case .object(let dict):
      string += "{"
      var first = true
      for (key, value) in dict {
        if !first { string += "," }
        first = false
        serializeJSONString(key, into: &string)
        string += ":"
        serializeJSON(value, into: &string)
      }
      string += "}"
    }
  }

  private func serializeJSONNumber(_ num: JSONNumber, into string: inout String) {
    switch num {
    case .integer(let i):
      string += "\(i)"
    case .float(let d):
      string += "\(d)"
    }
  }

  private func serializeJSONString(_ s: String, into string: inout String) {
    string += "\""
    for c in s {
      switch c {
      case "\"":
        string += "\\\""
      case "\\":
        string += "\\\\"
      case "\n":
        string += "\\n"
      case "\r":
        string += "\\r"
      case "\t":
        string += "\\t"
      case "\u{8}":
        string += "\\b"
      case "\u{12}":
        string += "\\f"
      default:
        if c.unicodeScalars.first?.value ?? 0 < 0x20 {
          string += "\\u00"
          let v = c.unicodeScalars.first!.value
          string += v < 0x10 ? "0" : ""
          string += String(v, radix: 16)
        } else {
          string += String(c)
        }
      }
    }
    string += "\""
  }

}

/// Splits an `OrderedJSONObject` into known and extra keys based on a set of known key strings.
/// - Returns: A tuple where `known` contains only the entries with keys in `knownKeys`,
///   and `extra` contains the remaining entries (preserving order).
package func splitExtraFields(
  from dict: OrderedJSONObject,
  knownKeys: Set<String>
) -> (known: OrderedJSONObject, extra: OrderedJSONObject) {
  var known = OrderedJSONObject()
  var extra = OrderedJSONObject()
  for (key, value) in dict {
    if knownKeys.contains(key) {
      known[key] = value
    } else {
      extra[key] = value
    }
  }
  return (known, extra)
}
