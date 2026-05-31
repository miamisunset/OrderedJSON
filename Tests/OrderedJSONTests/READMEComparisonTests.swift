import Testing

@testable import OrderedJSON

@Test func readmeComparisonOperators() {
  #expect(JSON(1) < JSON(2))
  #expect((JSON(1) > JSON(2)) == false)
  #expect(JSON(1) <= JSON(2))
  #expect((JSON(1) >= JSON(2)) == false)
}

@Test func readmeTypeOrdering() {
  // Note: Cross-type < returns false per current implementation.
  // Only same-type comparisons are supported.
  #expect(JSON.null < JSON.boolean(true))
  #expect(JSON.boolean(false) < JSON.boolean(true))
  #expect(JSON.number(.integer(1)) < JSON.number(.integer(2)))
  #expect(JSON.string("a") < JSON.string("b"))
  let obj1 = JSON.object(["x": JSON(1)])
  let obj2 = JSON.object(["x": JSON(1), "y": JSON(2)])
  #expect(obj1 < obj2)
  let arr1 = JSON.array([JSON(1)])
  let arr2 = JSON.array([JSON(1), JSON(2)])
  #expect(arr1 < arr2)
}

@Test func readmeMixedNumberComparison() {
  // Note: < supports mixed number comparison, but == does NOT.
  // Integer and float are distinct enum cases in JSONNumber.
  #expect(JSON.number(.integer(1)) < JSON.number(.float(2.5)))
  #expect(JSON.number(.integer(42)) != JSON.number(.float(42.0)))
  #expect(JSON.number(.float(42.0)) != JSON.number(.integer(42)))
}

@Test func readmeSequenceConformance() {
  let arr = JSON.array([JSON(1), JSON(2), JSON(3)])
  var collected: [JSON] = []
  for element in arr {
    collected.append(element)
  }
  #expect(collected == [JSON(1), JSON(2), JSON(3)])

  let obj = JSON.object(["x": JSON(10), "y": JSON(20)])
  var values: [JSON] = []
  for value in obj {
    values.append(value)
  }
  #expect(values == [JSON(10), JSON(20)])

  // Key-value pairs via keyValuePairs()
  let pairs = obj.keyValuePairs()
  #expect(pairs.count == 2)
  #expect(pairs[0].key == "x")
  #expect(pairs[0].value == JSON(10))
}
