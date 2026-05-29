import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - JSONAccess Tests

@Suite("Access Tests") struct JSONAccessTests {
  @Test("count object") func countObject() {
    let obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
    #expect(obj.count == 2)
  }

  @Test("count array") func countArray() {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1)), JSON.boolean(true)])
    #expect(arr.count == 3)
  }

  @Test("count scalar") func countScalar() {
    #expect(JSON.string("hello").count == 0)
    #expect(JSON.number(.integer(42)).count == 0)
    #expect(JSON.boolean(true).count == 0)
    #expect(JSON.null.count == 0)
  }

  @Test("is empty object") func isEmptyObject() {
    #expect(JSON.object([:]).isEmpty)
    #expect(JSON.object(["a": JSON.string("x")]).isEmpty == false)
  }

  @Test("is empty array") func isEmptyArray() {
    #expect(JSON.array([]).isEmpty)
    #expect(JSON.array([JSON.string("a")]).isEmpty == false)
  }

  @Test("is empty null") func isEmptyNull() {
    #expect(JSON.null.isEmpty)
  }

  @Test("is empty scalar") func isEmptyScalar() {
    #expect(JSON.string("a").isEmpty == false)
    #expect(JSON.number(.integer(1)).isEmpty == false)
    #expect(JSON.boolean(true).isEmpty == false)
  }

  @Test("first array") func firstArray() {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    #expect(arr.first == JSON.string("a"))
  }

  @Test("first empty array") func firstEmptyArray() {
    #expect(JSON.array([]).first == nil)
  }

  @Test("first object") func firstObject() {
    let obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
    #expect(obj.first == JSON.string("x"))
  }

  @Test("first empty object") func firstEmptyObject() {
    #expect(JSON.object([:]).first == nil)
  }

  @Test("first scalar") func firstScalar() {
    #expect(JSON.string("hello").first == nil)
    #expect(JSON.number(.integer(42)).first == nil)
    #expect(JSON.boolean(true).first == nil)
    #expect(JSON.null.first == nil)
  }

  @Test("last array") func lastArray() {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    #expect(arr.last == JSON.number(.integer(1)))
  }

  @Test("last empty array") func lastEmptyArray() {
    #expect(JSON.array([]).last == nil)
  }

  @Test("last object") func lastObject() {
    let obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
    #expect(obj.last == JSON.number(.integer(1)))
  }

  @Test("last empty object") func lastEmptyObject() {
    #expect(JSON.object([:]).last == nil)
  }

  @Test("last scalar") func lastScalar() {
    #expect(JSON.string("hello").last == nil)
    #expect(JSON.number(.integer(42)).last == nil)
    #expect(JSON.boolean(true).last == nil)
    #expect(JSON.null.last == nil)
  }
}

// MARK: - JSONLookup Tests

@Suite("Lookup Tests") struct JSONLookupTests {
  @Test("contains key") func containsKey() {
    let obj = JSON.object(["a": JSON.string("x")])
    #expect(obj.contains(key: "a"))
    #expect(obj.contains(key: "b") == false)
  }

  @Test("contains key non object") func containsKeyNonObject() {
    #expect(JSON.string("hello").contains(key: "key") == false)
    #expect(JSON.array([]).contains(key: "key") == false)
    #expect(JSON.null.contains(key: "key") == false)
  }

  @Test("find key") func findKey() {
    let obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
    #expect(obj.find(key: "a") == JSON.string("x"))
    #expect(obj.find(key: "missing") == nil)
  }

  @Test("find key non object") func findKeyNonObject() {
    #expect(JSON.string("hello").find(key: "key") == nil)
    #expect(JSON.array([]).find(key: "key") == nil)
    #expect(JSON.null.find(key: "key") == nil)
  }
}

// MARK: - JSONSubscript Tests

@Suite("Subscript Tests") struct JSONSubscriptTests {
  @Test("key get") func keyGet() {
    let obj = JSON.object(["a": JSON.string("x")])
    #expect(obj["a"] == JSON.string("x"))
    #expect(obj["missing"] == nil)
  }

  @Test("key get non object") func keyGetNonObject() {
    #expect(JSON.string("hello")["key"] == nil)
    #expect(JSON.array([])["key"] == nil)
  }

  @Test("key set") func keySet() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj["a"] = JSON.number(.integer(42))
    #expect(obj["a"] == JSON.number(.integer(42)))
  }

  @Test("key set new key") func keySetNewKey() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj["b"] = JSON.number(.integer(42))
    #expect(obj["b"] == JSON.number(.integer(42)))
  }

  @Test("key remove") func keyRemove() {
    var obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
    obj["a"] = nil
    #expect(obj["a"] == nil)
    #expect(obj.count == 1)
  }

  @Test("key set non object") func keySetNonObject() {
    var str = JSON.string("hello")
    str["key"] = JSON.number(.integer(42))
    #expect(str == JSON.string("hello"))
  }

  @Test("index get") func indexGet() {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    #expect(arr[0] == JSON.string("a"))
    #expect(arr[1] == JSON.number(.integer(1)))
    #expect(arr[2] == nil)
    #expect(arr[-1] == nil)
  }

  @Test("index get non array") func indexGetNonArray() {
    #expect(JSON.object([:])[0] == nil)
    #expect(JSON.string("hello")[0] == nil)
  }

  @Test("index set") func indexSet() {
    var arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    arr[0] = JSON.string("b")
    #expect(arr[0] == JSON.string("b"))
  }

  @Test("index remove") func indexRemove() {
    var arr = JSON.array([JSON.string("a"), JSON.number(.integer(1)), JSON.boolean(true)])
    arr[1] = nil
    #expect(arr.count == 2)
    #expect(arr[0] == JSON.string("a"))
    #expect(arr[1] == JSON.boolean(true))
  }

  @Test("index set non array") func indexSetNonArray() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj[0] = JSON.string("b")
    #expect(obj == JSON.object(["a": JSON.string("x")]))
  }
}

// MARK: - Throwing Accessor Tests

@Suite("Throwing Accessor Tests") struct JSONThrowingAccessorTests {
  @Test("at key success") func atKeySuccess() throws {
    let obj = JSON.object(["a": JSON.string("x")])
    let val = try obj.at(key: "a")
    #expect(val == JSON.string("x"))
  }

  @Test("at key throws type error") func atKeyThrowsTypeError() throws {
    let str = JSON.string("hello")
    let error = #expect(throws: JSONError.self) {
      try str.at(key: "key")
    }
    #expect(error == JSONError.typeError(expected: "object", actual: "string"))
  }

  @Test("at key throws key not found") func atKeyThrowsKeyNotFound() throws {
    let obj = JSON.object(["a": JSON.string("x")])
    let error = #expect(throws: JSONError.self) {
      try obj.at(key: "missing")
    }
    #expect(error == JSONError.keyNotFound("missing"))
  }

  @Test("at index throws type error") func atIndexThrowsTypeError() throws {
    let obj = JSON.object(["a": JSON.string("x")])
    let error = #expect(throws: JSONError.self) {
      try obj.at(index: 0)
    }
    #expect(error == JSONError.typeError(expected: "array", actual: "object"))
  }

  @Test("at index throws out of bounds") func atIndexThrowsOutOfBounds() throws {
    let arr = JSON.array([JSON.string("a")])
    #expect(throws: JSONError.indexOutOfBounds(1)) {
      try arr.at(index: 1)
    }
    #expect(throws: JSONError.indexOutOfBounds(-1)) {
      try arr.at(index: -1)
    }
  }

  @Test("at index success") func atIndexSuccess() throws {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    let val = try arr.at(index: 1)
    #expect(val == JSON.number(.integer(1)))
  }

  @Test("value key with default") func valueKeyWithDefault() {
    let obj = JSON.object(["a": JSON.string("x")])
    #expect(obj.value(forKey: "a", default: JSON.string("default")) == JSON.string("x"))
    #expect(obj.value(forKey: "missing", default: JSON.string("default")) == JSON.string("default"))
  }

  @Test("value key non object") func valueKeyNonObject() {
    let str = JSON.string("hello")
    #expect(
      str.value(forKey: "key", default: JSON.number(.integer(42))) == JSON.number(.integer(42)))
  }

  @Test("value index with default") func valueIndexWithDefault() {
    let arr = JSON.array([
      JSON.string("a"),
      JSON.number(.integer(1)),
      JSON.boolean(true),
    ])
    #expect(arr.value(at: 0, default: JSON.string("default")) == JSON.string("a"))
    #expect(arr.value(at: 1, default: JSON.string("default")) == JSON.number(.integer(1)))
    #expect(arr.value(at: 2, default: JSON.string("default")) == JSON.boolean(true))
  }

  @Test("value index out of bounds") func valueIndexOutOfBounds() {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    #expect(arr.value(at: 2, default: JSON.string("default")) == JSON.string("default"))
    #expect(arr.value(at: -1, default: JSON.number(.integer(0))) == JSON.number(.integer(0)))
  }

  @Test("value index non array") func valueIndexNonArray() {
    let scalar = JSON.string("hello")
    #expect(scalar.value(at: 0, default: JSON.number(.integer(42))) == JSON.number(.integer(42)))
  }

  @Test("value index empty array") func valueIndexEmptyArray() {
    let arr = JSON.array([])
    #expect(arr.value(at: 0, default: JSON.string("default")) == JSON.string("default"))
  }

  @Test("value index sentinel default") func valueIndexSentinelDefault() {
    let sentinel = JSON.object(["marker": JSON.boolean(true)])
    let arr = JSON.array([JSON.string("a")])
    let result = arr.value(at: 99, default: sentinel)
    #expect(result == sentinel)
    #expect(result["marker"] == JSON.boolean(true))
  }
}

// MARK: - Dynamic member lookup

@Suite("Dynamic Member Tests") struct JSONDynamicMemberTests {
  @Test("get object key") func getObjectKey() {
    let obj = JSON.object([
      "user": JSON.object(["name": JSON.string("Alice"), "age": JSON.number(.integer(30))]),
      "role": JSON.string("admin"),
    ])
    #expect(
      obj.user
        == JSON.object([
          "name": JSON.string("Alice"),
          "age": JSON.number(.integer(30)),
        ])
    )
    #expect(obj.user.name == JSON.string("Alice"))
    #expect(obj.user.age == JSON.number(.integer(30)))
    #expect(obj.role == JSON.string("admin"))
  }

  @Test("missing key returns null") func missingKeyReturnsNull() {
    let obj = JSON.object(["a": JSON.string("x")])
    #expect(obj.missing == .null)
  }

  @Test("non object returns null") func nonObjectReturnsNull() {
    let scalar = JSON.number(.integer(42))
    #expect(scalar.foo == .null)
    let arr = JSON.array([JSON.string("a")])
    #expect(arr.nonexistent == .null)
  }

  @Test("set value") func setValue() {
    var obj = JSON.object(["a": JSON.number(.integer(1))])
    obj.b = JSON.number(.integer(2))
    #expect(obj.a == JSON.number(.integer(1)))
    #expect(obj.b == JSON.number(.integer(2)))
  }

  @Test("set non object noop") func setNonObjectNoop() {
    var scalar = JSON.number(.integer(42))
    scalar.foo = JSON.string("bar")
    #expect(scalar == JSON.number(.integer(42)))
  }

  @Test("set overwrites") func setOverwrites() {
    var obj = JSON.object(["x": JSON.number(.integer(1))])
    obj.x = JSON.number(.integer(2))
    #expect(obj.x == JSON.number(.integer(2)))
  }
}

// MARK: - Array contains Tests

@Suite("Array Contains Tests") struct JSONArrayContainsTests {
  @Test("existing element") func existingElement() {
    let arr = JSON.array([
      JSON.string("a"),
      JSON.number(.integer(1)),
      JSON.boolean(true),
    ])
    #expect(arr.contains(element: JSON.string("a")))
    #expect(arr.contains(element: JSON.number(.integer(1))))
    #expect(arr.contains(element: JSON.boolean(true)))
  }

  @Test("missing element") func missingElement() {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    #expect(arr.contains(element: JSON.string("b")) == false)
    #expect(arr.contains(element: JSON.number(.integer(2))) == false)
  }

  @Test("non array returns false") func nonArrayReturnsFalse() {
    let scalar = JSON.string("hello")
    #expect(scalar.contains(element: JSON.string("hello")) == false)
  }

  @Test("empty array") func emptyArray() {
    let arr = JSON.array([])
    #expect(arr.contains(element: JSON.string("a")) == false)
  }

  @Test("nested array") func nestedArray() {
    let nested = JSON.array([JSON.array([JSON.number(.integer(1))])])
    #expect(nested.contains(element: JSON.array([JSON.number(.integer(1))])))
    #expect(nested.contains(element: JSON.array([JSON.number(.integer(2))])) == false)
  }

  @Test("cross type") func crossType() {
    let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
    #expect(arr.contains(element: JSON.number(.integer(2))) == false)
    #expect(arr.contains(element: JSON.boolean(true)) == false)
  }

  @Test("duplicate") func duplicate() {
    let arr = JSON.array([
      JSON.string("a"),
      JSON.string("b"),
      JSON.string("a"),
    ])
    #expect(arr.contains(element: JSON.string("a")))
    #expect(arr.contains(element: JSON.string("b")))
    #expect(arr.contains(element: JSON.string("c")) == false)
  }
}
