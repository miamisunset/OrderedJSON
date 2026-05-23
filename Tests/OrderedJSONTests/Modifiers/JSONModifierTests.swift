import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - JSONClear Tests

@Test func clearObject() throws {
  var obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
  obj.clear()
  #expect(obj.isObject)
  #expect(obj.isEmpty)
}

@Test func clearArray() throws {
  var arr = JSON.array([JSON.string("a"), JSON.number(.integer(1))])
  arr.clear()
  #expect(arr.isArray)
  #expect(arr.isEmpty)
}

@Test func clearScalarNoop() throws {
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

@Test func eraseKey() throws {
  var obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
  obj.erase("a")
  #expect(obj.count == 1)
  #expect(obj["a"] == nil)
  #expect(obj["b"] == JSON.number(.integer(1)))
}

@Test func eraseKeyNonObject() throws {
  var arr = JSON.array([JSON.string("a")])
  arr.erase("key")  // silently ignored
  #expect(arr.count == 1)
}

@Test func eraseKeyMissing() throws {
  var obj = JSON.object(["a": JSON.string("x")])
  obj.erase("missing")
  #expect(obj.count == 1)
}

@Test func eraseIndex() throws {
  var arr = JSON.array([JSON.string("a"), JSON.number(.integer(1)), JSON.boolean(true)])
  arr.erase(1)
  #expect(arr.count == 2)
  #expect(arr[0] == JSON.string("a"))
  #expect(arr[1] == JSON.boolean(true))
}

@Test func eraseIndexOutOfBounds() throws {
  var arr = JSON.array([JSON.string("a")])
  arr.erase(5)  // silently ignored
  #expect(arr.count == 1)
  arr.erase(-1)  // silently ignored
  #expect(arr.count == 1)
}

@Test func eraseIndexNonArray() throws {
  var obj = JSON.object(["a": JSON.string("x")])
  obj.erase(0)  // silently ignored
  #expect(obj.count == 1)
}

@Test func appendToArray() throws {
  var arr = JSON.array([JSON.string("a")])
  arr.append(JSON.number(.integer(42)))
  #expect(arr.count == 2)
  #expect(arr[1] == JSON.number(.integer(42)))
}

@Test func appendToNonArray() throws {
  var str = JSON.string("hello")
  str.append(JSON.number(.integer(42)))  // silently ignored
  #expect(str == JSON.string("hello"))
}

@Test func insertAtIndex() throws {
  var arr = JSON.array([JSON.string("a"), JSON.string("c")])
  arr.insert(JSON.string("b"), at: 1)
  #expect(arr.count == 3)
  #expect(arr[0] == JSON.string("a"))
  #expect(arr[1] == JSON.string("b"))
  #expect(arr[2] == JSON.string("c"))
}

@Test func insertOutOfBounds() throws {
  var arr = JSON.array([JSON.string("a")])
  arr.insert(JSON.string("b"), at: 5)  // silently ignored
  #expect(arr.count == 1)
}

@Test func insertNonArray() throws {
  var obj = JSON.object(["a": JSON.string("x")])
  obj.insert(JSON.string("b"), at: 0)  // silently ignored
  #expect(obj.count == 1)
}

@Test func emplaceArray() throws {
  var arr = JSON.array([JSON.string("a")])
  arr.emplace(JSON.number(.integer(42)))
  #expect(arr.count == 2)
  #expect(arr[1] == JSON.number(.integer(42)))
}

@Test func emplaceArrayNonArray() throws {
  var str = JSON.string("hello")
  str.emplace(JSON.number(.integer(42)))  // silently ignored
  #expect(str == JSON.string("hello"))
}

@Test func emplaceObjectNewKey() throws {
  var obj = JSON.object(["a": JSON.string("x")])
  obj.emplace(key: "b", default: JSON.number(.integer(42)))
  #expect(obj.count == 2)
  #expect(obj["b"] == JSON.number(.integer(42)))
}

@Test func emplaceObjectExistingKey() throws {
  var obj = JSON.object(["a": JSON.string("x")])
  obj.emplace(key: "a", default: JSON.number(.integer(99)))
  #expect(obj.count == 1)
  #expect(obj["a"] == JSON.string("x"))
}

@Test func emplaceObjectNonObject() throws {
  var str = JSON.string("hello")
  str.emplace(key: "a", default: JSON.number(.integer(42)))  // silently ignored
  #expect(str == JSON.string("hello"))
}

@Test func updateObject() throws {
  var obj = JSON.object(["a": JSON.string("x")])
  let other = JSON.object(["b": JSON.number(.integer(42)), "a": JSON.string("new")])
  obj.update(with: other)
  #expect(obj.count == 2)
  #expect(obj["a"] == JSON.string("new"))
  #expect(obj["b"] == JSON.number(.integer(42)))
}

@Test func updateNonObjectTarget() throws {
  var str = JSON.string("hello")
  let other = JSON.object(["a": JSON.string("x")])
  str.update(with: other)  // silently ignored
  #expect(str == JSON.string("hello"))
}

@Test func updateWithNonObjectSource() throws {
  var obj = JSON.object(["a": JSON.string("x")])
  let other = JSON.string("not object")
  obj.update(with: other)  // silently ignored
  #expect(obj.count == 1)
}

@Test func swapValues() throws {
  var a = JSON.string("hello")
  var b = JSON.number(.integer(42))
  a.swap(with: &b)
  #expect(a == JSON.number(.integer(42)))
  #expect(b == JSON.string("hello"))
}

// MARK: - maxCount

@Test func maxSize() {
  #expect(JSON.null.maxCount == Int.max)
}
