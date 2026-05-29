import Testing

@testable import OrderedJSON

// MARK: - JSON Merge Patch (RFC 7396) Tests

@Suite("JSON merge patch tests")
struct JSONMergePatchTests {

@Test("merge patch replace scalar") func mergePatchReplaceScalar() {
  let target = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.object(["foo": JSON.string("baz")])
  let result = target.mergePatch(patch)
  let expected = JSON.object(["foo": JSON.string("baz")])
  #expect(result == expected)
}

@Test("merge patch add key") func mergePatchAddKey() {
  let target = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.object(["baz": JSON.string("qux")])
  let result = target.mergePatch(patch)
  let expected = JSON.object([
    "foo": JSON.string("bar"),
    "baz": JSON.string("qux"),
  ])
  #expect(result == expected)
}

@Test("merge patch remove key") func mergePatchRemoveKey() {
  let target = JSON.object([
    "foo": JSON.string("bar"),
    "baz": JSON.string("qux"),
  ])
  let patch = JSON.object(["baz": JSON.null])
  let result = target.mergePatch(patch)
  let expected = JSON.object(["foo": JSON.string("bar")])
  #expect(result == expected)
}

@Test("merge patch recursive") func mergePatchRecursive() {
  let target = JSON.object([
    "a": JSON.object([
      "b": JSON.string("c")
    ])
  ])
  let patch = JSON.object([
    "a": JSON.object([
      "d": JSON.string("e")
    ])
  ])
  let result = target.mergePatch(patch)
  let expected = JSON.object([
    "a": JSON.object([
      "b": JSON.string("c"),
      "d": JSON.string("e"),
    ])
  ])
  #expect(result == expected)
}

@Test("merge patch recursive replace") func mergePatchRecursiveReplace() {
  let target = JSON.object([
    "a": JSON.object([
      "b": JSON.string("c")
    ])
  ])
  let patch = JSON.object([
    "a": JSON.object([
      "b": JSON.string("x")
    ])
  ])
  let result = target.mergePatch(patch)
  let expected = JSON.object([
    "a": JSON.object([
      "b": JSON.string("x")
    ])
  ])
  #expect(result == expected)
}

@Test("merge patch null target") func mergePatchNullTarget() {
  let target = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.null
  let result = target.mergePatch(patch)
  #expect(result.isNull)
}

@Test("merge patch replaces non object") func mergePatchReplacesNonObject() {
  let target = JSON.string("original")
  let patch = JSON.object(["foo": JSON.string("bar")])
  let result = target.mergePatch(patch)
  // Non-object target gets replaced by the patch object
  let expected = JSON.object(["foo": JSON.string("bar")])
  #expect(result == expected)
}

@Test("merge patch scalar replaces object") func mergePatchScalarReplacesObject() {
  let target = JSON.object(["foo": JSON.string("bar")])
  let patch = JSON.string("scalar")
  let result = target.mergePatch(patch)
  #expect(result == JSON.string("scalar"))
}

@Test("merge patch no changes") func mergePatchNoChanges() {
  let target = JSON.object([
    "foo": JSON.string("bar"),
    "baz": JSON.number(.integer(42)),
  ])
  let patch = JSON.object([:])
  let result = target.mergePatch(patch)
  #expect(result == target)
}

@Test("merge patch adds and removes") func mergePatchAddsAndRemoves() {
  let target = JSON.object([
    "a": JSON.string("1"),
    "b": JSON.string("2"),
  ])
  let patch = JSON.object([
    "a": JSON.null,
    "c": JSON.string("3"),
  ])
  let result = target.mergePatch(patch)
  let expected = JSON.object([
    "b": JSON.string("2"),
    "c": JSON.string("3"),
  ])
  #expect(result == expected)
}

@Test("merge patch deeply nested") func mergePatchDeeplyNested() {
  let target = JSON.object([
    "level1": JSON.object([
      "level2": JSON.object([
        "level3": JSON.string("old")
      ])
    ])
  ])
  let patch = JSON.object([
    "level1": JSON.object([
      "level2": JSON.object([
        "level3": JSON.string("new"),
        "extra": JSON.boolean(true),
      ])
    ])
  ])
  let result = target.mergePatch(patch)
  let expected = JSON.object([
    "level1": JSON.object([
      "level2": JSON.object([
        "level3": JSON.string("new"),
        "extra": JSON.boolean(true),
      ])
    ])
  ])
  #expect(result == expected)
}
}
