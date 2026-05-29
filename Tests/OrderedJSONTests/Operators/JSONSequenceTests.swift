import Testing

@testable import OrderedJSON

@Suite("Sequence Tests") struct JSONSequenceTests {
  @Test("sequence array") func sequenceArray() {
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

  @Test("sequence object") func sequenceObject() {
    let obj = JSON.object([
      "a": JSON.string("x"),
      "b": JSON.number(.integer(1)),
    ])
    var collected: [JSON] = []
    for element in obj {
      collected.append(element)
    }
    #expect(collected.count == 2)
    #expect(collected[0] == JSON.string("x"))
    #expect(collected[1] == JSON.number(.integer(1)))
  }

  @Test("sequence scalar") func sequenceScalar() {
    let scalar = JSON.string("hello")
    var collected: [JSON] = []
    for element in scalar {
      collected.append(element)
    }
    #expect(collected.count == 1)
    #expect(collected[0] == JSON.string("hello"))
  }

  @Test("sequence null") func sequenceNull() {
    var collected: [JSON] = []
    for element in JSON.null {
      collected.append(element)
    }
    #expect(collected.count == 1)
    #expect(collected[0] == JSON.null)
  }

  @Test("sequence empty array") func sequenceEmptyArray() {
    let arr = JSON.array([])
    var collected: [JSON] = []
    for element in arr {
      collected.append(element)
    }
    #expect(collected.isEmpty)
  }

  @Test("sequence empty object") func sequenceEmptyObject() {
    let obj = JSON.object([:])
    var collected: [JSON] = []
    for element in obj {
      collected.append(element)
    }
    #expect(collected.isEmpty)
  }

  @Test("iterator exhaustion") func iteratorExhaustion() {
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
}

@Suite("Key Value Pairs Tests") struct JSONKeyValuePairsTests {
  @Test("key value pairs object") func keyValuePairsObject() {
    let obj = JSON.object([
      "a": JSON.string("x"),
      "b": JSON.number(.integer(1)),
    ])
    let items = obj.keyValuePairs()
    #expect(items.count == 2)
    #expect(items[0].key == "a")
    #expect(items[0].value == JSON.string("x"))
    #expect(items[1].key == "b")
    #expect(items[1].value == JSON.number(.integer(1)))
  }

  @Test("key value pairs non object") func keyValuePairsNonObject() {
    #expect(JSON.string("hello").keyValuePairs().isEmpty)
    #expect(JSON.array([]).keyValuePairs().isEmpty)
    #expect(JSON.null.keyValuePairs().isEmpty)
  }

  @Test("key value pairs empty object") func keyValuePairsEmptyObject() {
    let items = JSON.object([:]).keyValuePairs()
    #expect(items.isEmpty)
  }
}
