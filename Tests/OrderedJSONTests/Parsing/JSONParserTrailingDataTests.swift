import Foundation
import Testing

@testable import OrderedJSON

@Suite("Parser trailing data tests")
struct JSONParserTrailingDataTests {
  @Test("trailing data after null rejected")
  func trailingDataAfterNullRejected() {
    // "null extra" — null ends at col 4, space at col 5 skipped, 'e' at col 6 → unexpectedToken
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 6)) {
      try JSON.parse("null extra")
    }
  }

  @Test("trailing data after true rejected")
  func trailingDataAfterTrueRejected() {
    // "true extra" — true ends at col 4, space at col 5 skipped, 'e' at col 6 → unexpectedToken
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 6)) {
      try JSON.parse("true extra")
    }
  }

  @Test("trailing data after number rejected")
  func trailingDataAfterNumberRejected() {
    // "42 extra" — 42 ends at col 2, space at col 3 skipped, 'e' at col 4 → unexpectedToken
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 4)) {
      try JSON.parse("42 extra")
    }
  }

  @Test("trailing data after string rejected")
  func trailingDataAfterStringRejected() {
    // "\"hello\" extra" — string ends at col 7, space at col 8 skipped, 'e' at col 9 → unexpectedToken
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 9)) {
      try JSON.parse("\"hello\" extra")
    }
  }

  @Test("trailing data after array rejected")
  func trailingDataAfterArrayRejected() {
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 5)) {
      try JSON.parse("[1] extra")
    }
  }

  @Test("trailing data after object rejected")
  func trailingDataAfterObjectRejected() {
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 10)) {
      try JSON.parse("{\"a\": 1} extra")
    }
  }

  @Test("SAX accept rejects trailing data")
  func saxAcceptRejectsTrailingData() {
    #expect(JSON.accept("null extra") == false)
    #expect(JSON.accept("true extra") == false)
    #expect(JSON.accept("42 extra") == false)
    #expect(JSON.accept("\"hi\" extra") == false)
    #expect(JSON.accept("[1] extra") == false)
    #expect(JSON.accept(#"{"k":"v"} extra"#) == false)
  }

  @Test("SAX accept accepts whitespace after value")
  func saxAcceptAcceptsWhitespaceAfterValue() {
    #expect(JSON.accept("null "))
    #expect(JSON.accept("true  "))
    #expect(JSON.accept("42\n"))
    #expect(JSON.accept("\"hi\"\t"))
  }

  @Test("multiple spaces and newlines between values rejected")
  func multipleSpacesAndNewlinesBetweenValuesRejected() {
    #expect(throws: JSONParseError.unexpectedToken(line: 2, column: 1)) {
      try JSON.parse("true\nfalse")
    }
  }
}
