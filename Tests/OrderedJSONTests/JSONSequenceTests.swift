import Testing

@testable import OrderedJSON

@Test func sequenceArray() {
  let arr = JSON.array([
    JSON.string("a"),
    JSON.number(.integer(1)),
    JSON.boolean(true),
  ])
  var collected: [JSON] = []
  for element in arr {
    collected.append(element)
  }
  #expect(collected.count == 3)
  #expect(collected[0] == JSON.string("a"))
  #expect(collected[1] == JSON.number(.integer(1)))
  #expect(collected[2] == JSON.boolean(true))
}

@Test func sequenceObject() {
  let obj = JSON.object([
    "a": JSON.string("x"),
    "b": JSON.number(.integer(1)),
  ])
  var collected: [JSON] = []
  for element in obj {
    collected.append(element)
  }
  // Sequence over an object yields each value (key-value pair as JSON? No — let me check)
  // Actually our Sequence iterator for objects uses the dictionary iterator which yields (key, value) pairs
  // But the IteratorProtocol next() returns JSON? — we need to handle this
  // For objects, each element is a JSON value from the dict
  #expect(collected.count == 2)
  #expect(collected[0] == JSON.string("x"))
  #expect(collected[1] == JSON.number(.integer(1)))
}

@Test func sequenceScalar() {
  let scalar = JSON.string("hello")
  var collected: [JSON] = []
  for element in scalar {
    collected.append(element)
  }
  #expect(collected.count == 1)
  #expect(collected[0] == JSON.string("hello"))
}

@Test func sequenceNull() {
  var collected: [JSON] = []
  for element in JSON.null {
    collected.append(element)
  }
  #expect(collected.count == 1)
  #expect(collected[0] == JSON.null)
}

@Test func sequenceEmptyArray() {
  let arr = JSON.array([])
  var collected: [JSON] = []
  for element in arr {
    collected.append(element)
  }
  #expect(collected.isEmpty)
}

@Test func sequenceEmptyObject() {
  let obj = JSON.object([:])
  var collected: [JSON] = []
  for element in obj {
    collected.append(element)
  }
  #expect(collected.isEmpty)
}

@Test func itemsObject() {
  let obj = JSON.object([
    "a": JSON.string("x"),
    "b": JSON.number(.integer(1)),
  ])
  let items = obj.items()
  #expect(items.count == 2)
  #expect(items[0].key == "a")
  #expect(items[0].value == JSON.string("x"))
  #expect(items[1].key == "b")
  #expect(items[1].value == JSON.number(.integer(1)))
}

@Test func itemsNonObject() {
  #expect(JSON.string("hello").items().isEmpty)
  #expect(JSON.array([]).items().isEmpty)
  #expect(JSON.null.items().isEmpty)
}

@Test func itemsEmptyObject() {
  let items = JSON.object([:]).items()
  #expect(items.isEmpty)
}

@Test func iteratorExhaustion() {
  // Test that calling next() after exhaustion returns nil (covers .empty case)
  var iter = JSON.array([JSON.string("a"), JSON.string("b")]).makeIterator()
  #expect(iter.next() == JSON.string("a"))
  #expect(iter.next() == JSON.string("b"))
  #expect(iter.next() == nil)

  var objIter = JSON.object(["k": JSON.string("v")]).makeIterator()
  #expect(objIter.next() == JSON.string("v"))
  #expect(objIter.next() == nil)

  var scalarIter = JSON.number(.integer(1)).makeIterator()
  #expect(scalarIter.next() == JSON.number(.integer(1)))
  #expect(scalarIter.next() == nil)
}
