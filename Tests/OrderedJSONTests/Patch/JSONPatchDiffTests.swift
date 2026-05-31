import Testing

@testable import OrderedJSON

@Suite("JSONPatch diff tests")
struct JSONPatchDiffTests {
  @Test("diff different types") func diffDifferentTypes() {
    let source = JSON.object(["foo": JSON.string("bar")])
    let target = JSON.array([JSON.string("bar")])
    let patch = JSON.diff(source, target)
    #expect(patch.isArray)
    #expect(patch.count == 1)
    #expect(patch[0]?["op"] == JSON.string("replace"))
  }

  @Test("diff array remove excess") func diffArrayRemoveExcess() {
    let source = JSON.array([
      JSON.number(.integer(1)), JSON.number(.integer(2)), JSON.number(.integer(3)),
    ])
    let target = JSON.array([JSON.number(.integer(1))])
    let patch = JSON.diff(source, target)
    #expect(patch.isArray)
    #expect(patch.count == 2)  // replace index 1, remove index 2? Actually remove trailing
  }

  @Test("diff array recursive objects") func diffArrayRecursiveObjects() {
    let source = JSON.array([
      JSON.object(["a": JSON.string("old")])
    ])
    let target = JSON.array([
      JSON.object(["a": JSON.string("new")])
    ])
    let patch = JSON.diff(source, target)
    // Should produce a recursive diff for the object at index 0
    #expect(patch.isArray)
    #expect(patch.count == 1)
    #expect(patch[0]?["op"] == JSON.string("replace"))
  }

  @Test("diff object recursive") func diffObjectRecursive() {
    let source = JSON.object([
      "a": JSON.object(["b": JSON.string("old")])
    ])
    let target = JSON.object([
      "a": JSON.object(["b": JSON.string("new")])
    ])
    let patch = JSON.diff(source, target)
    // Should produce a recursive diff for the nested object
    #expect(patch.isArray)
    #expect(patch[0]?["op"] == JSON.string("replace"))
  }

  @Test("diff nested array recursive") func diffNestedArrayRecursive() {
    let source = JSON.object([
      "a": JSON.array([JSON.object(["x": JSON.string("old")])])
    ])
    let target = JSON.object([
      "a": JSON.array([JSON.object(["x": JSON.string("new")])])
    ])
    let patch = JSON.diff(source, target)
    #expect(patch.isArray)
  }

  @Test("diff simple replace") func diffSimpleReplace() {
    let source = JSON.object(["foo": JSON.string("bar")])
    let target = JSON.object(["foo": JSON.string("baz")])
    let patch = JSON.diff(source, target)
    let expected = JSON.array([
      JSON.object([
        "op": JSON.string("replace"),
        "path": JSON.string("/foo"),
        "value": JSON.string("baz"),
      ])
    ])
    #expect(patch == expected)
  }

  @Test("diff add key") func diffAddKey() {
    let source = JSON.object(["foo": JSON.string("bar")])
    let target = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.string("qux"),
    ])
    let patch = JSON.diff(source, target)
    let expected = JSON.array([
      JSON.object([
        "op": JSON.string("add"),
        "path": JSON.string("/baz"),
        "value": JSON.string("qux"),
      ])
    ])
    #expect(patch == expected)
  }

  @Test("diff remove key") func diffRemoveKey() {
    let source = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.string("qux"),
    ])
    let target = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.diff(source, target)
    let expected = JSON.array([
      JSON.object([
        "op": JSON.string("remove"),
        "path": JSON.string("/baz"),
      ])
    ])
    #expect(patch == expected)
  }

  @Test("diff array changes") func diffArrayChanges() {
    let source = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    let target = JSON.array([
      JSON.number(.integer(1)), JSON.number(.integer(3)), JSON.number(.integer(4)),
    ])
    let patch = JSON.diff(source, target)
    // First: replace index 1, then add index 2
    #expect(patch.isArray)
    #expect(patch.count == 2)
  }

  @Test("diff no changes") func diffNoChanges() {
    let source = JSON.object(["foo": JSON.string("bar")])
    let target = JSON.object(["foo": JSON.string("bar")])
    let patch = JSON.diff(source, target)
    #expect(patch.isArray)
    #expect(patch.isEmpty)
  }

  @Test("diff round trip") func diffRoundTrip() throws {
    let source = JSON.object([
      "foo": JSON.string("bar"),
      "baz": JSON.number(.integer(42)),
    ])
    let target = JSON.object([
      "foo": JSON.string("bar"),
      "qux": JSON.boolean(true),
    ])
    let patch = JSON.diff(source, target)
    let result = try source.applying(patch)
    #expect(result == target)
  }
}
