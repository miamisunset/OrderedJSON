import Testing

@testable import OrderedJSON

@Test func readmeQuickStart() throws {
  let json = """
    {"z": 1, "a": 2, "m": 3}
    """
  let value = try JSON.parse(json)

  #expect(value.count == 3)
  #expect(value["z"] == JSON.number(.integer(1)))

  let output = value.dump()
  #expect(output == "{\"z\":1,\"a\":2,\"m\":3}")
}
