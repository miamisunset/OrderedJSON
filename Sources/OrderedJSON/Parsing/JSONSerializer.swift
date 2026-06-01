import Foundation
import OrderedCollections

extension JSON {
  /// Controls indentation for JSON serialization.
  ///
  /// Per RFC 8259, JSON indent characters are limited to space and horizontal tab.
  /// This enum makes invalid indent states impossible at compile time.
  public enum Indent: Hashable, Sendable {
    /// Compact output with no whitespace.
    case compact
    /// Indent with spaces — the number of spaces per indent level.
    ///
    /// The width must be non-negative. A value of 0 produces no leading
    /// whitespace (effectively compact within containers), while positive
    /// values produce the corresponding number of spaces per level.
    /// Negative values trigger a runtime precondition failure.
    case spaces(Int)
    /// Indent with horizontal tab characters.
    case tab
  }

  /// Pretty-prints this JSON value with the given indentation.
  ///
  /// - Parameter indent: Indentation style. Use `.compact` for single-line
  ///   output (default), `.spaces(n)` for n-space indentation, or `.tab`
  ///   for tab indentation.
  /// - Parameter ensureAscii: If `true`, non-ASCII characters are escaped as
  ///   `\uXXXX`. Defaults to `false`.
  /// - Returns: A JSON string.
  ///
  /// ## Example
  ///
  /// ```swift
  /// let json = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])
  /// json.dump()                         // compact: {"name":"Alice","age":30}
  /// json.dump(indent: .spaces(2))       // pretty-printed with 2-space indent
  /// json.dump(indent: .compact)         // compact
  /// json.dump(indent: .tab)             // tab-indented
  /// json.dump(ensureAscii: true)        // escape non-ASCII as \uXXXX
  /// ```
  public func dump(
    indent: Indent = .compact,
    ensureAscii: Bool = false
  ) -> String {
    switch indent {
    case .compact:
      var string = ""
      serializeJSONCompact(self, ensureAscii: ensureAscii, sortedKeys: false, into: &string)
      return string
    case .spaces(let width):
      precondition(width >= 0, "Indent.spaces width (\(width)) must be non-negative")
      var string = ""
      serializeJSONPretty(
        self, indent: width, indentCharacter: " ", depth: 0, ensureAscii: ensureAscii, sortedKeys: false, into: &string
      )
      return string
    case .tab:
      var string = ""
      serializeJSONPretty(
        self, indent: 1, indentCharacter: "\t", depth: 0, ensureAscii: ensureAscii, sortedKeys: false, into: &string)
      return string
    }
  }

  private func serializeJSONCompact(
    _ value: JSON, ensureAscii: Bool, sortedKeys: Bool, into string: inout String
  ) {
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
        serializeJSONCompact(el, ensureAscii: ensureAscii, sortedKeys: sortedKeys, into: &string)
      }
      string += "]"
    case .object(let dict):
      string += "{"
      var first = true
      let keys = sortedKeys ? Array(dict.keys.sorted()) : Array(dict.keys)
      for key in keys {
        if !first { string += "," }
        first = false
        serializeJSONString(key, ensureAscii: ensureAscii, into: &string)
        string += ":"
        serializeJSONCompact(dict[key]!, ensureAscii: ensureAscii, sortedKeys: sortedKeys, into: &string)
      }
      string += "}"
    }
  }

  private func serializeJSONPretty(
    _ value: JSON, indent: Int, indentCharacter: Character, depth: Int, ensureAscii: Bool,
    sortedKeys: Bool, into string: inout String
  ) {
    let pad = String(repeating: String(indentCharacter), count: depth * indent)
    let innerPad = String(repeating: String(indentCharacter), count: (depth + 1) * indent)
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
            el,
            indent: indent,
            indentCharacter: indentCharacter,
            depth: depth + 1,
            ensureAscii: ensureAscii,
            sortedKeys: sortedKeys,
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
        let keys = sortedKeys ? Array(dict.keys.sorted()) : Array(dict.keys)
        for key in keys {
          if !first { string += ",\n" }
          first = false
          string += innerPad
          serializeJSONString(key, ensureAscii: ensureAscii, into: &string)
          string += ": "
          serializeJSONPretty(
            dict[key]!, indent: indent, indentCharacter: indentCharacter, depth: depth + 1,
            ensureAscii: ensureAscii, sortedKeys: sortedKeys, into: &string
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

  // MARK: - Sorted key serialization

  /// Serializes with keys sorted alphabetically for objects.
  func _dumpSorted(indent: Indent = .compact, ensureAscii: Bool = false) -> String {
    var string = ""
    switch indent {
    case .compact:
      serializeJSONCompact(self, ensureAscii: ensureAscii, sortedKeys: true, into: &string)
    case .spaces(let width):
      precondition(width >= 0, "Indent.spaces width (\(width)) must be non-negative")
      serializeJSONPretty(
        self, indent: width, indentCharacter: " ", depth: 0, ensureAscii: ensureAscii,
        sortedKeys: true, into: &string)
    case .tab:
      serializeJSONPretty(
        self, indent: 1, indentCharacter: "\t", depth: 0, ensureAscii: ensureAscii,
        sortedKeys: true, into: &string)
    }
    return string
  }
}
