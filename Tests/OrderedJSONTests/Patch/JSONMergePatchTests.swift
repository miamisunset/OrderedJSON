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

  // MARK: - Phase 4: Merge Patch Edge Cases

  @Test("null patch on null target returns null") func nullPatchOnNullTarget() {
    let target = JSON.null
    let patch = JSON.null
    let result = target.mergePatch(patch)
    #expect(result.isNull)
  }

  @Test("null patch replaces any value") func nullPatchReplacesAnyValue() {
    let target = JSON.string("hello")
    let patch = JSON.null
    let result = target.mergePatch(patch)
    #expect(result.isNull)
  }

  @Test("non-object scalar patch replaces entire object target") func nonObjectScalarPatchReplaces()
  {
    let target = JSON.object(["key": JSON.string("value")])
    let patch = JSON.number(.integer(42))
    let result = target.mergePatch(patch)
    #expect(result == JSON.number(.integer(42)))
  }

  @Test("non-object boolean patch replaces entire object target") func nonObjectBoolPatchReplaces()
  {
    let target = JSON.object(["key": JSON.string("value")])
    let patch = JSON.boolean(true)
    let result = target.mergePatch(patch)
    #expect(result == JSON.boolean(true))
  }

  @Test("non-object array patch replaces entire object target") func nonObjectArrayPatchReplaces() {
    let target = JSON.object(["key": JSON.string("value")])
    let patch = JSON.array([JSON.string("a"), JSON.string("b")])
    let result = target.mergePatch(patch)
    #expect(result == JSON.array([JSON.string("a"), JSON.string("b")]))
  }

  @Test("target null at key, patch object replaces null") func targetNullKeyPatchObject() {
    let target = JSON.object([
      "a": JSON.null
    ])
    let patch = JSON.object([
      "a": JSON.object([
        "b": JSON.string("c")
      ])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object([
        "b": JSON.string("c")
      ])
    ])
    #expect(result == expected)
  }

  @Test("target object at key, patch null removes key") func targetObjectKeyPatchNull() {
    let target = JSON.object([
      "a": JSON.object([
        "b": JSON.string("c")
      ])
    ])
    let patch = JSON.object([
      "a": JSON.null
    ])
    let result = target.mergePatch(patch)
    #expect(result == JSON.object([:]))
    #expect(result.isObject)
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.isEmpty)
  }

  @Test("target null at key, patch null removes key") func targetNullKeyPatchNull() {
    let target = JSON.object([
      "a": JSON.null
    ])
    let patch = JSON.object([
      "a": JSON.null
    ])
    let result = target.mergePatch(patch)
    #expect(result == JSON.object([:]))
    guard case .object(let dict) = result.storage else { return }
    #expect(dict.isEmpty)
  }

  @Test("target missing key, patch null is no-op") func targetMissingKeyPatchNull() {
    let target = JSON.object([
      "a": JSON.string("value")
    ])
    let patch = JSON.object([
      "nonexistent": JSON.null
    ])
    let result = target.mergePatch(patch)
    #expect(result == target)
  }

  @Test("target non-object at key, patch object overwrites")
  func targetNonObjectKeyPatchObjectOverwrites() {
    let target = JSON.object([
      "a": JSON.string("scalar")
    ])
    let patch = JSON.object([
      "a": JSON.object([
        "b": JSON.number(.integer(1))
      ])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object([
        "b": JSON.number(.integer(1))
      ])
    ])
    #expect(result == expected)
  }

  @Test("target object at key, patch scalar overwrites") func targetObjectKeyPatchScalarOverwrites()
  {
    let target = JSON.object([
      "a": JSON.object([
        "b": JSON.string("c")
      ])
    ])
    let patch = JSON.object([
      "a": JSON.string("replaced")
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.string("replaced")
    ])
    #expect(result == expected)
  }

  @Test("empty target object accepts keys from patch") func emptyTargetObjectAcceptsKeys() {
    let target = JSON.object([:])
    let patch = JSON.object([
      "a": JSON.number(.integer(1)),
      "b": JSON.string("two"),
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.number(.integer(1)),
      "b": JSON.string("two"),
    ])
    #expect(result == expected)
  }

  @Test("multiple null removals in single patch") func multipleNullRemovals() {
    let target = JSON.object([
      "a": JSON.number(.integer(1)),
      "b": JSON.number(.integer(2)),
      "c": JSON.number(.integer(3)),
    ])
    let patch = JSON.object([
      "a": JSON.null,
      "c": JSON.null,
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "b": JSON.number(.integer(2))
    ])
    #expect(result == expected)
  }

  @Test("in-place mutation via mutating mergePatch") func inPlaceMutation() {
    var target = JSON.object([
      "a": JSON.string("old"),
      "b": JSON.string("keep"),
    ])
    let patch = JSON.object([
      "a": JSON.null,
      "b": JSON.string("updated"),
      "c": JSON.number(.integer(3)),
    ])
    target = target.mergePatch(patch)
    let expected = JSON.object([
      "b": JSON.string("updated"),
      "c": JSON.number(.integer(3)),
    ])
    #expect(target == expected)
  }

  @Test("in-place mutation with null patch") func inPlaceNullPatch() {
    var target = JSON.object(["key": JSON.string("value")])
    target = target.mergePatch(JSON.null)
    #expect(target.isNull)
  }

  @Test("in-place mutation with non-object patch") func inPlaceNonObjectPatch() {
    var target = JSON.object(["key": JSON.string("value")])
    target = target.mergePatch(JSON.string("replaced"))
    #expect(target == JSON.string("replaced"))
  }

  @Test("merge patch recursive remove nested key") func recursiveRemoveNestedKey() {
    let target = JSON.object([
      "a": JSON.object([
        "b": JSON.string("c"),
        "d": JSON.string("e"),
      ])
    ])
    let patch = JSON.object([
      "a": JSON.object([
        "b": JSON.null
      ])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object([
        "d": JSON.string("e")
      ])
    ])
    #expect(result == expected)
  }

  @Test("merge patch recursive replace nested object with scalar")
  func recursiveReplaceNestedWithScalar() {
    let target = JSON.object([
      "a": JSON.object([
        "b": JSON.object([
          "c": JSON.string("deep")
        ])
      ])
    ])
    let patch = JSON.object([
      "a": JSON.object([
        "b": JSON.string("flat")
      ])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object([
        "b": JSON.string("flat")
      ])
    ])
    #expect(result == expected)
  }

  @Test("merge patch multiple nested levels of new keys") func multipleNestedNewKeys() {
    let target = JSON.object([
      "a": JSON.object([
        "b": JSON.object([
          "c": JSON.string("deep")
        ])
      ])
    ])
    let patch = JSON.object([
      "a": JSON.object([
        "b": JSON.object([
          "x": JSON.number(.integer(1)),
          "y": JSON.number(.integer(2)),
        ]),
        "z": JSON.string("new"),
      ])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object([
        "b": JSON.object([
          "c": JSON.string("deep"),
          "x": JSON.number(.integer(1)),
          "y": JSON.number(.integer(2)),
        ]),
        "z": JSON.string("new"),
      ])
    ])
    #expect(result == expected)
  }

  @Test("merge patch identity: empty patch returns same object") func emptyPatchIdentity() {
    let target = JSON.object([
      "a": JSON.number(.integer(1)),
      "b": JSON.object([
        "c": JSON.string("d")
      ]),
    ])
    let patch = JSON.object([:])
    let result = target.mergePatch(patch)
    #expect(result == target)
  }

  @Test("merge patch target is array, patch object replaces") func targetArrayPatchObjectReplaces()
  {
    let target = JSON.array([JSON.string("a"), JSON.string("b")])
    let patch = JSON.object(["key": JSON.string("value")])
    let result = target.mergePatch(patch)
    #expect(result == JSON.object(["key": JSON.string("value")]))
  }
}
