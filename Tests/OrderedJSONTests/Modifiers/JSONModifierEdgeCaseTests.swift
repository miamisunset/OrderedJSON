import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Modifier Edge Cases

@Suite("Modifier Edge Cases") struct JSONModifierEdgeCaseTests {

  // MARK: - update(mergingNested:) edge cases

  @Test("update merge: non-object target overwritten by object source")
  func updateMergeNonObjectTargetOverwrittenByObjectSource() {
    var target = JSON.object(["a": JSON.string("string")])
    let source = JSON.object(["a": JSON.object(["x": JSON.number(.integer(1))])])
    target.update(with: source, mergingNested: true)
    // "a" in target was a string, source has an object — should overwrite (not merge)
    #expect(target["a"]?.isObject == true)
    #expect(target["a"]?["x"] == JSON.number(.integer(1)))
  }

  @Test("update merge: both non-object at same key — simple overwrite")
  func updateMergeBothNonObject() {
    var target = JSON.object(["a": JSON.number(.integer(1))])
    let source = JSON.object(["a": JSON.string("replaced")])
    target.update(with: source, mergingNested: true)
    #expect(target["a"] == JSON.string("replaced"))
  }

  @Test("update merge: target key missing — value added")
  func updateMergeKeyMissing() {
    var target = JSON.object(["a": JSON.number(.integer(1))])
    let source = JSON.object(["b": JSON.object(["x": JSON.number(.integer(2))])])
    target.update(with: source, mergingNested: true)
    #expect(target["a"] == JSON.number(.integer(1)))
    #expect(target["b"]?.isObject == true)
    #expect(target["b"]?["x"] == JSON.number(.integer(2)))
  }

  @Test("update merge: empty source — no changes")
  func updateMergeEmptySource() {
    var target = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
    let empty = JSON.object(OrderedDictionary<String, JSON>())
    target.update(with: empty, mergingNested: true)
    #expect(target.count == 2)
    #expect(target["a"] == JSON.number(.integer(1)))
    #expect(target["b"] == JSON.string("x"))
  }

  @Test("update merge: empty target with source — keys added")
  func updateMergeEmptyTarget() {
    var target = JSON.object(OrderedDictionary<String, JSON>())
    let source = JSON.object(["a": JSON.number(.integer(1))])
    target.update(with: source, mergingNested: true)
    #expect(target.count == 1)
    #expect(target["a"] == JSON.number(.integer(1)))
  }

  @Test("update merge: both empty objects — no-op")
  func updateMergeBothEmpty() {
    var target = JSON.object(OrderedDictionary<String, JSON>())
    let source = JSON.object(OrderedDictionary<String, JSON>())
    target.update(with: source, mergingNested: true)
    #expect(target.isEmpty)
  }

  @Test("update merge: non-object target, non-object source at top level — no-op")
  func updateMergeNonObjectBothSides() {
    var target = JSON.string("hello")
    let source = JSON.object(["a": JSON.number(.integer(1))])
    target.update(with: source, mergingNested: true)
    #expect(target == JSON.string("hello"))
  }

  @Test("update non-mutating: returns new object without modifying original")
  func updatedNonMutating() {
    let original = JSON.object(["a": JSON.number(.integer(1))])
    let other = JSON.object(["b": JSON.number(.integer(2))])
    let result = original.updated(with: other)
    #expect(original.count == 1)  // unchanged
    #expect(result.count == 2)
    #expect(result["a"] == JSON.number(.integer(1)))
    #expect(result["b"] == JSON.number(.integer(2)))
  }

  @Test("update non-mutating with mergingNested: true")
  func updatedNonMutatingMergingNested() {
    let original = JSON.object([
      "a": JSON.object(["x": JSON.number(.integer(1))])
    ])
    let other = JSON.object([
      "a": JSON.object(["y": JSON.number(.integer(2))])
    ])
    let result = original.updated(with: other, mergingNested: true)
    #expect(result["a"]?["x"] == JSON.number(.integer(1)))
    #expect(result["a"]?["y"] == JSON.number(.integer(2)))
  }

  // MARK: - setDefault autoclosure laziness

  @Test("setDefault: autoclosure not evaluated when key exists")
  func setDefaultAutoclosureNotEvaluated() {
    var sideEffects: [Int] = []
    func makeValue() -> JSON {
      sideEffects.append(42)
      return JSON.number(.integer(42))
    }

    var obj = JSON.object(["a": JSON.string("existing")])
    obj.setDefault(key: "a", makeValue())
    #expect(obj["a"] == JSON.string("existing"))  // unchanged
    #expect(sideEffects.isEmpty)  // closure was never evaluated
  }

  @Test("setDefault: autoclosure evaluated when key missing")
  func setDefaultAutoclosureEvaluatedWhenMissing() {
    var sideEffects: [Int] = []
    func makeValue() -> JSON {
      sideEffects.append(99)
      return JSON.number(.integer(99))
    }

    var obj = JSON.object(["a": JSON.string("existing")])
    obj.setDefault(key: "b", makeValue())
    #expect(obj["b"] == JSON.number(.integer(99)))
    #expect(sideEffects == [99])  // closure was evaluated
  }

  @Test("setDefault: autoclosure on non-object — no-op, no evaluation")
  func setDefaultNonObjectNoEvaluation() {
    var sideEffects: [Int] = []
    func makeValue() -> JSON {
      sideEffects.append(42)
      return JSON.number(.integer(42))
    }

    var arr = JSON.array([JSON.string("x")])
    arr.setDefault(key: "a", makeValue())
    #expect(arr.count == 1)
    #expect(sideEffects.isEmpty)  // closure never evaluated (early return)
  }

  // MARK: - remove(at:) edge cases

  @Test("remove at negative index on array — no-op")
  func removeAtNegativeIndex() {
    var arr = JSON.array([JSON.string("a"), JSON.string("b"), JSON.string("c")])
    arr.remove(at: -1)
    #expect(arr.count == 3)
    arr.remove(at: -100)
    #expect(arr.count == 3)
  }

  @Test("remove at index equal to count — no-op")
  func removeAtIndexEqualToCount() {
    var arr = JSON.array([JSON.string("a"), JSON.string("b")])
    arr.remove(at: 2)  // count is 2, so index 2 is out of bounds
    #expect(arr.count == 2)
  }

  @Test("remove at index 0 from empty array — no-op")
  func removeAtIndexZeroEmpty() {
    var arr = JSON.array([])
    arr.remove(at: 0)
    #expect(arr.isEmpty)
  }

  @Test("remove at last index works correctly")
  func removeAtLastIndex() {
    var arr = JSON.array([JSON.string("a"), JSON.string("b"), JSON.string("c")])
    arr.remove(at: 2)
    #expect(arr.count == 2)
    #expect(arr[0] == JSON.string("a"))
    #expect(arr[1] == JSON.string("b"))
  }

  // MARK: - swap edge cases

  @Test("swap with equal value — no effective change")
  func swapWithEqualValue() {
    var a = JSON.string("hello")
    var b = JSON.string("hello")
    a.swap(with: &b)
    #expect(a == JSON.string("hello"))
    #expect(b == JSON.string("hello"))
  }

  @Test("swap null with object")
  func swapNullWithObject() {
    var nullVal = JSON.null
    var obj = JSON.object(["key": JSON.string("value")])
    nullVal.swap(with: &obj)
    #expect(nullVal.isObject)
    #expect(nullVal["key"] == JSON.string("value"))
    #expect(obj.isNull)
  }

  @Test("swap array with boolean")
  func swapArrayWithBool() {
    var arr = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    var bool = JSON.boolean(true)
    arr.swap(with: &bool)
    #expect(arr.isBoolean)
    #expect(arr == JSON.boolean(true))
    #expect(bool.isArray)
    #expect(bool == JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))]))
  }

  @Test("swap inout semantics — values are exchanged")
  func swapInoutSemantics() {
    var a = JSON.string("first")
    var b = JSON.string("second")
    a.swap(with: &b)
    #expect(a == JSON.string("second"))
    #expect(b == JSON.string("first"))
  }

  // MARK: - append/insert edge cases

  @Test("append to empty array")
  func appendToEmptyArray() {
    var arr = JSON.array([])
    arr.append(JSON.number(.integer(1)))
    #expect(arr.count == 1)
    #expect(arr[0] == JSON.number(.integer(1)))
  }

  @Test("append null to array")
  func appendNullToArray() {
    var arr = JSON.array([JSON.string("a")])
    arr.append(JSON.null)
    #expect(arr.count == 2)
    #expect(arr[1]?.isNull == true)
  }

  @Test("insert at beginning of array")
  func insertAtBeginning() {
    var arr = JSON.array([JSON.string("b"), JSON.string("c")])
    arr.insert(JSON.string("a"), at: 0)
    #expect(arr.count == 3)
    #expect(arr[0] == JSON.string("a"))
    #expect(arr[1] == JSON.string("b"))
    #expect(arr[2] == JSON.string("c"))
  }

  @Test("insert at end of array (index == count)")
  func insertAtEnd() {
    var arr = JSON.array([JSON.string("a"), JSON.string("b")])
    arr.insert(JSON.string("c"), at: 2)  // index == count — appends
    #expect(arr.count == 3)
    #expect(arr[0] == JSON.string("a"))
    #expect(arr[1] == JSON.string("b"))
    #expect(arr[2] == JSON.string("c"))
  }

  @Test("insert into empty array")
  func insertIntoEmpty() {
    var arr = JSON.array([])
    arr.insert(JSON.string("a"), at: 0)  // index == count == 0 — works
    #expect(arr.count == 1)
    #expect(arr[0] == JSON.string("a"))
  }

  // MARK: - clear/erase edge cases

  @Test("clear then append on same array")
  func clearThenAppend() {
    var arr = JSON.array([JSON.string("a"), JSON.string("b")])
    arr.clear()
    #expect(arr.isEmpty)
    arr.append(JSON.string("c"))
    #expect(arr.count == 1)
    #expect(arr[0] == JSON.string("c"))
  }

  @Test("remove key then add same key")
  func removeKeyThenReadd() {
    var obj = JSON.object(["a": JSON.string("first")])
    obj.remove(key: "a")
    #expect(obj.isEmpty)
    obj.setDefault(key: "a", JSON.string("second"))
    #expect(obj["a"] == JSON.string("second"))
  }
}
