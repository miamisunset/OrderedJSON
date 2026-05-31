import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - JSON Merge Patch (RFC 7396) Edge Case Tests

@Suite("JSON merge patch edge case tests")
struct JSONMergePatchEdgeCaseTests {

  // MARK: - Bug: Recursive merge on non-object target values

  @Test("target null at key, patch object with null inside replaces (not recursive merge)")
  func targetNullKeyPatchObjectWithNullInside() {
    // Bug: when target has null and patch has an object, the code recursively merges
    // instead of replacing. With {"b": null} in the patch, recursive merge removes "b"
    // from an empty dict → {}, but RFC says non-object target should be replaced → {"b": null}
    let target = JSON.object(["a": JSON.null])
    let patch = JSON.object([
      "a": JSON.object(["b": JSON.null])
    ])
    let result = target.mergePatch(patch)
    // Per RFC 7396: target's value for "a" is null (not an object), so the patch
    // object should REPLACE it. Result should be {"a": {"b": null}}
    let expected = JSON.object([
      "a": JSON.object(["b": JSON.null])
    ])
    #expect(result == expected)
  }

  @Test("target string at key, patch object with null inside replaces (not recursive merge)")
  func targetStringKeyPatchObjectWithNullInside() {
    let target = JSON.object(["a": JSON.string("hello")])
    let patch = JSON.object([
      "a": JSON.object(["b": JSON.null])
    ])
    let result = target.mergePatch(patch)
    // Per RFC: target's "a" is a string (not object), so patch object replaces it
    let expected = JSON.object([
      "a": JSON.object(["b": JSON.null])
    ])
    #expect(result == expected)
  }

  @Test("target number at key, patch object replaces")
  func targetNumberKeyPatchObject() {
    let target = JSON.object(["a": JSON.number(.integer(42))])
    let patch = JSON.object([
      "a": JSON.object(["b": JSON.string("new")])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object(["b": JSON.string("new")])
    ])
    #expect(result == expected)
  }

  @Test("target boolean at key, patch object replaces")
  func targetBoolKeyPatchObject() {
    let target = JSON.object(["a": JSON.boolean(true)])
    let patch = JSON.object([
      "a": JSON.object(["b": JSON.boolean(false)])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object(["b": JSON.boolean(false)])
    ])
    #expect(result == expected)
  }

  @Test("target array at key, patch object replaces")
  func targetArrayKeyPatchObject() {
    let target = JSON.object([
      "a": JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    ])
    let patch = JSON.object([
      "a": JSON.object(["b": JSON.string("replaced")])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object(["b": JSON.string("replaced")])
    ])
    #expect(result == expected)
  }

  // MARK: - Recursive merge only when both are objects

  @Test("target object at key, patch object merges recursively (null removes key)")
  func targetObjectKeyPatchObjectMergesRecursively() {
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

  @Test("target object at key, patch object merges recursively (adds new key)")
  func targetObjectKeyPatchObjectAddsKey() {
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

  // MARK: - Null patch edge cases

  @Test("null patch on null target returns null")
  func nullPatchOnNullTarget() {
    #expect(JSON.null.mergePatch(JSON.null).isNull)
  }

  @Test("null patch on object returns null")
  func nullPatchOnObject() {
    let target = JSON.object(["key": JSON.string("value")])
    #expect(target.mergePatch(JSON.null).isNull)
  }

  @Test("null patch on array returns null")
  func nullPatchOnArray() {
    let target = JSON.array([JSON.number(.integer(1))])
    #expect(target.mergePatch(JSON.null).isNull)
  }

  @Test("null patch on string returns null")
  func nullPatchOnString() {
    #expect(JSON.string("hello").mergePatch(JSON.null).isNull)
  }

  @Test("null patch on number returns null")
  func nullPatchOnNumber() {
    #expect(JSON.number(.integer(42)).mergePatch(JSON.null).isNull)
  }

  @Test("null patch on boolean returns null")
  func nullPatchOnBool() {
    #expect(JSON.boolean(true).mergePatch(JSON.null).isNull)
  }

  // MARK: - Non-object patch replaces entire target

  @Test("string patch replaces object target")
  func stringPatchReplacesObject() {
    let target = JSON.object(["a": JSON.string("old")])
    let result = target.mergePatch(JSON.string("replacement"))
    #expect(result == JSON.string("replacement"))
  }

  @Test("number patch replaces object target")
  func numberPatchReplacesObject() {
    let target = JSON.object(["a": JSON.string("old")])
    let result = target.mergePatch(JSON.number(.integer(99)))
    #expect(result == JSON.number(.integer(99)))
  }

  @Test("boolean patch replaces object target")
  func boolPatchReplacesObject() {
    let target = JSON.object(["a": JSON.string("old")])
    let result = target.mergePatch(JSON.boolean(false))
    #expect(result == JSON.boolean(false))
  }

  @Test("array patch replaces object target")
  func arrayPatchReplacesObject() {
    let target = JSON.object(["a": JSON.string("old")])
    let patch = JSON.array([JSON.string("x"), JSON.string("y")])
    let result = target.mergePatch(patch)
    #expect(result == JSON.array([JSON.string("x"), JSON.string("y")]))
  }

  @Test("string patch replaces array target")
  func stringPatchReplacesArray() {
    let target = JSON.array([JSON.number(.integer(1))])
    let result = target.mergePatch(JSON.string("replacement"))
    #expect(result == JSON.string("replacement"))
  }

  @Test("string patch replaces null target")
  func stringPatchReplacesNull() {
    let result = JSON.null.mergePatch(JSON.string("replacement"))
    #expect(result == JSON.string("replacement"))
  }

  // MARK: - Recursive merge edge cases

  @Test("deeply nested merge with multiple null removals")
  func deeplyNestedMergeWithNullRemovals() {
    let target = JSON.object([
      "level1": JSON.object([
        "level2": JSON.object([
          "a": JSON.string("keep"),
          "b": JSON.string("remove"),
          "c": JSON.string("also-keep"),
        ])
      ])
    ])
    let patch = JSON.object([
      "level1": JSON.object([
        "level2": JSON.object([
          "b": JSON.null,
          "d": JSON.string("added"),
        ])
      ])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "level1": JSON.object([
        "level2": JSON.object([
          "a": JSON.string("keep"),
          "c": JSON.string("also-keep"),
          "d": JSON.string("added"),
        ])
      ])
    ])
    #expect(result == expected)
  }

  @Test("merge patch with empty object in patch value")
  func emptyObjectInPatchValue() {
    let target = JSON.object([
      "a": JSON.object([
        "b": JSON.string("c")
      ])
    ])
    let patch = JSON.object([
      "a": JSON.object([:])  // empty object patch → should be a no-op on the nested object
    ])
    let result = target.mergePatch(patch)
    #expect(result == target)
  }

  @Test("merge patch with empty object replacing non-object target")
  func emptyObjectReplacesNonObject() {
    let target = JSON.object([
      "a": JSON.string("scalar")
    ])
    let patch = JSON.object([
      "a": JSON.object([:])  // empty object replaces the string
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object([:])
    ])
    #expect(result == expected)
  }

  @Test("merge patch where target key is missing, patch object adds")
  func missingKeyPatchObjectAdds() {
    let target = JSON.object([
      "existing": JSON.string("value")
    ])
    let patch = JSON.object([
      "new": JSON.object([
        "nested": JSON.string("added")
      ])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "existing": JSON.string("value"),
      "new": JSON.object([
        "nested": JSON.string("added")
      ]),
    ])
    #expect(result == expected)
  }

  @Test("merge patch removes all keys leaving empty object")
  func removeAllKeysLeavesEmptyObject() {
    let target = JSON.object([
      "a": JSON.string("x"),
      "b": JSON.string("y"),
    ])
    let patch = JSON.object([
      "a": JSON.null,
      "b": JSON.null,
    ])
    let result = target.mergePatch(patch)
    #expect(result == JSON.object([:]))
    #expect(result.isObject)
  }

  @Test("merge patch on empty target adds keys")
  func emptyTargetAddsKeys() {
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

  // MARK: - In-place mutation edge cases

  @Test("in-place mutation on null target")
  func inPlaceNullTarget() {
    var target = JSON.null
    target = target.mergePatch(JSON.object(["a": JSON.string("added")]))
    #expect(target == JSON.object(["a": JSON.string("added")]))
  }

  @Test("in-place mutation chain: apply patch then another patch")
  func inPlaceMutationChain() {
    var target = JSON.object([
      "a": JSON.string("original")
    ])
    // First patch: add key "b"
    target = target.mergePatch(
      JSON.object([
        "b": JSON.number(.integer(2))
      ]))
    #expect(
      target
        == JSON.object([
          "a": JSON.string("original"),
          "b": JSON.number(.integer(2)),
        ]))

    // Second patch: remove "a", update "b"
    target = target.mergePatch(
      JSON.object([
        "a": JSON.null,
        "b": JSON.string("updated"),
      ]))
    #expect(
      target
        == JSON.object([
          "b": JSON.string("updated")
        ]))
  }

  @Test("in-place mutation with recursive merge")
  func inPlaceRecursiveMerge() {
    var target = JSON.object([
      "nested": JSON.object([
        "x": JSON.number(.integer(1))
      ])
    ])
    target = target.mergePatch(
      JSON.object([
        "nested": JSON.object([
          "y": JSON.number(.integer(2))
        ])
      ]))
    let expected = JSON.object([
      "nested": JSON.object([
        "x": JSON.number(.integer(1)),
        "y": JSON.number(.integer(2)),
      ])
    ])
    #expect(target == expected)
  }

  // MARK: - Round-trip tests

  @Test("apply then reverse patch restores original (simple)")
  func applyThenReversePatch() {
    let original = JSON.object([
      "a": JSON.string("original"),
      "b": JSON.string("keep"),
    ])
    // Apply a forward patch
    let forward = JSON.object([
      "a": JSON.string("updated"),
      "c": JSON.number(.integer(3)),
    ])
    let patched = original.mergePatch(forward)

    // Apply a reverse patch to restore original
    let reverse = JSON.object([
      "a": JSON.string("original"),
      "c": JSON.null,
    ])
    let restored = patched.mergePatch(reverse)
    #expect(restored == original)
  }

  @Test("apply then reverse patch restores original (with recursive merge)")
  func applyThenReversePatchRecursive() {
    let original = JSON.object([
      "config": JSON.object([
        "theme": JSON.string("dark"),
        "fontSize": JSON.number(.integer(14)),
      ]),
      "version": JSON.string("1.0"),
    ])
    // Forward patch: change theme, add language
    let forward = JSON.object([
      "config": JSON.object([
        "theme": JSON.string("light"),
        "language": JSON.string("en"),
      ])
    ])
    let patched = original.mergePatch(forward)

    // Reverse patch
    let reverse = JSON.object([
      "config": JSON.object([
        "theme": JSON.string("dark"),
        "language": JSON.null,
      ])
    ])
    let restored = patched.mergePatch(reverse)
    #expect(restored == original)
  }

  // MARK: - Large/deep patch edge cases

  @Test("merge patch with many keys")
  func manyKeysPatch() {
    var targetDict = OrderedDictionary<String, JSON>()
    var patchDict = OrderedDictionary<String, JSON>()
    for i in 0..<100 {
      targetDict["key_\(i)"] = JSON.number(.integer(Int64(i)))
      patchDict["key_\(i)"] = JSON.number(.integer(Int64(i * 2)))
    }
    let target = JSON.object(targetDict)
    let patch = JSON.object(patchDict)
    let result = target.mergePatch(patch)
    var expectedDict = OrderedDictionary<String, JSON>()
    for i in 0..<100 {
      expectedDict["key_\(i)"] = JSON.number(.integer(Int64(i * 2)))
    }
    #expect(result == JSON.object(expectedDict))
  }

  @Test("merge patch with deeply nested structure (10 levels)")
  func deeplyNestedStructure() {
    // Build target and patch as deeply nested structures
    var targetBuilder: JSON = JSON.object(["value": JSON.string("deep")])
    var patchBuilder: JSON = JSON.object(["value": JSON.string("updated")])
    for _ in 0..<10 {
      targetBuilder = JSON.object(["level": targetBuilder])
      patchBuilder = JSON.object(["level": patchBuilder])
    }
    let result = targetBuilder.mergePatch(patchBuilder) as JSON

    // Navigate down 10 levels to verify the update propagated
    var current = result
    for _ in 0..<10 {
      guard case .object(let dict) = current.storage, let level = dict["level"] else {
        Issue.record("missing level key")
        return
      }
      current = level
    }
    guard case .object(let dict) = current.storage, let value = dict["value"] else {
      Issue.record("missing value key")
      return
    }
    #expect(value == JSON.string("updated"))
  }

  // MARK: - Null value handling in target

  @Test("target has null key, patch object adds nested keys")
  func targetNullAddsNestedKeys() {
    let target = JSON.object([
      "a": JSON.null
    ])
    let patch = JSON.object([
      "a": JSON.object([
        "b": JSON.string("c"),
        "d": JSON.number(.integer(1)),
      ])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object([
        "b": JSON.string("c"),
        "d": JSON.number(.integer(1)),
      ])
    ])
    #expect(result == expected)
  }

  @Test("patch with multiple null values in nested object")
  func multipleNullsInNestedObject() {
    let target = JSON.object([
      "a": JSON.object([
        "x": JSON.number(.integer(1)),
        "y": JSON.number(.integer(2)),
        "z": JSON.number(.integer(3)),
      ])
    ])
    let patch = JSON.object([
      "a": JSON.object([
        "x": JSON.null,
        "z": JSON.null,
        "w": JSON.number(.integer(4)),
      ])
    ])
    let result = target.mergePatch(patch)
    let expected = JSON.object([
      "a": JSON.object([
        "y": JSON.number(.integer(2)),
        "w": JSON.number(.integer(4)),
      ])
    ])
    #expect(result == expected)
  }
}
