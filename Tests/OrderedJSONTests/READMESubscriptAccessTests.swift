import Testing

@testable import OrderedJSON

@Test func readmeSubscriptAccess() throws {
  let json = try JSON.parse(
    """
    {"name": "Alice", "items": [10, 20]}
    """)

  // Key subscript
  #expect(json["name"] == JSON.string("Alice"))
  #expect(json["missing"] == nil)

  // Index subscript on array
  #expect(json["items"]?[0] == JSON.number(.integer(10)))

  // Key subscript set
  var mutable = json
  mutable["name"] = JSON.string("Bob")
  #expect(mutable["name"] == JSON.string("Bob"))

  // Index subscript set
  mutable["items"]?[0] = JSON.number(.integer(99))
  #expect(mutable["items"]?[0] == JSON.number(.integer(99)))

  // Throwing access
  #expect(throws: JSONError.self) { try json.at(key: "missing") }
  let name = try json.at(key: "name")
  #expect(name == JSON.string("Alice"))

  // Value with default
  #expect(json.value(forKey: "name", default: JSON.null) == JSON.string("Alice"))
  #expect(json.value(forKey: "missing", default: JSON("x")) == JSON.string("x"))

  // Array value with default
  let arr = JSON.array([.string("a"), .number(.integer(1))])
  #expect(arr.value(at: 0, default: JSON.null) == JSON.string("a"))
  #expect(arr.value(at: 99, default: JSON("x")) == JSON.string("x"))
}
