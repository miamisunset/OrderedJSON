import Testing

@testable import OrderedJSON

@Suite("Integer Width Tests") struct JSONIntegerWidthTests {
  @Test("require int8 value success") func requireInt8ValueSuccess() throws {
    let json = JSON.number(.integer(42))
    #expect(try json.requireInt8() == 42)
  }

  @Test("require int8 value overflow") func requireInt8ValueOverflow() throws {
    let json = JSON.number(.integer(200))
    let error = #expect(throws: JSONError.self) {
      try json.requireInt8()
    }
    #expect(error == JSONError.typeError(expected: "int8", actual: "number"))
  }

  @Test("require int16 value success") func requireInt16ValueSuccess() throws {
    let json = JSON.number(.integer(300))
    #expect(try json.requireInt16() == 300)
  }

  @Test("require int32 value success") func requireInt32ValueSuccess() throws {
    let json = JSON.number(.integer(100_000))
    #expect(try json.requireInt32() == 100_000)
  }

  @Test("require uint value success") func requireUIntValueSuccess() throws {
    let json = JSON.number(.integer(42))
    #expect(try json.requireUInt() == 42)
  }

  @Test("require uint value negative throws") func requireUIntValueNegativeThrows() throws {
    let json = JSON.number(.integer(-1))
    let error = #expect(throws: JSONError.self) {
      try json.requireUInt()
    }
    #expect(error == JSONError.typeError(expected: "uint", actual: "number"))
  }

  @Test("require uint8 value success") func requireUInt8ValueSuccess() throws {
    let json = JSON.number(.integer(255))
    #expect(try json.requireUInt8() == 255)
  }

  @Test("require uint8 value overflow") func requireUInt8ValueOverflow() throws {
    let json = JSON.number(.integer(256))
    let error = #expect(throws: JSONError.self) {
      try json.requireUInt8()
    }
    #expect(error == JSONError.typeError(expected: "uint8", actual: "number"))
  }

  @Test("require uint16 value success") func requireUInt16ValueSuccess() throws {
    let json = JSON.number(.integer(42000))
    #expect(try json.requireUInt16() == 42000)
  }

  @Test("require uint32 value success") func requireUInt32ValueSuccess() throws {
    let json = JSON.number(.integer(2_000_000_000))
    #expect(try json.requireUInt32() == 2_000_000_000)
  }

  @Test("require uint64 value success") func requireUInt64ValueSuccess() throws {
    let json = JSON.number(.integer(42))
    #expect(try json.requireUInt64() == 42)
  }

  @Test("require uint64 value negative throws") func requireUInt64ValueNegativeThrows() throws {
    let json = JSON.number(.integer(-1))
    let error = #expect(throws: JSONError.self) {
      try json.requireUInt64()
    }
    #expect(error == JSONError.typeError(expected: "uint64", actual: "number"))
  }

  @Test("double value from integer") func doubleValueFromInteger() throws {
    let json = JSON.number(.integer(42))
    #expect(try json.requireDouble() == 42.0)
  }

  @Test("double value from float") func doubleValueFromFloat() throws {
    let json = JSON.number(.float(3.14))
    #expect(try json.requireDouble() == 3.14)
  }

  @Test("double value throws on non number") func doubleValueThrowsOnNonNumber() throws {
    let json = JSON.string("hello")
    let error = #expect(throws: JSONError.self) {
      try json.requireDouble()
    }
    #expect(error == JSONError.typeError(expected: "float", actual: "string"))
  }

  @Test("require float value rejects lossy double") func requireFloatValueRejectsLossyDouble()
    throws
  {
    // 0.1 is not exactly representable as Float
    let json = JSON.number(.float(0.1))
    let error = #expect(throws: JSONError.self) {
      try json.requireFloat()
    }
    #expect(error == JSONError.typeError(expected: "float", actual: "double"))
  }

  @Test("require float value from integer") func requireFloatValueFromInteger() throws {
    // Clean integers are exactly representable as Float
    let json = JSON.number(.integer(42))
    #expect(try json.requireFloat() == 42.0)
  }

  @Test("require int64 value from float") func requireInt64ValueFromFloat() throws {
    // Clean integer stored as .float should still work with int64Value
    let json = JSON.number(.float(42.0))
    #expect(try json.requireInt64() == 42)
  }

  @Test("require int64 value from float throws") func requireInt64ValueFromFloatThrows() throws {
    // Fractional float should throw
    let json = JSON.number(.float(3.14))
    let error = #expect(throws: JSONError.self) {
      try json.requireInt64()
    }
    #expect(error == JSONError.typeError(expected: "integer", actual: "number"))
  }
}
