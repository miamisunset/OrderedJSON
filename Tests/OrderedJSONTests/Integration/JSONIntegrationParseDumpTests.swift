import Foundation
import Testing

@testable import OrderedJSON

@Suite("Integration: parse → dump → parse")
struct JSONIntegrationParseDumpTests {
  @Test("parse → dump(indent: nil) → parse: object with various value types")
  func parseDumpParseObject() throws {
    let input = """
      {
        "null": null,
        "bool": true,
        "int": 42,
        "float": 3.14,
        "string": "hello",
        "array": [1, 2, 3],
        "object": {"a": 1, "b": 2}
      }
      """
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    #expect(json1 == json2)
  }

  @Test("parse → dump → parse: nested arrays")
  func parseDumpParseNestedArrays() throws {
    let input = """
      [[1, 2], [3, [4, 5]], {"key": [6, 7]}]
      """
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    #expect(json1 == json2)
  }

  @Test("parse → dump → parse: strings with escaped characters")
  func parseDumpParseEscapedStrings() throws {
    let input = #"""
      {"tab": "\t", "newline": "\n", "quote": "\"", "backslash": "\\", "unicode": "A"}
      """#
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    #expect(json1 == json2)
  }

  @Test("parse → dump → parse: edge numbers (negative, large integer)")
  func parseDumpParseEdgeNumbers() throws {
    let input = """
      {"neg": -1, "zero": 0, "large": 999999999999, "negZero": -0, "frac": -0.5}
      """
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    #expect(json1 == json2)
  }

  @Test("parse → dump → parse: empty containers")
  func parseDumpParseEmpty() throws {
    let input = """
      {"empty": {}, "emptyArr": [], "null": null}
      """
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    #expect(json1 == json2)
  }

  @Test("parse → dump(indent:) → parse: pretty-printed round-trip")
  func parseDumpPrettyRoundTrip() throws {
    let input = """
      {"a": 1, "b": [2, 3, {"c": 4}]}
      """
    let json1 = try JSON.parse(input)
    let pretty = json1.dump(indent: 2)
    let json2 = try JSON.parse(pretty)
    #expect(json1 == json2)
  }

  @Test("parse → dump(ensureAscii:) → parse: ascii-safe round-trip")
  func parseDumpEnsureAsciiRoundTrip() throws {
    let input = """
      {"unicode": "héllo ñiño"}
      """
    let json1 = try JSON.parse(input)
    let asciiDump = json1.dump(ensureAscii: true)
    let json2 = try JSON.parse(asciiDump)
    // The parsed value should have the same string content
    #expect(json1["unicode"] == json2["unicode"])
  }

  @Test("parse → dump → parse: key order preservation")
  func parseDumpParseKeyOrder() throws {
    let input = """
      {"z": 1, "a": 2, "m": 3, "b": 4}
      """
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    // Verify key order is preserved
    let keys1 = json1.keyValuePairs().map(\.key)
    let keys2 = json2.keyValuePairs().map(\.key)
    #expect(keys1 == keys2)
  }
}
