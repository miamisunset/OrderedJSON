import Testing

@testable import OrderedJSON

@Suite("Parser trailing comma tests")
struct JSONParserTrailingCommaTests {
  @Test("trailing comma rejected by default")
  func trailingCommaRejectedDefault() {
    // [1,] — after comma, parser tries to parse value, sees ] → unexpectedToken at col 4
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 4)) {
      try JSON.parse("[1,]")
    }
  }

  @Test("trailing comma object rejected by default")
  func trailingCommaObjectRejectedDefault() {
    // {"a": 1,} — after comma, parser tries to parse key, sees } → expectedString at col 9
    #expect(throws: JSONParseError.expectedString(line: 1, column: 9)) {
      try JSON.parse("{\"a\": 1,}")
    }
  }

  @Test("trailing comma accepted with option")
  func trailingCommaAcceptedWithOption() throws {
    let opts = JSON.ParserOptions(allowTrailingCommas: true)
    let result = try JSON.parse("[1,]", options: opts)
    #expect(result.isArray)
    #expect(result.count == 1)
    #expect(result[0] == JSON.number(.integer(1)))
  }

  @Test("trailing comma object accepted with option")
  func trailingCommaObjectAcceptedWithOption() throws {
    let opts = JSON.ParserOptions(allowTrailingCommas: true)
    let result = try JSON.parse("{\"a\": 1,}", options: opts)
    #expect(result.isObject)
    #expect(result.count == 1)
    #expect(result["a"] == JSON.number(.integer(1)))
  }

  @Test("double comma rejected even with allowTrailingCommas")
  func doubleCommaRejected() {
    // [1,,2] — after first comma, parser tries to parse value, sees , → unexpectedToken at col 4
    let opts = JSON.ParserOptions(allowTrailingCommas: true)
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 4)) {
      try JSON.parse("[1,,2]", options: opts)
    }
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 4)) {
      try JSON.parse("[1,,2]")
    }
  }

  @Test("double comma in object rejected")
  func doubleCommaObjectRejected() {
    // {"a": 1,,} — after comma, parser tries to parse key, sees , → expectedString at col 9
    let opts = JSON.ParserOptions(allowTrailingCommas: true)
    #expect(throws: JSONParseError.expectedString(line: 1, column: 9)) {
      try JSON.parse("{\"a\": 1,,}", options: opts)
    }
  }

  @Test("trailing comma with whitespace accepted")
  func trailingCommaWithWhitespace() throws {
    let opts = JSON.ParserOptions(allowTrailingCommas: true)
    let result = try JSON.parse("[1, ]", options: opts)
    #expect(result.isArray)
    #expect(result.count == 1)
  }

  @Test("trailing comma with whitespace in object")
  func trailingCommaWithWhitespaceObject() throws {
    let opts = JSON.ParserOptions(allowTrailingCommas: true)
    let result = try JSON.parse("{\"a\": 1, }", options: opts)
    #expect(result.isObject)
    #expect(result.count == 1)
  }
}
