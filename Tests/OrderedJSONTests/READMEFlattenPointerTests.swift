import Testing

@testable import OrderedJSON

@Test func readmeFlatten() throws {
  let json = try JSON.parse(
    """
    {"a": "x", "b": {"c": "deep"}, "d": [1, {"e": "nested"}]}
    """)

  let flat = json.flatten()
  #expect(flat["/a"] == JSON.string("x"))
  #expect(flat["/b/c"] == JSON.string("deep"))
  #expect(flat["/d/0"] == JSON.number(.integer(1)))
  #expect(flat["/d/1/e"] == JSON.string("nested"))

  let restored = try flat.unflatten()
  #expect(restored == json)
}

@Test func readmeJSONPointer() throws {
  let json = try JSON.parse(
    """
    {"a": {"b": {"c": 42}}}
    """)

  let ptr = try JSONPointer("/a/b/c")
  #expect(ptr.resolve(json) == JSON.number(.integer(42)))
}

@Test func readmeJSONPointerError() throws {
  // Invalid syntax
  #expect(throws: JSONPointerError.self) { try JSONPointer("foo") }

  // Leading zero
  #expect(throws: JSONPointerError.self) { try JSONPointer("/01") }
  _ = try JSONPointer("/0")  // OK
}

@Test func readmeJSONPointerInit() throws {
  // Standard pointer
  let ptr1 = try JSONPointer("/foo/bar")
  #expect(ptr1.segments == ["foo", "bar"])

  // Root pointer
  let root = try JSONPointer("")
  #expect(root.segments.isEmpty)

  // URI fragment
  let ptr2 = try JSONPointer(fragment: "#/c%25d")
  #expect(ptr2.segments == ["c%d"])

  // Valid single digit
  let ptr4 = try JSONPointer("/0")
  #expect(ptr4.segments == ["0"])

  // Invalid fragment
  #expect(throws: JSONPointerError.self) { try JSONPointer(fragment: "/foo") }
}

@Test func readmeJSONPointerResolution() throws {
  let json = try JSON.parse(
    """
    {"a": {"b": [1, 2, 3]}}
    """)

  let ptr = try JSONPointer("/a/b/2")
  #expect(ptr.resolve(json) == JSON.number(.integer(3)))

  // Missing key returns nil
  let missing = try JSONPointer("/x")
  #expect(missing.resolve(json) == nil)

  // "-" token returns nil
  let dash = try JSONPointer("/-/")
  #expect(dash.resolve(json) == nil)

  // Throwing resolution
  let value = try ptr.resolveOrThrow(json)
  #expect(value == JSON.number(.integer(3)))
}

@Test func readmeJSONPointerSet() throws {
  var json = JSON.object(["a": JSON.number(.integer(1))])

  let ptr = try JSONPointer("/b/c")
  ptr.set(value: JSON.string("deep"), into: &json)
  #expect(json["b"]?["c"] == JSON.string("deep"))

  // Root pointer replaces entire value
  let root = try JSONPointer("")
  root.set(value: JSON.number(.integer(42)), into: &json)
  #expect(json == JSON.number(.integer(42)))

  // "-" token appends to array
  var arr = JSON.array([JSON.string("a")])
  let append = try JSONPointer("/-")
  append.set(value: JSON.string("b"), into: &arr)
  #expect(arr.count == 2)
  #expect(arr.last == JSON.string("b"))

  // "-" on non-array creates one
  var obj = JSON.object([:])
  let force = try JSONPointer("/-")
  force.set(value: JSON.string("first"), into: &obj)
  #expect(obj.isArray)
  #expect(obj.first == JSON.string("first"))
}

@Test func readmeJSONPointerDescription() throws {
  let ptr = try JSONPointer("/a~1b/m~0n")
  #expect(ptr.description == "/a~1b/m~0n")

  let root = try JSONPointer("")
  #expect(root.description == "")

  let roundtrip = try JSONPointer(ptr.description)
  #expect(roundtrip.segments == ptr.segments)
}
