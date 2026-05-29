import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - JSONClear Tests

@Suite("Clear Tests") struct JSONClearTests {
  @Test("clear object") func clearObject() {
    var obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
    obj.clear()
    #expect(obj.isObject)
    #expect(obj.isEmpty)
  }

  @Test("clear array") func clearArray() {
    var arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    arr.clear()
    #expect(arr.isArray)
    #expect(arr.isEmpty)
  }

  @Test("cleared object") func clearedObject() {
    let obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
    let cleared = obj.cleared()
    #expect(cleared.isObject)
    #expect(cleared.isEmpty)
    #expect(obj.isEmpty == false)  // original unchanged
  }

  @Test("cleared array") func clearedArray() {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    let cleared = arr.cleared()
    #expect(cleared.isArray)
    #expect(cleared.isEmpty)
    #expect(arr.isEmpty == false)  // original unchanged
  }

  @Test("cleared scalar returns self") func clearedScalarReturnsSelf() {
    let str = JSON.string("hello")
    #expect(str.cleared() == str)

    let num = JSON.number(.integer(42))
    #expect(num.cleared() == num)

    let bool = JSON.boolean(true)
    #expect(bool.cleared() == bool)

    let nullVal = JSON.null
    #expect(nullVal.cleared().isNull)
  }

  @Test("clear scalar noop") func clearScalarNoop() {
    var str = JSON.string("hello")
    str.clear()
    #expect(str == JSON.string("hello"))

    var num = JSON.number(.integer(42))
    num.clear()
    #expect(num == JSON.number(.integer(42)))

    var bool = JSON.boolean(true)
    bool.clear()
    #expect(bool == JSON.boolean(true))

    var nullVal = JSON.null
    nullVal.clear()
    #expect(nullVal.isNull)
  }
}

// MARK: - JSONErase Tests

@Suite("Erase Tests") struct JSONEraseTests {
  @Test("erase key") func eraseKey() {
    var obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
    obj.remove(key: "a")
    #expect(obj.count == 1)
    #expect(obj["a"] == nil)
    #expect(obj["b"] == JSON.number(.integer(1)))
  }

  @Test("erase key non object") func eraseKeyNonObject() {
    var arr = JSON.array([JSON.string("a")])
    arr.remove(key: "key")  // silently ignored
    #expect(arr.count == 1)
  }

  @Test("erase key missing") func eraseKeyMissing() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj.remove(key: "missing")
    #expect(obj.count == 1)
  }

  @Test("erase index") func eraseIndex() {
    var arr = JSON.array([JSON.string("a"), JSON.number(.integer(1)), JSON.boolean(true)])
    arr.remove(at: 1)
    #expect(arr.count == 2)
    #expect(arr[0] == JSON.string("a"))
    #expect(arr[1] == JSON.boolean(true))
  }

  @Test("erase index out of bounds") func eraseIndexOutOfBounds() {
    var arr = JSON.array([JSON.string("a")])
    arr.remove(at: 5)  // silently ignored
    #expect(arr.count == 1)
    arr.remove(at: -1)  // silently ignored
    #expect(arr.count == 1)
  }

  @Test("erase index non array") func eraseIndexNonArray() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj.remove(at: 0)  // silently ignored
    #expect(obj.count == 1)
  }
}

// MARK: - JSONAppendInsert Tests

@Suite("Append Insert Tests") struct JSONAppendInsertTests {
  @Test("append to array") func appendToArray() {
    var arr = JSON.array([JSON.string("a")])
    arr.append(JSON.number(.integer(42)))
    #expect(arr.count == 2)
    #expect(arr[1] == JSON.number(.integer(42)))
  }

  @Test("append to non array") func appendToNonArray() {
    var str = JSON.string("hello")
    str.append(JSON.number(.integer(42)))  // silently ignored
    #expect(str == JSON.string("hello"))
  }

  @Test("insert at index") func insertAtIndex() {
    var arr = JSON.array([JSON.string("a"), JSON.string("c")])
    arr.insert(JSON.string("b"), at: 1)
    #expect(arr.count == 3)
    #expect(arr[0] == JSON.string("a"))
    #expect(arr[1] == JSON.string("b"))
    #expect(arr[2] == JSON.string("c"))
  }

  @Test("insert out of bounds") func insertOutOfBounds() {
    var arr = JSON.array([JSON.string("a")])
    arr.insert(JSON.string("b"), at: 5)  // silently ignored
    #expect(arr.count == 1)
  }

  @Test("insert non array") func insertNonArray() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj.insert(JSON.string("b"), at: 0)  // silently ignored
    #expect(obj.count == 1)
  }
}

// MARK: - JSONEmplaceUpdate Tests

@Suite("Emplace Update Tests") struct JSONEmplaceUpdateTests {
  @Test("emplace object new key") func emplaceObjectNewKey() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj.setDefault(key: "b", JSON.number(.integer(42)))
    #expect(obj.count == 2)
    #expect(obj["b"] == JSON.number(.integer(42)))
  }

  @Test("emplace object existing key") func emplaceObjectExistingKey() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj.setDefault(key: "a", JSON.number(.integer(99)))
    #expect(obj.count == 1)
    #expect(obj["a"] == JSON.string("x"))
  }

  @Test("emplace object non object") func emplaceObjectNonObject() {
    var str = JSON.string("hello")
    str.setDefault(key: "a", JSON.number(.integer(42)))  // silently ignored
    #expect(str == JSON.string("hello"))
  }

  @Test("update object") func updateObject() {
    var obj = JSON.object(["a": JSON.string("x")])
    let other = JSON.object(["b": JSON.number(.integer(42)), "a": JSON.string("new")])
    obj.update(with: other)
    #expect(obj.count == 2)
    #expect(obj["a"] == JSON.string("new"))
    #expect(obj["b"] == JSON.number(.integer(42)))
  }

  @Test("update non object target") func updateNonObjectTarget() {
    var str = JSON.string("hello")
    let other = JSON.object(["a": JSON.string("x")])
    str.update(with: other)  // silently ignored
    #expect(str == JSON.string("hello"))
  }

  @Test("update with non object source") func updateWithNonObjectSource() {
    var obj = JSON.object(["a": JSON.string("x")])
    let other = JSON.string("not object")
    obj.update(with: other)  // silently ignored
    #expect(obj.count == 1)
  }

  @Test("update merge objects simple") func updateMergeObjectsSimple() {
    var obj = JSON.object([
      "a": JSON.object(["x": JSON.number(.integer(1))]),
      "b": JSON.string("keep"),
    ])
    let other = JSON.object([
      "a": JSON.object(["y": JSON.number(.integer(2))]),
      "c": JSON.string("new"),
    ])
    obj.update(with: other, mergingNested: true)
    #expect(obj["a"]?.isObject == true)
    #expect(obj["a"]?["x"] == JSON.number(.integer(1)))  // preserved
    #expect(obj["a"]?["y"] == JSON.number(.integer(2)))  // added
    #expect(obj["b"] == JSON.string("keep"))  // unchanged
    #expect(obj["c"] == JSON.string("new"))  // added
  }

  @Test("update merge objects deep") func updateMergeObjectsDeep() {
    var obj = JSON.object([
      "a": JSON.object([
        "b": JSON.object(["c": JSON.number(.integer(1))])
      ])
    ])
    let other = JSON.object([
      "a": JSON.object([
        "b": JSON.object(["d": JSON.number(.integer(2))])
      ])
    ])
    obj.update(with: other, mergingNested: true)
    #expect(obj["a"]?["b"]?["c"] == JSON.number(.integer(1)))  // preserved
    #expect(obj["a"]?["b"]?["d"] == JSON.number(.integer(2)))  // added
  }

  @Test("update merge objects non object overwrites") func updateMergeObjectsNonObjectOverwrites() {
    var obj = JSON.object([
      "a": JSON.object(["x": JSON.number(.integer(1))])
    ])
    let other = JSON.object([
      "a": JSON.string("replaced")  // not an object — overwrites entirely
    ])
    obj.update(with: other, mergingNested: true)
    #expect(obj["a"] == JSON.string("replaced"))
  }

  @Test("update merge objects default is false") func updateMergeObjectsDefaultIsFalse() {
    var obj = JSON.object([
      "a": JSON.object(["x": JSON.number(.integer(1))])
    ])
    let other = JSON.object([
      "a": JSON.object(["y": JSON.number(.integer(2))])
    ])
    obj.update(with: other)  // default: mergingNested=false
    #expect(obj["a"]?["x"] == nil)  // overwritten, not merged
    #expect(obj["a"]?["y"] == JSON.number(.integer(2)))
  }

  @Test("update merge objects array overwrites") func updateMergeObjectsArrayOverwrites() {
    var obj = JSON.object([
      "a": JSON.object(["x": JSON.number(.integer(1))])
    ])
    let other = JSON.object([
      "a": JSON.array([JSON.number(.integer(99))])  // array, not object — overwrites
    ])
    obj.update(with: other, mergingNested: true)
    #expect(obj["a"]?.isArray == true)
    #expect(obj["a"] == JSON.array([JSON.number(.integer(99))]))
  }

  @Test("update merge objects null overwrites") func updateMergeObjectsNullOverwrites() {
    var obj = JSON.object([
      "a": JSON.object(["x": JSON.number(.integer(1))])
    ])
    let other = JSON.object([
      "a": JSON.null
    ])
    obj.update(with: other, mergingNested: true)
    #expect(obj["a"] == JSON.null)  // null is not an object — overwrites
  }

  @Test("update merge objects self merge") func updateMergeObjectsSelfMerge() {
    var obj = JSON.object([
      "a": JSON.object(["x": JSON.number(.integer(1))]),
      "b": JSON.string("keep"),
    ])
    obj.update(with: obj, mergingNested: true)  // self-merge is safe (value semantics)
    #expect(obj["a"]?["x"] == JSON.number(.integer(1)))
    #expect(obj["b"] == JSON.string("keep"))
  }
}

// MARK: - JSONSwap Tests

@Suite("Swap Tests") struct JSONSwapTests {
  @Test("swap values") func swapValues() {
    var a = JSON.string("hello")
    var b = JSON.number(.integer(42))
    a.swap(with: &b)
    #expect(a == JSON.number(.integer(42)))
    #expect(b == JSON.string("hello"))
  }
}
