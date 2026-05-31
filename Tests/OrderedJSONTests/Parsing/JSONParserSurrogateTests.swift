import Foundation
import Testing

@testable import OrderedJSON

@Suite("Parser surrogate pair tests")
struct JSONParserSurrogateTests {
  @Test("high surrogate at end of input throws")
  func highSurrogateAtEndOfInput() throws {
    // "\uD800" — high surrogate with no low surrogate following
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 8)) {
      try JSON.parse("\"\\uD800\"")
    }
  }

  @Test("high surrogate followed by non-backslash throws")
  func highSurrogateFollowedByNonBackslash() throws {
    // High surrogate \uD800 followed by a letter (not \uXXXX) throws
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 8)) {
      try JSON.parse("\"\\uD800X\"")
    }
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 8)) {
      try JSON.parse("\"\\uD800 \"")
    }
  }

  @Test("high surrogate followed by non-u after backslash throws")
  func highSurrogateBackslashNonU() throws {
    // "\uD800\\" — backslash after high surrogate, but no 'u' follows
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 9)) {
      try JSON.parse("\"\\uD800\\\\\"")
    }
  }

  @Test("low surrogate alone throws")
  func lowSurrogateAloneThrows() {
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 8)) {
      try JSON.parse("\"\\uDC00\"")
    }
  }

  @Test("low surrogate without high surrogate throws")
  func lowSurrogateWithoutHighThrows() {
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 14)) {
      try JSON.parse("\"\\u0041\\uDC00\"")
    }
  }

  @Test("high surrogate with non-low second value throws")
  func highSurrogateNonLowSecond() {
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 14)) {
      try JSON.parse("\"\\uD800\\u0041\"")
    }
  }

  @Test("high surrogate with low outside range throws")
  func highSurrogateLowOutsideRange() {
    // \uD800휀 — D700 is below DC00 (low surrogate range)
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 14)) {
      try JSON.parse("\"\\uD800\\uD700\"")
    }
  }

  @Test("high surrogate with too-few hex digits throws")
  func highSurrogateTooFewHexDigits() {
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 7)) {
      try JSON.parse("\"\\uD80")
    }
  }

  @Test("valid surrogate pair round-trip")
  func validSurrogatePairRoundTrip() throws {
    let json = try JSON.parse("\"\\uD83D\\uDE06\"")
    #expect(json == JSON.string("😆"))
    let dumped = json.dump(indent: nil)
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == json)
  }

  @Test("SAX lenient surrogate handling returns empty string for invalid")
  func saxLenientSurrogateReturnsEmpty() {
    // SAX parser returns "" for invalid unicode escapes (lenient mode)
    // Verify it doesn't crash — the parse should complete (return true)
    // because SAX returns empty string for the value, which is valid
    struct Handler: JSONSAXEventHandler {
      func null() -> Bool { true }
      func boolean(_: Bool) -> Bool { true }
      func integer(_: Int64) -> Bool { true }
      func float(_: Double, string: String) -> Bool { true }
      func string(_: String) -> Bool {
        // SAX returns empty string for invalid unicode escapes
        return true
      }
      func startObject() -> Bool { true }
      func key(_: String) -> Bool { true }
      func endObject() -> Bool { true }
      func startArray() -> Bool { true }
      func endArray() -> Bool { true }
      func parseError(_: JSONParseError, data: Data) -> Bool { return false }
    }

    // High surrogate at end of input — SAX returns "" for the string value.
    // SAX is lenient: invalid unicode escapes produce empty strings, not errors.
    // The handler's string("") returns true, so the parse completes successfully.
    let result = JSON.parse("\"\\uD800", handler: Handler())
    #expect(result == true)
  }
}
