import Foundation
import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - JSONParser Tests

@Suite("Parser Tests") struct JSONParserTests {
  @Test("parse null") func parseNull() throws {
    let result = try JSON.parse("null")
    #expect(result.isNull)
  }

  @Test("parse boolean true") func parseBooleanTrue() throws {
    let result = try JSON.parse("true")
    #expect(result == JSON.boolean(true))
  }

  @Test("parse boolean false") func parseBooleanFalse() throws {
    let result = try JSON.parse("false")
    #expect(result == JSON.boolean(false))
  }

  @Test("parse integer") func parseInteger() throws {
    let result = try JSON.parse("42")
    #expect(result == JSON.number(.integer(42)))
  }

  @Test("parse negative integer") func parseNegativeInteger() throws {
    let result = try JSON.parse("-42")
    #expect(result == JSON.number(.integer(-42)))
  }

  @Test("parse float") func parseFloat() throws {
    let result = try JSON.parse("3.14")
    #expect(result == JSON.number(.float(3.14)))
  }

  @Test("parse float with exponent") func parseFloatWithExponent() throws {
    let result = try JSON.parse("2.5e2")
    #expect(result == JSON.number(.float(250)))
  }

  @Test("parse float with negative exponent") func parseFloatWithNegativeExponent() throws {
    let result = try JSON.parse("1e-2")
    #expect(result == JSON.number(.float(0.01)))
  }

  @Test("parse float with positive exponent") func parseFloatWithPositiveExponent() throws {
    let result = try JSON.parse("6.02e+23")
    #expect(result == JSON.number(.float(6.02e23)))
  }

  @Test("parse large exponent") func parseLargeExponent() throws {
    let result = try JSON.parse("-3.14E+10")
    #expect(result == JSON.number(.float(-3.14e+10)))
  }

  @Test("parse string") func parseString() throws {
    let result = try JSON.parse("\"hello\"")
    #expect(result == JSON.string("hello"))
  }

  @Test("parse string with escapes") func parseStringWithEscapes() throws {
    let result = try JSON.parse("\"hello\\n\\t\\r\\\\\\\"\"")
    #expect(result == JSON.string("hello\n\t\r\\\""))
  }

  @Test("parse string with unicode escape") func parseStringWithUnicodeEscape() throws {
    let result = try JSON.parse("\"\\u0041\"")
    #expect(result == JSON.string("A"))
  }

  @Test("parse string with surrogate pair") func parseStringWithSurrogatePair() throws {
    let result = try JSON.parse("\"\\uD83D\\uDE00\"")
    #expect(result == JSON.string("😀"))
  }

  @Test("parse string with slash") func parseStringWithSlash() throws {
    let result = try JSON.parse("\"a\\/b\"")
    #expect(result == JSON.string("a/b"))
  }

  @Test("parse string with backspace formfeed") func parseStringWithBackspaceFormfeed() throws {
    let result = try JSON.parse("\"a\\b\\fb\"")
    #expect(result == JSON.string("a\u{8}\u{0C}b"))
  }

  @Test("parse empty array") func parseEmptyArray() throws {
    let result = try JSON.parse("[]")
    #expect(result.isArray)
    #expect(result.isEmpty)
  }

  @Test("parse array") func parseArray() throws {
    let result = try JSON.parse("[1, \"hello\", true]")
    #expect(result.isArray)
    #expect(result.count == 3)
    #expect(result[0] == JSON.number(.integer(1)))
    #expect(result[1] == JSON.string("hello"))
    #expect(result[2] == JSON.boolean(true))
  }

  @Test("parse nested array") func parseNestedArray() throws {
    let result = try JSON.parse("[[1, 2], [3, 4]]")
    #expect(result.isArray)
    #expect(result.count == 2)
    #expect(result[0]?.count == 2)
    #expect(result[1]?.count == 2)
  }

  @Test("parse empty object") func parseEmptyObject() throws {
    let result = try JSON.parse("{}")
    #expect(result.isObject)
    #expect(result.isEmpty)
  }

  @Test("parse object") func parseObject() throws {
    let result = try JSON.parse("{\"a\": 1, \"b\": \"hello\"}")
    #expect(result.isObject)
    #expect(result.count == 2)
    #expect(result["a"] == JSON.number(.integer(1)))
    #expect(result["b"] == JSON.string("hello"))
  }

  @Test("parse object preserves order") func parseObjectPreservesOrder() throws {
    let result = try JSON.parse("{\"c\": 3, \"a\": 1, \"b\": 2}")
    #expect(result.isObject)
    #expect(result.count == 3)
    guard case .object(let dict) = result.storage else {
      Issue.record("Expected object")
      return
    }
    let keys = Array(dict.keys)
    #expect(keys[0] == "c")
    #expect(keys[1] == "a")
    #expect(keys[2] == "b")
  }

  @Test("parse nested object") func parseNestedObject() throws {
    let result = try JSON.parse("{\"a\": {\"b\": {\"c\": \"deep\"}}}")
    #expect(result["a"]?["b"]?["c"] == JSON.string("deep"))
  }

  @Test("parse whitespace") func parseWhitespace() throws {
    let result = try JSON.parse("  {  \"a\"  :  1  }  ")
    #expect(result.isObject)
    #expect(result["a"] == JSON.number(.integer(1)))
  }

  @Test("parse trailing whitespace") func parseTrailingWhitespace() throws {
    let result = try JSON.parse("  [1, 2]  ")
    #expect(result.isArray)
    #expect(result.count == 2)
  }
}

// MARK: - Parser Error Cases

@Suite("Parser Error Tests") struct JSONParserErrorTests {
  @Test("parse error unexpected end") func parseErrorUnexpectedEnd() throws {
    #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("") }
    #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("\"hello") }
    #expect(throws: JSONParseError.expectedString(line: 1, column: 2)) { try JSON.parse("{") }
    #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("[") }
  }

  @Test("parse error unexpected token") func parseErrorUnexpectedToken() throws {
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) { try JSON.parse("}") }
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) { try JSON.parse("x") }
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 5)) { try JSON.parse("truex") }
  }

  @Test("parse error expected colon") func parseErrorExpectedColon() throws {
    #expect(throws: JSONParseError.expectedColon(line: 1, column: 6)) {
      try JSON.parse("{\"a\" 1}")
    }
  }

  @Test("parse error expected close brace") func parseErrorExpectedCloseBrace() throws {
    #expect(throws: JSONParseError.expectedCloseBrace(line: 1, column: 8)) {
      try JSON.parse("{\"a\": 1")
    }
  }

  @Test("parse error expected close bracket") func parseErrorExpectedCloseBracket() throws {
    #expect(throws: JSONParseError.expectedCloseBracket(line: 1, column: 3)) {
      try JSON.parse("[1")
    }
  }

  @Test("parse error expected string") func parseErrorExpectedString() throws {
    #expect(throws: JSONParseError.expectedString(line: 1, column: 2)) { try JSON.parse("{a: 1}") }
  }

  @Test("parse error invalid escape") func parseErrorInvalidEscape() throws {
    #expect(throws: JSONParseError.invalidEscape(line: 1, column: 3)) { try JSON.parse("\"\\x\"") }
  }

  @Test("parse error invalid unicode escape") func parseErrorInvalidUnicodeEscape() throws {
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 4)) {
      try JSON.parse("\"\\u\"")
    }
    #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 4)) {
      try JSON.parse("\"\\uQQQQ\"")
    }
  }

  @Test("parse error invalid number") func parseErrorInvalidNumber() throws {
    #expect(throws: JSONParseError.invalidNumber(line: 1, column: 2)) { try JSON.parse("-") }
    #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("0.") }
  }

  @Test("parse error trailing backslash") func parseErrorTrailingBackslash() throws {
    #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("\"\\") }
  }

  @Test("parse error invalid exponent") func parseErrorInvalidExponent() throws {
    #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("1.0e+") }
  }

  @Test("parse error trailing garbage") func parseErrorTrailingGarbage() throws {
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 4)) { try JSON.parse("[1]x") }
  }

  @Test("parse error boolean incomplete") func parseErrorBooleanIncomplete() throws {
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) { try JSON.parse("tr") }
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) { try JSON.parse("f") }
  }

  @Test("parse error null incomplete") func parseErrorNullIncomplete() throws {
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) { try JSON.parse("nu") }
  }
}

// MARK: - ParserOptions Tests

@Suite("Parser Options Tests") struct JSONParserOptionsTests {
  @Test("parse with trailing comma") func parseWithTrailingComma() throws {
    let opts = JSON.ParserOptions(allowTrailingCommas: true)
    let result = try JSON.parse("[1, 2,]", options: opts)
    #expect(result.isArray)
    #expect(result.count == 2)
    #expect(result[0] == JSON.number(.integer(1)))
    #expect(result[1] == JSON.number(.integer(2)))
  }

  @Test("parse with trailing comma object") func parseWithTrailingCommaObject() throws {
    let opts = JSON.ParserOptions(allowTrailingCommas: true)
    let result = try JSON.parse("{\"a\": 1, \"b\": 2,}", options: opts)
    #expect(result.isObject)
    #expect(result.count == 2)
    #expect(result["a"] == JSON.number(.integer(1)))
    #expect(result["b"] == JSON.number(.integer(2)))
  }

  @Test("parse without trailing comma fails") func parseWithoutTrailingCommaFails() throws {
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 7)) {
      try JSON.parse("[1, 2,]")
    }
  }

  @Test("parse depth exceeded") func parseDepthExceeded() throws {
    let opts = JSON.ParserOptions(maxDepth: 3)
    let deepJSON = "{\"a\": {\"b\": {\"c\": {\"d\": 1}}}"
    #expect(throws: JSONParseError.depthExceeded(line: 1, column: 20, depth: 4, maxDepth: 3)) {
      try JSON.parse(deepJSON, options: opts)
    }
  }

  @Test("parse depth exceeds limit by one") func parseDepthExceedsLimitByOne() throws {
    let opts = JSON.ParserOptions(maxDepth: 3)
    let deepJSON = "{\"a\": {\"b\": {\"c\": {\"d\": 1}}}}"
    #expect(throws: JSONParseError.depthExceeded(line: 1, column: 20, depth: 4, maxDepth: 3)) {
      try JSON.parse(deepJSON, options: opts)
    }
  }

  @Test("parse depth at limit") func parseDepthAtLimit() throws {
    let opts = JSON.ParserOptions(maxDepth: 3)
    let nested = "{\"a\": {\"b\": {\"c\": 1}}}"
    let result = try JSON.parse(nested, options: opts)
    #expect(result["a"]?["b"]?["c"] == JSON.number(.integer(1)))
  }
}

// MARK: - Data Parsing Tests

@Suite("Parser Data Tests") struct JSONParserDataTests {
  @Test("parse from data") func parseFromData() throws {
    let data = Data(#"{"a": 1}"#.utf8)
    let result = try JSON.parse(data)
    #expect(result.isObject)
    #expect(result["a"] == JSON.number(.integer(1)))
  }

  @Test("parse from data with options") func parseFromDataWithOptions() throws {
    let opts = JSON.ParserOptions(allowTrailingCommas: true)
    let data = Data("[1, 2,]".utf8)
    let result = try JSON.parse(data, options: opts)
    #expect(result.isArray)
    #expect(result.count == 2)
  }

  @Test("parse from invalid encoding") func parseFromInvalidEncoding() throws {
    // Invalid UTF-8 bytes
    let invalidData = Data([0xFF, 0xFE, 0x00, 0x00])
    #expect(throws: JSONParseError.invalidEncoding()) {
      try JSON.parse(invalidData)
    }
  }
}

// MARK: - Standard Encoding Tests

@Suite("Parser Encoding Tests") struct JSONParserEncodingTests {
  @Test("encode standard null") func encodeStandardNull() {
    #expect(JSON.null.dump(indent: nil) == "null")
  }

  @Test("encode standard bool") func encodeStandardBool() {
    #expect(JSON.boolean(true).dump(indent: nil) == "true")
  }

  @Test("encode standard int") func encodeStandardInt() {
    #expect(JSON.number(.integer(42)).dump(indent: nil) == "42")
  }

  @Test("encode standard float") func encodeStandardFloat() {
    #expect(JSON.number(.float(3.14)).dump(indent: nil) == "3.14")
  }

  @Test("encode standard string") func encodeStandardString() {
    #expect(JSON.string("hello").dump(indent: nil) == "\"hello\"")
  }

  @Test("encode standard array") func encodeStandardArray() {
    let value = JSON.array([
      JSON.string("a"),
      JSON.number(.integer(1)),
      JSON.boolean(true),
    ])
    #expect(value.dump(indent: nil) == "[\"a\",1,true]")
  }

  @Test("encode standard object") func encodeStandardObject() {
    let value = JSON.object([
      "name": JSON.string("Alice"),
      "age": JSON.number(.integer(30)),
    ])
    #expect(value.dump(indent: nil) == "{\"name\":\"Alice\",\"age\":30}")
  }
}

// MARK: - Large Value Edge Cases

@Suite("Parser Large Value Tests") struct JSONParserLargeValueTests {
  @Test("parse large integer beyond int64 max") func parseLargeIntegerBeyondInt64Max() throws {
    // Value > Int64.max should be stored as .float(Double)
    let result = try JSON.parse("9223372036854775808")
    #expect(result.isFloat)
    #expect(result == JSON.number(.float(9_223_372_036_854_775_808.0)))
  }

  @Test("parse large negative integer beyond int64 min")
  func parseLargeNegativeIntegerBeyondInt64Min() throws {
    // Value < Int64.min should be stored as .float(Double)
    let result = try JSON.parse("-9223372036854775809")
    #expect(result.isFloat)
  }

  @Test("parse overflow to infinity throws") func parseOverflowToInfinityThrows() throws {
    // 1e400 overflows Double range → Infinity, must throw
    #expect(throws: JSONParseError.invalidNumber(line: 1, column: 1)) {
      try JSON.parse("1e400")
    }
  }
}
