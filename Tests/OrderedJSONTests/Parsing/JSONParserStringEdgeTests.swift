import Testing

@testable import OrderedJSON

@Suite("Parser string edge case tests")
struct JSONParserStringEdgeTests {
  @Test("control character U+0000 rejected in string")
  func controlCharacterNullRejected() {
    // Construct JSON string with raw NUL character: "<NUL>"
    let nul = "\u{0}"  // Swift unicode escape for U+0000
    let jsonString = "\"" + nul + "\""
    #expect(throws: JSONParseError.invalidEscape(line: 1, column: 2)) {
      try JSON.parse(jsonString)
    }
  }

  @Test("control character U+0001 rejected in string")
  func controlCharacterSOHRejected() {
    // Construct JSON string with raw SOH character: "<SOH>"
    let soh = "\u{1}"  // Swift unicode escape for U+0001
    let jsonString = "\"" + soh + "\""
    #expect(throws: JSONParseError.invalidEscape(line: 1, column: 2)) {
      try JSON.parse(jsonString)
    }
  }

  @Test("raw tab control char in string rejected")
  func rawTabControlCharRejected() {
    // Construct JSON string with raw tab character
    let tab = "\u{9}"  // Swift unicode escape for U+0009 (tab)
    let jsonString = "\"" + tab + "\""
    #expect(throws: JSONParseError.invalidEscape(line: 1, column: 2)) {
      try JSON.parse(jsonString)
    }
  }

  @Test("escaped tab is valid")
  func escapedTabIsValid() throws {
    // \t is a valid JSON escape — should produce a tab character
    let result = try JSON.parse("\"\\t\"")
    #expect(result == JSON.string("\u{9}"))
  }

  @Test("invalid escape \\x rejected")
  func invalidEscapeXRejected() {
    #expect(throws: JSONParseError.invalidEscape(line: 1, column: 3)) {
      try JSON.parse("\"\\x\"")
    }
  }

  @Test("invalid escape \\8 rejected")
  func invalidEscape8Rejected() {
    #expect(throws: JSONParseError.invalidEscape(line: 1, column: 3)) {
      try JSON.parse("\"\\8\"")
    }
  }

  @Test("invalid escape \\9 rejected")
  func invalidEscape9Rejected() {
    #expect(throws: JSONParseError.invalidEscape(line: 1, column: 3)) {
      try JSON.parse("\"\\9\"")
    }
  }

  @Test("lone surrogate in raw string content accepted")
  func loneSurrogateInRawStringAccepted() throws {
    // A lone surrogate U+D800 in raw string content — Swift decodes this as
    // the replacement character U+FFFD (surrogates are not valid Swift scalars),
    // so the parser sees a valid non-control character and accepts it.
    let utf8Bytes: [UInt8] = [0x22, 0xED, 0xA0, 0x80, 0x22]  // '"' + U+D800 + '"'
    let jsonString = String(decoding: utf8Bytes, as: Unicode.UTF8.self)
    let result = try JSON.parse(jsonString)
    #expect(result.isString)
  }
}
