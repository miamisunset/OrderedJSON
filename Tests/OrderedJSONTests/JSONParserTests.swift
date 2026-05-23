import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - JSONParser Tests

@Test func parseNull() throws {
  let result = try JSON.parse("null")
  #expect(result.isNull)
}

@Test func parseBooleanTrue() throws {
  let result = try JSON.parse("true")
  #expect(result == JSON.boolean(true))
}

@Test func parseBooleanFalse() throws {
  let result = try JSON.parse("false")
  #expect(result == JSON.boolean(false))
}

@Test func parseInteger() throws {
  let result = try JSON.parse("42")
  #expect(result == JSON.number(.integer(42)))
}

@Test func parseNegativeInteger() throws {
  let result = try JSON.parse("-42")
  #expect(result == JSON.number(.integer(-42)))
}

@Test func parseFloat() throws {
  let result = try JSON.parse("3.14")
  #expect(result == JSON.number(.float(3.14)))
}

@Test func parseFloatWithExponent() throws {
  let result = try JSON.parse("2.5e2")
  #expect(result == JSON.number(.float(250)))
}

@Test func parseFloatWithNegativeExponent() throws {
  let result = try JSON.parse("1e-2")
  #expect(result == JSON.number(.float(0.01)))
}

@Test func parseString() throws {
  let result = try JSON.parse("\"hello\"")
  #expect(result == JSON.string("hello"))
}

@Test func parseStringWithEscapes() throws {
  let result = try JSON.parse("\"hello\\n\\t\\r\\\\\\\"\"")
  #expect(result == JSON.string("hello\n\t\r\\\""))
}

@Test func parseStringWithUnicodeEscape() throws {
  let result = try JSON.parse("\"\\u0041\"")
  #expect(result == JSON.string("A"))
}

@Test func parseStringWithSlash() throws {
  let result = try JSON.parse("\"a\\/b\"")
  #expect(result == JSON.string("a/b"))
}

@Test func parseStringWithBackspaceFormfeed() throws {
  let result = try JSON.parse("\"a\\b\\fb\"")
  #expect(result == JSON.string("a\u{8}\u{12}b"))
}

@Test func parseEmptyArray() throws {
  let result = try JSON.parse("[]")
  #expect(result.isArray)
  #expect(result.isEmpty)
}

@Test func parseArray() throws {
  let result = try JSON.parse("[1, \"hello\", true]")
  #expect(result.isArray)
  #expect(result.count == 3)
  #expect(result[0] == JSON.number(.integer(1)))
  #expect(result[1] == JSON.string("hello"))
  #expect(result[2] == JSON.boolean(true))
}

@Test func parseNestedArray() throws {
  let result = try JSON.parse("[[1, 2], [3, 4]]")
  #expect(result.isArray)
  #expect(result.count == 2)
  #expect(result[0]?.count == 2)
  #expect(result[1]?.count == 2)
}

@Test func parseEmptyObject() throws {
  let result = try JSON.parse("{}")
  #expect(result.isObject)
  #expect(result.isEmpty)
}

@Test func parseObject() throws {
  let result = try JSON.parse("{\"a\": 1, \"b\": \"hello\"}")
  #expect(result.isObject)
  #expect(result.count == 2)
  #expect(result["a"] == JSON.number(.integer(1)))
  #expect(result["b"] == JSON.string("hello"))
}

@Test func parseObjectPreservesOrder() throws {
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

@Test func parseNestedObject() throws {
  let result = try JSON.parse("{\"a\": {\"b\": {\"c\": \"deep\"}}}")
  #expect(result["a"]?["b"]?["c"] == JSON.string("deep"))
}

@Test func parseWhitespace() throws {
  let result = try JSON.parse("  {  \"a\"  :  1  }  ")
  #expect(result.isObject)
  #expect(result["a"] == JSON.number(.integer(1)))
}

@Test func parseTrailingWhitespace() throws {
  let result = try JSON.parse("  [1, 2]  ")
  #expect(result.isArray)
  #expect(result.count == 2)
}

// MARK: - Parser Error Cases

@Test func parseErrorUnexpectedEnd() throws {
  #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("") }
  #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("\"hello") }
  #expect(throws: JSONParseError.expectedString(1)) { try JSON.parse("{") }
  #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("[") }
}

@Test func parseErrorUnexpectedToken() throws {
  #expect(throws: JSONParseError.unexpectedToken(0)) { try JSON.parse("}") }
  #expect(throws: JSONParseError.unexpectedToken(0)) { try JSON.parse("x") }
  #expect(throws: JSONParseError.unexpectedToken(4)) { try JSON.parse("truex") }
}

@Test func parseErrorExpectedColon() throws {
  #expect(throws: JSONParseError.expectedColon(5)) { try JSON.parse("{\"a\" 1}") }
}

@Test func parseErrorExpectedCloseBrace() throws {
  #expect(throws: JSONParseError.expectedCloseBrace(7)) { try JSON.parse("{\"a\": 1") }
}

@Test func parseErrorExpectedCloseBracket() throws {
  #expect(throws: JSONParseError.expectedCloseBracket(2)) { try JSON.parse("[1") }
}

@Test func parseErrorExpectedString() throws {
  #expect(throws: JSONParseError.expectedString(1)) { try JSON.parse("{a: 1}") }
}

@Test func parseErrorInvalidEscape() throws {
  #expect(throws: JSONParseError.invalidEscape(2)) { try JSON.parse("\"\\x\"") }
}

@Test func parseErrorInvalidUnicodeEscape() throws {
  #expect(throws: JSONParseError.invalidUnicodeEscape(3)) { try JSON.parse("\"\\u\"") }
  #expect(throws: JSONParseError.invalidUnicodeEscape(3)) { try JSON.parse("\"\\uQQQQ\"") }
}

@Test func parseErrorInvalidNumber() throws {
  #expect(throws: JSONParseError.invalidNumber(1)) { try JSON.parse("-") }
  #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("0.") }
}

@Test func parseErrorTrailingBackslash() throws {
  // Line 110: backslash at end of string
  #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("\"\\") }
}

@Test func parseErrorInvalidDouble() throws {
  // Line 215: Double(s) returns nil for incomplete exponent
  #expect(throws: JSONParseError.invalidNumber(0)) { try JSON.parse("1.0e+") }
}

@Test func parseErrorTrailingGarbage() throws {
  #expect(throws: JSONParseError.unexpectedToken(3)) { try JSON.parse("[1]x") }
}

@Test func parseErrorBooleanIncomplete() throws {
  #expect(throws: JSONParseError.unexpectedToken(0)) { try JSON.parse("tr") }
  #expect(throws: JSONParseError.unexpectedToken(0)) { try JSON.parse("f") }
}

@Test func parseErrorNullIncomplete() throws {
  #expect(throws: JSONParseError.unexpectedToken(0)) { try JSON.parse("nu") }
}
