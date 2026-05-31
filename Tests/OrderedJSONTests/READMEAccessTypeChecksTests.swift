import Testing

@testable import OrderedJSON

@Test func readmeTypeChecks() throws {
  let json = try JSON.parse("{\"x\": 1, \"y\": [2], \"z\": null}")

  let x = try #require(json["x"])
  #expect(x.isNull == false)
  #expect(x.isBoolean == false)
  #expect(x.isNumber)
  #expect(x.isInteger)
  #expect(x.isFloat == false)
  #expect(x.isString == false)
  #expect(x.isObject == false)
  #expect(x.isArray == false)
  #expect(x.isPrimitive)
  #expect(x.isStructured == false)

  #expect(x.type == JSON.JSONType.number)
  #expect(x.typeName == "number")
}
