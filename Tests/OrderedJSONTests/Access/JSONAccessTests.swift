import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - JSONAccess Tests

@Test func accessCountObject() {
  let obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
  #expect(obj.count == 2)
}

@Test func accessCountArray() {
  let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1)), JSON.boolean(true)])
  #expect(arr.count == 3)
}

@Test func accessCountScalar() {
  #expect(JSON.string("hello").count == 0)
  #expect(JSON.number(.integer(42)).count == 0)
  #expect(JSON.boolean(true).count == 0)
  #expect(JSON.null.count == 0)
}

@Test func accessIsEmptyObject() {
  #expect(JSON.object([:]).isEmpty)
  #expect(!JSON.object(["a": JSON.string("x")]).isEmpty)
}

@Test func accessIsEmptyArray() {
  #expect(JSON.array([]).isEmpty)
  #expect(!JSON.array([JSON.string("a")]).isEmpty)
}

@Test func accessIsEmptyNull() {
  #expect(JSON.null.isEmpty)
}

@Test func accessIsEmptyScalar() {
  #expect(!JSON.string("a").isEmpty)
  #expect(!JSON.number(.integer(1)).isEmpty)
  #expect(!JSON.boolean(true).isEmpty)
}

@Test func accessFirstArray() {
  let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
  #expect(arr.first == JSON.string("a"))
}

@Test func accessFirstEmptyArray() {
  #expect(JSON.array([]).first == nil)
}

@Test func accessFirstObject() {
  let obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
  #expect(obj.first == JSON.string("x"))
}

@Test func accessFirstEmptyObject() {
  #expect(JSON.object([:]).first == nil)
}

@Test func accessFirstScalar() {
  #expect(JSON.string("hello").first == nil)
  #expect(JSON.number(.integer(42)).first == nil)
  #expect(JSON.boolean(true).first == nil)
  #expect(JSON.null.first == nil)
}

@Test func accessLastArray() {
  let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
  #expect(arr.last == JSON.number(.integer(1)))
}

@Test func accessLastEmptyArray() {
  #expect(JSON.array([]).last == nil)
}

@Test func accessLastObject() {
  let obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
  #expect(obj.last == JSON.number(.integer(1)))
}

@Test func accessLastEmptyObject() {
  #expect(JSON.object([:]).last == nil)
}

@Test func accessLastScalar() {
  #expect(JSON.string("hello").last == nil)
  #expect(JSON.number(.integer(42)).last == nil)
  #expect(JSON.boolean(true).last == nil)
  #expect(JSON.null.last == nil)
}

// MARK: - JSONLookup Tests

@Test func lookupContains() {
  let obj = JSON.object(["a": JSON.string("x")])
  #expect(obj.contains(key: "a"))
  #expect(!obj.contains(key: "b"))
}

@Test func lookupContainsNonObject() {
  #expect(JSON.string("hello").contains(key: "key") == false)
  #expect(JSON.array([]).contains(key: "key") == false)
  #expect(JSON.null.contains(key: "key") == false)
}

@Test func lookupCountKey() {
  let obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
  #expect(obj.containsKey("a"))
  #expect(!obj.containsKey("missing"))
}

@Test func lookupCountKeyNonObject() {
  #expect(!JSON.string("hello").containsKey("key"))
  #expect(!JSON.array([]).containsKey("key"))
  #expect(!JSON.null.containsKey("key"))
}

@Test func lookupFind() {
  let obj = JSON.object(["a": JSON.string("x")])
  #expect(obj.find(key: "a") == JSON.string("x"))
  #expect(obj.find(key: "missing") == nil)
}

@Test func lookupFindNonObject() {
  #expect(JSON.string("hello").find(key: "key") == nil)
  #expect(JSON.array([]).find(key: "key") == nil)
  #expect(JSON.null.find(key: "key") == nil)
}

// MARK: - JSONSubscript Tests

@Test func subscriptKeyGet() {
  let obj = JSON.object(["a": JSON.string("x")])
  #expect(obj["a"] == JSON.string("x"))
  #expect(obj["missing"] == nil)
}

@Test func subscriptKeyGetNonObject() {
  #expect(JSON.string("hello")["key"] == nil)
  #expect(JSON.array([])["key"] == nil)
}

@Test func subscriptKeySet() {
  var obj = JSON.object(["a": JSON.string("x")])
  obj["a"] = JSON.number(.integer(42))
  #expect(obj["a"] == JSON.number(.integer(42)))
}

@Test func subscriptKeySetNewKey() {
  var obj = JSON.object(["a": JSON.string("x")])
  obj["b"] = JSON.number(.integer(42))
  #expect(obj["b"] == JSON.number(.integer(42)))
}

@Test func subscriptKeyRemove() {
  var obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
  obj["a"] = nil
  #expect(obj["a"] == nil)
  #expect(obj.count == 1)
}

@Test func subscriptKeySetNonObject() {
  var str = JSON.string("hello")
  str["key"] = JSON.number(.integer(42))  // silently ignored
  #expect(str == JSON.string("hello"))
}

@Test func subscriptIndexGet() {
  let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
  #expect(arr[0] == JSON.string("a"))
  #expect(arr[1] == JSON.number(.integer(1)))
  #expect(arr[2] == nil)
  #expect(arr[-1] == nil)
}

@Test func subscriptIndexGetNonArray() {
  #expect(JSON.object([:])[0] == nil)
  #expect(JSON.string("hello")[0] == nil)
}

@Test func subscriptIndexSet() {
  var arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
  arr[0] = JSON.string("b")
  #expect(arr[0] == JSON.string("b"))
}

@Test func subscriptIndexRemove() {
  var arr = JSON.array([JSON.string("a"), JSON.number(.integer(1)), JSON.boolean(true)])
  arr[1] = nil
  #expect(arr.count == 2)
  #expect(arr[0] == JSON.string("a"))
  #expect(arr[1] == JSON.boolean(true))
}

@Test func subscriptIndexSetNonArray() {
  var obj = JSON.object(["a": JSON.string("x")])
  obj[0] = JSON.string("b")  // silently ignored
  #expect(obj == JSON.object(["a": JSON.string("x")]))
}

@Test func atKeySuccess() throws {
  let obj = JSON.object(["a": JSON.string("x")])
  let val = try obj.at(key: "a")
  #expect(val == JSON.string("x"))
}

let typeErrorObjectExpected = JSONError.typeError(expected: "object", actual: "string")
let typeErrorArrayExpected = JSONError.typeError(expected: "array", actual: "object")
let keyNotFoundMissing = JSONError.keyNotFound("missing")
let indexOutOfBounds1 = JSONError.indexOutOfBounds(1)
let indexOutOfBoundsNeg = JSONError.indexOutOfBounds(-1)

@Test func atKeyThrowsTypeError() throws {
  let str = JSON.string("hello")
  #expect(throws: typeErrorObjectExpected) { try str.at(key: "key") }
}

@Test func atKeyThrowsKeyNotFound() throws {
  let obj = JSON.object(["a": JSON.string("x")])
  #expect(throws: keyNotFoundMissing) { try obj.at(key: "missing") }
}

@Test func atIndexThrowsTypeError() throws {
  let obj = JSON.object(["a": JSON.string("x")])
  #expect(throws: typeErrorArrayExpected) { try obj.at(index: 0) }
}

@Test func atIndexThrowsOutOfBounds() throws {
  let arr = JSON.array([JSON.string("a")])
  #expect(throws: indexOutOfBounds1) { try arr.at(index: 1) }
  #expect(throws: indexOutOfBoundsNeg) { try arr.at(index: -1) }
}

@Test func atIndexSuccess() throws {
  let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
  let val = try arr.at(index: 1)
  #expect(val == JSON.number(.integer(1)))
}

@Test func valueKeyWithDefault() {
  let obj = JSON.object(["a": JSON.string("x")])
  #expect(obj.value(forKey: "a", default: JSON.string("default")) == JSON.string("x"))
  #expect(obj.value(forKey: "missing", default: JSON.string("default")) == JSON.string("default"))
}

@Test func valueKeyNonObject() {
  let str = JSON.string("hello")
  #expect(str.value(forKey: "key", default: JSON.number(.integer(42))) == JSON.number(.integer(42)))
}

// MARK: - Array value with default Tests

@Test func valueIndexWithDefault() {
  let arr = JSON.array([
    JSON.string("a"),
    JSON.number(.integer(1)),
    JSON.boolean(true),
  ])
  #expect(arr.value(at: 0, default: JSON.string("default")) == JSON.string("a"))
  #expect(arr.value(at: 1, default: JSON.string("default")) == JSON.number(.integer(1)))
  #expect(arr.value(at: 2, default: JSON.string("default")) == JSON.boolean(true))
}

@Test func valueIndexOutOfBounds() {
  let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
  #expect(arr.value(at: 2, default: JSON.string("default")) == JSON.string("default"))
  #expect(arr.value(at: -1, default: JSON.number(.integer(0))) == JSON.number(.integer(0)))
}

@Test func valueIndexNonArray() {
  let scalar = JSON.string("hello")
  #expect(scalar.value(at: 0, default: JSON.number(.integer(42))) == JSON.number(.integer(42)))
}

@Test func valueIndexEmptyArray() {
  let arr = JSON.array([])
  #expect(arr.value(at: 0, default: JSON.string("default")) == JSON.string("default"))
}

@Test func valueIndexSentinelDefault() {
  let sentinel = JSON.object(["marker": JSON.boolean(true)])
  let arr = JSON.array([JSON.string("a")])
  let result = arr.value(at: 99, default: sentinel)
  // Verify the returned value is equal to the sentinel, not a default
  // that coincidentally equals another value.
  #expect(result == sentinel)
  #expect(result["marker"] == JSON.boolean(true))
}

// MARK: - Dynamic member lookup

@Test func dynamicMemberGetObjectKey() {
  let obj = JSON.object([
    "user": JSON.object(["name": JSON.string("Alice"), "age": JSON.number(.integer(30))]),
    "role": JSON.string("admin"),
  ])
  // Dot-notation access
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

@Test func dynamicMemberMissingKeyReturnsNull() {
  let obj = JSON.object(["a": JSON.string("x")])
  #expect(obj.missing == .null)
}

@Test func dynamicMemberNonObjectReturnsNull() {
  let scalar = JSON.number(.integer(42))
  #expect(scalar.foo == .null)
  let arr = JSON.array([JSON.string("a")])
  #expect(arr.nonexistent == .null)
}

@Test func dynamicMemberSet() {
  var obj = JSON.object(["a": JSON.number(.integer(1))])
  obj.b = JSON.number(.integer(2))
  #expect(obj.a == JSON.number(.integer(1)))
  #expect(obj.b == JSON.number(.integer(2)))
}

@Test func dynamicMemberSetNonObjectNoop() {
  var scalar = JSON.number(.integer(42))
  scalar.foo = JSON.string("bar")
  #expect(scalar == JSON.number(.integer(42)))
}

@Test func dynamicMemberSetOverwrites() {
  var obj = JSON.object(["x": JSON.number(.integer(1))])
  obj.x = JSON.number(.integer(2))
  #expect(obj.x == JSON.number(.integer(2)))
}

// MARK: - Array contains Tests

@Test func arrayContainsExistingElement() {
  let arr = JSON.array([
    JSON.string("a"),
    JSON.number(.integer(1)),
    JSON.boolean(true),
  ])
  #expect(arr.contains(element: JSON.string("a")))
  #expect(arr.contains(element: JSON.number(.integer(1))))
  #expect(arr.contains(element: JSON.boolean(true)))
}

@Test func arrayContainsMissingElement() {
  let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
  #expect(!arr.contains(element: JSON.string("b")))
  #expect(!arr.contains(element: JSON.number(.integer(2))))
}

@Test func arrayContainsOnNonArrayReturnsFalse() {
  let scalar = JSON.string("hello")
  #expect(!scalar.contains(element: JSON.string("hello")))
}

@Test func arrayContainsEmptyArray() {
  let arr = JSON.array([])
  #expect(!arr.contains(element: JSON.string("a")))
}

@Test func arrayContainsNestedArray() {
  let nested = JSON.array([JSON.array([JSON.number(.integer(1))])])
  #expect(nested.contains(element: JSON.array([JSON.number(.integer(1))])))
  #expect(!nested.contains(element: JSON.array([JSON.number(.integer(2))])))
}

@Test func arrayContainsCrossType() {
  let arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
  #expect(!arr.contains(element: JSON.number(.integer(2))))  // different value, same type
  #expect(!arr.contains(element: JSON.boolean(true)))  // different type entirely
}

@Test func arrayContainsDuplicate() {
  let arr = JSON.array([
    JSON.string("a"),
    JSON.string("b"),
    JSON.string("a"),
  ])
  #expect(arr.contains(element: JSON.string("a")))  // appears at indices 0 and 2
  #expect(arr.contains(element: JSON.string("b")))  // appears once
  #expect(!arr.contains(element: JSON.string("c")))
}
