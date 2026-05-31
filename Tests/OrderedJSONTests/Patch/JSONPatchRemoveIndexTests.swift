import Testing

@testable import OrderedJSON

@Suite("JSONPatch remove index shift tests")
struct JSONPatchRemoveIndexTests {
  @Test("multiple removes on same array") func multipleRemovesSameArray() throws {
    let json = JSON.array([
      .string("a"), .string("b"), .string("c"), .string("d"),
    ])
    let patch = JSON.array([
      JSON.object(["op": .string("remove"), "path": .string("/0")]),
      JSON.object(["op": .string("remove"), "path": .string("/1")]),
    ])
    let result = try json.applying(patch)
    // First remove /0: ["b", "c", "d"]
    // Second remove /1: ["b", "d"]  (index 1 is now "c", so remove "c")
    let expected = JSON.array([.string("b"), .string("d")])
    #expect(result == expected)
  }

  @Test("multiple removes on same array (reverse order)") func multipleRemovesReverseOrder() throws
  {
    let json = JSON.array([
      .string("a"), .string("b"), .string("c"), .string("d"),
    ])
    let patch = JSON.array([
      JSON.object(["op": .string("remove"), "path": .string("/2")]),
      JSON.object(["op": .string("remove"), "path": .string("/1")]),
    ])
    let result = try json.applying(patch)
    // First remove /2: ["a", "b", "d"]
    // Second remove /1: ["a", "d"]  (index 1 is "b", so remove "b")
    let expected = JSON.array([.string("a"), .string("d")])
    #expect(result == expected)
  }

  @Test("multiple adds on same array") func multipleAddsSameArray() throws {
    let json = JSON.array([.string("a"), .string("b")])
    let patch = JSON.array([
      JSON.object([
        "op": .string("add"),
        "path": .string("/0"),
        "value": .string("x"),
      ]),
      JSON.object([
        "op": .string("add"),
        "path": .string("/2"),
        "value": .string("y"),
      ]),
    ])
    let result = try json.applying(patch)
    // First add at /0: ["x", "a", "b"]
    // Second add at /2: ["x", "a", "y", "b"]
    let expected = JSON.array([.string("x"), .string("a"), .string("y"), .string("b")])
    #expect(result == expected)
  }

  @Test("mixed add and remove on same array") func mixedAddRemoveSameArray() throws {
    let json = JSON.array([.string("a"), .string("b"), .string("c")])
    let patch = JSON.array([
      JSON.object(["op": .string("remove"), "path": .string("/0")]),
      JSON.object([
        "op": .string("add"),
        "path": .string("/1"),
        "value": .string("x"),
      ]),
    ])
    let result = try json.applying(patch)
    // First remove /0: ["b", "c"]
    // Second add at /1: ["b", "x", "c"]
    let expected = JSON.array([.string("b"), .string("x"), .string("c")])
    #expect(result == expected)
  }
}
