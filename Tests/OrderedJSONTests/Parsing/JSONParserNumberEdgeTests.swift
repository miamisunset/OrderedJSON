import Testing

@testable import OrderedJSON

@Suite("Parser number edge case tests")
struct JSONParserNumberEdgeTests {
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
}
