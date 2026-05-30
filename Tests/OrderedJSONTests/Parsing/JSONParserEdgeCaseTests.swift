import Foundation
import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Phase 1: Parser Edge Case Tests

/// Covers all edge cases from the Phase 1 bug hunt checklist:
///   1. Surrogate pair handling (parser + SAX)
///   2. Trailing comma logic
///   3. Number parsing edge cases
///   4. String parsing edge cases
///   5. Depth limit verification
///   6. SAX accept mode
///   7. Trailing data after valid JSON
@Suite("Parser Edge Case Tests (Phase 1)")
struct JSONParserEdgeCaseTests {

  // MARK: - 1. Surrogate Pair Handling

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

  // MARK: - SAX Surrogate Pair Consistency

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

  // MARK: - 2. Trailing Comma Logic

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

  // MARK: - 3. Number Parsing Edge Cases

  @Test("leading zero integer rejected")
  func leadingZeroIntegerRejected() {
    // 01 — parser consumes both digits, then throws invalidNumber at col 3
    #expect(throws: JSONParseError.invalidNumber(line: 1, column: 3)) {
      try JSON.parse("01")
    }
  }

  @Test("leading zero float rejected")
  func leadingZeroFloatRejected() {
    // 00.5 — parser consumes leading zeros, then throws invalidNumber at col 3
    #expect(throws: JSONParseError.invalidNumber(line: 1, column: 3)) {
      try JSON.parse("00.5")
    }
  }

  @Test("negative leading zero rejected")
  func negativeLeadingZeroRejected() {
    // -01 — parser consumes -,0,1, then throws invalidNumber at col 4
    #expect(throws: JSONParseError.invalidNumber(line: 1, column: 4)) {
      try JSON.parse("-01")
    }
  }

  @Test("negative zero parses as integer 0")
  func negativeZeroParsesAsIntegerZero() throws {
    let result = try JSON.parse("-0")
    #expect(result == JSON.number(.integer(0)))
  }

  @Test("bare dot rejected")
  func bareDotRejected() {
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) {
      try JSON.parse(".")
    }
  }

  @Test("bare e rejected")
  func bareERejected() {
    #expect(throws: JSONParseError.unexpectedToken(line: 1, column: 1)) {
      try JSON.parse("e")
    }
  }

  @Test("minus dot e rejected")
  func minusDotERejected() {
    #expect(throws: JSONParseError.unexpectedEnd()) {
      try JSON.parse("-.e1")
    }
  }

  @Test("minus alone rejected")
  func minusAloneRejected() {
    #expect(throws: JSONParseError.invalidNumber(line: 1, column: 2)) {
      try JSON.parse("-")
    }
  }

  @Test("number just after decimal point rejected")
  func justDecimalPointRejected() {
    #expect(throws: JSONParseError.unexpectedEnd()) {
      try JSON.parse("0.")
    }
  }

  @Test("number with just exponent rejected")
  func justExponentRejected() {
    #expect(throws: JSONParseError.unexpectedEnd()) {
      try JSON.parse("1.e")
    }
  }

  @Test("number with plus-only exponent rejected")
  func plusOnlyExponentRejected() {
    #expect(throws: JSONParseError.unexpectedEnd()) {
      try JSON.parse("1.0e+")
    }
  }

  @Test("number with minus-only exponent rejected")
  func minusOnlyExponentRejected() {
    #expect(throws: JSONParseError.unexpectedEnd()) {
      try JSON.parse("1.0e-")
    }
  }

  @Test("number beyond Int64.max stored as float")
  func beyondInt64MaxStoredAsFloat() throws {
    let result = try JSON.parse("9223372036854775808")
    #expect(result.isFloat)
  }

  @Test("number below Int64.min stored as float")
  func belowInt64MinStoredAsFloat() throws {
    let result = try JSON.parse("-9223372036854775809")
    #expect(result.isFloat)
  }

  @Test("0.0 is float, not integer")
  func zeroPointZeroIsFloat() throws {
    let result = try JSON.parse("0.0")
    #expect(result.isFloat)
    #expect(result == JSON.number(.float(0.0)))
  }

  // MARK: - 4. String Parsing Edge Cases

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

  // MARK: - 5. Depth Limit Verification

  @Test("depth at limit parses correctly")
  func depthAtLimitParsesCorrectly() throws {
    let opts = JSON.ParserOptions(maxDepth: 3)
    let result = try JSON.parse("{\"a\": {\"b\": {\"c\": 1}}}", options: opts)
    #expect(result["a"]?["b"]?["c"] == JSON.number(.integer(1)))
  }

  @Test("depth one over limit rejected")
  func depthOneOverLimitRejected() {
    let opts = JSON.ParserOptions(maxDepth: 3)
    // {"a": {"b": {"c": {"d": 1}}}} — 4 levels of nesting (depth exceeds 3)
    // Error at column where the 4th '{' is parsed
    #expect(throws: JSONParseError.depthExceeded(line: 1, column: 20, depth: 4, maxDepth: 3)) {
      try JSON.parse("{\"a\": {\"b\": {\"c\": {\"d\": 1}}}}", options: opts)
    }
  }

  @Test("depth two over limit rejected")
  func depthTwoOverLimitRejected() {
    let opts = JSON.ParserOptions(maxDepth: 3)
    #expect(throws: JSONParseError.depthExceeded(line: 1, column: 20, depth: 4, maxDepth: 3)) {
      try JSON.parse("{\"a\": {\"b\": {\"c\": {\"d\": {\"e\": 1}}}}}", options: opts)
    }
  }

  @Test("array depth at limit")
  func arrayDepthAtLimit() throws {
    let opts = JSON.ParserOptions(maxDepth: 3)
    let result = try JSON.parse("[[[1]]]", options: opts)
    #expect(result.isArray)
    #expect(result[0]?[0]?[0] == JSON.number(.integer(1)))
  }

  @Test("array depth over limit rejected")
  func arrayDepthOverLimitRejected() {
    let opts = JSON.ParserOptions(maxDepth: 3)
    // [[[[1]]]] — 4 levels of array nesting (depth exceeds 3)
    // Error at column 5: after 4th '[', depth=4 > maxDepth=3
    #expect(throws: JSONParseError.depthExceeded(line: 1, column: 5, depth: 4, maxDepth: 3)) {
      try JSON.parse("[[[[1]]]]", options: opts)
    }
  }

  @Test("depth limit with mixed arrays and objects")
  func depthLimitMixed() throws {
    let opts = JSON.ParserOptions(maxDepth: 4)
    let result = try JSON.parse("[{\"a\": [[1]]}]", options: opts)
    #expect(result[0]?["a"]?[0]?[0] == JSON.number(.integer(1)))
  }

  // MARK: - 6. SAX Accept Mode

  @Test("accept rejects lone minus")
  func acceptRejectsLoneMinus() {
    #expect(JSON.accept("-") == false)
  }

  @Test("accept rejects leading zero")
  func acceptRejectsLeadingZero() {
    #expect(JSON.accept("01") == false)
  }

  @Test("accept accepts valid values")
  func acceptAcceptsValidValues() {
    #expect(JSON.accept("null"))
    #expect(JSON.accept("true"))
    #expect(JSON.accept("42"))
    #expect(JSON.accept("\"hi\""))
    #expect(JSON.accept("{}"))
    #expect(JSON.accept("[]"))
    #expect(JSON.accept(#"{"k":"v"}"#))
    #expect(JSON.accept("[1,2]"))
  }

  @Test("accept rejects invalid values")
  func acceptRejectsInvalidValues() {
    #expect(JSON.accept("") == false)
    #expect(JSON.accept("invalid") == false)
    #expect(JSON.accept("{") == false)
    #expect(JSON.accept("[") == false)
    #expect(JSON.accept("}") == false)
    #expect(JSON.accept("]") == false)
  }

  @Test("accept rejects incomplete number")
  func acceptRejectsIncompleteNumber() {
    #expect(JSON.accept("-") == false)
    #expect(JSON.accept("0.") == false)
    #expect(JSON.accept("1.e") == false)
    #expect(JSON.accept("1.0e+") == false)
  }

  // MARK: - 7. Trailing Data After Valid JSON

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
