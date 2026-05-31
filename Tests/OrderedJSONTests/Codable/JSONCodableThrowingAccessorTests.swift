import Testing

@testable import OrderedJSON

@Suite("Codable Throwing Accessor Tests") struct JSONCodableThrowingAccessorTests {
  @Test("string value success") func stringValueSuccess() throws {
    let json = JSON.string("hello")
    #expect(try json.requireString() == "hello")
  }

  @Test("string value throws") func stringValueThrows() {
    let json = JSON.number(.integer(42))
    let error = #expect(throws: JSONError.self) {
      try json.requireString()
    }
    #expect(error == JSONError.typeError(expected: "string", actual: "number"))
  }

  @Test("bool value success") func boolValueSuccess() throws {
    let json = JSON.boolean(true)
    #expect(try json.requireBool() == true)
  }

  @Test("require int64 value success") func requireInt64ValueSuccess() throws {
    let json = JSON.number(.integer(42))
    #expect(try json.requireInt64() == 42)
  }

  @Test("double value success") func doubleValueSuccess() throws {
    let json = JSON.number(.float(3.14))
    #expect(try json.requireDouble() == 3.14)
  }
}
