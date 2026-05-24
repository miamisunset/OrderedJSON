import Foundation
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

@Test func parseFloatWithPositiveExponent() throws {
  let result = try JSON.parse("6.02e+23")
  #expect(result == JSON.number(.float(6.02e23)))
}

@Test func parseLargeExponent() throws {
  let result = try JSON.parse("-3.14E+10")
  #expect(result == JSON.number(.float(-3.14E+10)))
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

@Test func parseStringWithSurrogatePair() throws {
  let result = try JSON.parse("\"\\uD83D\\uDE00\"")
  #expect(result == JSON.string("😀"))
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
  #expect(throws: JSONParseError.expectedString(line: 1, column: 2)) { try JSON.parse("{") }
  #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("[") }
}

@Test func parseErrorUnexpectedToken() throws {
  #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) { try JSON.parse("}") }
  #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) { try JSON.parse("x") }
  #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 5)) { try JSON.parse("truex") }
}

@Test func parseErrorExpectedColon() throws {
  #expect(throws: JSONParseError.expectedColon(line: 1, column: 6)) { try JSON.parse("{\"a\" 1}") }
}

@Test func parseErrorExpectedCloseBrace() throws {
  #expect(throws: JSONParseError.expectedCloseBrace(line: 1, column: 8)) {
    try JSON.parse("{\"a\": 1")
  }
}

@Test func parseErrorExpectedCloseBracket() throws {
  #expect(throws: JSONParseError.expectedCloseBracket(line: 1, column: 3)) { try JSON.parse("[1") }
}

@Test func parseErrorExpectedString() throws {
  #expect(throws: JSONParseError.expectedString(line: 1, column: 2)) { try JSON.parse("{a: 1}") }
}

@Test func parseErrorInvalidEscape() throws {
  #expect(throws: JSONParseError.invalidEscape(line: 1, column: 3)) { try JSON.parse("\"\\x\"") }
}

@Test func parseErrorInvalidUnicodeEscape() throws {
  #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 4)) {
    try JSON.parse("\"\\u\"")
  }
  #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 4)) {
    try JSON.parse("\"\\uQQQQ\"")
  }
}

@Test func parseErrorInvalidNumber() throws {
  #expect(throws: JSONParseError.invalidNumber(line: 1, column: 2)) { try JSON.parse("-") }
  #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("0.") }
}

@Test func parseErrorTrailingBackslash() throws {
  #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("\"\\") }
}

@Test func parseErrorInvalidExponent() throws {
  #expect(throws: JSONParseError.unexpectedEnd()) { try JSON.parse("1.0e+") }
}

@Test func parseErrorTrailingGarbage() throws {
  #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 4)) { try JSON.parse("[1]x") }
}

@Test func parseErrorBooleanIncomplete() throws {
  #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) { try JSON.parse("tr") }
  #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) { try JSON.parse("f") }
}

@Test func parseErrorNullIncomplete() throws {
  #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) { try JSON.parse("nu") }
}

// MARK: - ParserOptions Tests

@Test func parseWithTrailingComma() throws {
  let opts = JSON.ParserOptions(allowTrailingCommas: true)
  let result = try JSON.parse("[1, 2,]", options: opts)
  #expect(result.isArray)
  #expect(result.count == 2)
  #expect(result[0] == JSON.number(.integer(1)))
  #expect(result[1] == JSON.number(.integer(2)))
}

@Test func parseWithTrailingCommaObject() throws {
  let opts = JSON.ParserOptions(allowTrailingCommas: true)
  let result = try JSON.parse("{\"a\": 1, \"b\": 2,}", options: opts)
  #expect(result.isObject)
  #expect(result.count == 2)
  #expect(result["a"] == JSON.number(.integer(1)))
  #expect(result["b"] == JSON.number(.integer(2)))
}

@Test func parseWithoutTrailingCommaFails() throws {
  #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 7)) {
    try JSON.parse("[1, 2,]")
  }
}

@Test func parseDepthExceeded() throws {
  let opts = JSON.ParserOptions(maxDepth: 3)
  let deepJSON = "{\"a\": {\"b\": {\"c\": {\"d\": 1}}}"
  #expect(throws: JSONParseError.depthExceeded(line: 1, column: 20, depth: 4, maxDepth: 3)) {
    try JSON.parse(deepJSON, options: opts)
  }
}

// MARK: - Data Parsing Tests

@Test func parseFromData() throws {
  let data = Data(#"{"a": 1}"#.utf8)
  let result = try JSON.parse(data)
  #expect(result.isObject)
  #expect(result["a"] == JSON.number(.integer(1)))
}

@Test func parseFromDataWithOptions() throws {
  let opts = JSON.ParserOptions(allowTrailingCommas: true)
  let data = Data("[1, 2,]".utf8)
  let result = try JSON.parse(data, options: opts)
  #expect(result.isArray)
  #expect(result.count == 2)
}

@Test func parseFromInvalidEncoding() throws {
  // Invalid UTF-8 bytes
  let invalidData = Data([0xFF, 0xFE, 0x00, 0x00])
  #expect(throws: JSONParseError.invalidEncoding()) {
    try JSON.parse(invalidData)
  }
}

// MARK: - Surrogate Pair Edge Cases

@Test func parseHighSurrogateWithoutLow() throws {
  #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 8)) {
    try JSON.parse("\"\\uD800\"")
  }
}

@Test func parseHighSurrogateWithInvalidLow() throws {
  #expect(throws: JSONParseError.invalidUnicodeEscape(line: 1, column: 14)) {
    try JSON.parse("\"\\uD800\\u0041\"")
  }
}

@Test func parseSurrogatePairEmoji() throws {
  let result = try JSON.parse("\"\\uD83D\\uDE06\"")
  #expect(result == JSON.string("😆"))
}

@Test func parseSurrogatePairSkull() throws {
  let result = try JSON.parse("\"\\uD83D\\uDC80\"")
  #expect(result == JSON.string("💀"))
}

// MARK: - Large JSON Performance (smoke test)

@Test func parseLargeArray() throws {
  let count = 10_000
  var elements: [String] = []
  elements.reserveCapacity(count)
  for i in 0..<count {
    elements.append("\(i)")
  }
  let jsonString = "[" + elements.joined(separator: ",") + "]"
  let result = try JSON.parse(jsonString)
  #expect(result.isArray)
  #expect(result.count == count)
}

// MARK: - Standard Encoding Tests

@Test func encodeStandardNull() {
  #expect(JSON.null.dump(indent: -1) == "null")
}

@Test func encodeStandardBool() {
  #expect(JSON.boolean(true).dump(indent: -1) == "true")
}

@Test func encodeStandardInt() {
  #expect(JSON.number(.integer(42)).dump(indent: -1) == "42")
}

@Test func encodeStandardFloat() {
  #expect(JSON.number(.float(3.14)).dump(indent: -1) == "3.14")
}

@Test func encodeStandardString() {
  #expect(JSON.string("hello").dump(indent: -1) == "\"hello\"")
}

@Test func encodeStandardArray() {
  let value = JSON.array([
    JSON.string("a"),
    JSON.number(.integer(1)),
    JSON.boolean(true),
  ])
  #expect(value.dump(indent: -1) == "[\"a\",1,true]")
}

@Test func encodeStandardObject() {
  let value = JSON.object([
    "name": JSON.string("Alice"),
    "age": JSON.number(.integer(30)),
  ])
  #expect(value.dump(indent: -1) == "{\"name\":\"Alice\",\"age\":30}")
}
