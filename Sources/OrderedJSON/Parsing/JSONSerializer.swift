import Foundation
import OrderedCollections

extension JSON {
  /// Pretty-prints this JSON value with the given indentation.
  ///
  /// - Parameter indent: Indentation width in spaces. Use `nil` for compact
  ///   (single-line) output. Defaults to `nil`.
  /// - Parameter indentChar: Character to use for indentation. Defaults to `" "`.
  /// - Parameter ensureAscii: If `true`, non-ASCII characters are escaped as
  ///   `\uXXXX`. Defaults to `false`.
  /// - Returns: A JSON string.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])
  /// json.dump()                         // compact: {"name":"Alice","age":30}
  /// json.dump(indent: 2)                // pretty-printed with 2-space indent
  /// json.dump(indent: nil)              // compact
  /// json.dump(ensureAscii: true)        // escape non-ASCII as \uXXXX
  /// ```
  public func dump(
    indent: Int? = nil,
    indentChar: Character = " ",
    ensureAscii: Bool = false
  ) -> String {
    if let indentValue = indent {
      var string = ""
      serializeJSONPretty(
        self, indent: indentValue, indentChar: indentChar, depth: 0, ensureAscii: ensureAscii,
        into: &string
      )
      return string
    }
    var string = ""
    serializeJSONCompact(self, ensureAscii: ensureAscii, into: &string)
    return string
  }

  private func serializeJSONCompact(_ value: JSON, ensureAscii: Bool, into string: inout String) {
    switch value.storage {
    case .null:
      string += "null"
    case .boolean(let bool):
      string += bool ? "true" : "false"
    case .number(let num):
      serializeJSONNumber(num, into: &string)
    case .string(let s):
      serializeJSONString(s, ensureAscii: ensureAscii, into: &string)
    case .array(let arr):
      string += "["
      for (i, el) in arr.enumerated() {
        if i > 0 { string += "," }
        serializeJSONCompact(el, ensureAscii: ensureAscii, into: &string)
      }
      string += "]"
    case .object(let dict):
      string += "{"
      var first = true
      for (key, value) in dict {
        if !first { string += "," }
        first = false
        serializeJSONString(key, ensureAscii: ensureAscii, into: &string)
        string += ":"
        serializeJSONCompact(value, ensureAscii: ensureAscii, into: &string)
      }
      string += "}"
    }
  }

  private func serializeJSONPretty(
    _ value: JSON, indent: Int, indentChar: Character, depth: Int, ensureAscii: Bool,
    into string: inout String
  ) {
    let pad = String(repeating: String(indentChar), count: depth * indent)
    let innerPad = String(repeating: String(indentChar), count: (depth + 1) * indent)
    switch value.storage {
    case .null:
      string += "null"
    case .boolean(let bool):
      string += bool ? "true" : "false"
    case .number(let num):
      serializeJSONNumber(num, into: &string)
    case .string(let s):
      serializeJSONString(s, ensureAscii: ensureAscii, into: &string)
    case .array(let arr):
      if arr.isEmpty {
        string += "[]"
      } else {
        string += "[\n"
        for (i, el) in arr.enumerated() {
          if i > 0 { string += ",\n" }
          string += innerPad
          serializeJSONPretty(
            el, indent: indent, indentChar: indentChar, depth: depth + 1, ensureAscii: ensureAscii,
            into: &string
          )
        }
        string += "\n"
        string += pad
        string += "]"
      }
    case .object(let dict):
      if dict.isEmpty {
        string += "{}"
      } else {
        string += "{\n"
        var first = true
        for (key, value) in dict {
          if !first { string += ",\n" }
          first = false
          string += innerPad
          serializeJSONString(key, ensureAscii: ensureAscii, into: &string)
          string += ": "
          serializeJSONPretty(
            value, indent: indent, indentChar: indentChar, depth: depth + 1,
            ensureAscii: ensureAscii, into: &string
          )
        }
        string += "\n"
        string += pad
        string += "}"
      }
    }
  }

  private func serializeJSONNumber(_ num: JSONNumber, into string: inout String) {
    switch num {
    case .integer(let i):
      string += "\(i)"
    case .float(let d):
      // NaN and Infinity are not valid JSON — serialize as null
      if d.isNaN || d.isInfinite {
        string += "null"
      } else {
        string += "\(d)"
      }
    }
  }

  private func serializeJSONString(
    _ s: String, ensureAscii: Bool = false, into string: inout String
  ) {
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
        let v = c.unicodeScalars.first?.value ?? 0
        if v < 0x20 || (ensureAscii && v > 0x7F) {
          string += "\\u"
          string += String(format: "%04X", v)
        } else {
          string += String(c)
        }
      }
    }
    string += "\""
  }
}
