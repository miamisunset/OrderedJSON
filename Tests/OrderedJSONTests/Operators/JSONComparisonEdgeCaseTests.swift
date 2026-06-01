import Foundation
import Testing

@testable import OrderedJSON

@Suite("Comparison Edge Case Tests") struct JSONComparisonEdgeCaseTests {

  // MARK: - NaN behavior

  @Test("NaN equality — NaN != NaN per IEEE 754")
  func nanEquality() {
    let nan = JSON.number(.float(Double.nan))
    #expect(nan != nan)
  }

  @Test("NaN less-than — NaN is unordered")
  func nanLessThan() {
    let nan = JSON.number(.float(Double.nan))
    let zero = JSON.number(.float(0.0))
    let one = JSON.number(.integer(1))

    #expect((nan < nan) == false)
    #expect((nan < zero) == false)
    #expect((zero < nan) == false)
    #expect((nan < one) == false)
    #expect((one < nan) == false)
  }

  @Test("NaN less-than-or-equal — NaN is unordered")
  func nanLessThanOrEqual() {
    let nan = JSON.number(.float(Double.nan))
    let zero = JSON.number(.float(0.0))

    #expect((nan <= nan) == false)
    #expect((nan <= zero) == false)
    #expect((zero <= nan) == false)
  }

  @Test("NaN greater-than — NaN is unordered")
  func nanGreaterThan() {
    let nan = JSON.number(.float(Double.nan))
    let zero = JSON.number(.float(0.0))

    #expect((nan > nan) == false)
    #expect((nan > zero) == false)
    #expect((zero > nan) == false)
  }

  @Test("NaN greater-than-or-equal — NaN is unordered")
  func nanGreaterThanOrEqual() {
    let nan = JSON.number(.float(Double.nan))
    let zero = JSON.number(.float(0.0))

    #expect((nan >= nan) == false)
    #expect((nan >= zero) == false)
    #expect((zero >= nan) == false)
  }

  // MARK: - Cross-type comparisons

  @Test("cross-type boolean vs number — boolean < number per type hierarchy")
  func crossTypeBoolVsNumber() {
    let boolTrue = JSON.boolean(true)
    let boolFalse = JSON.boolean(false)
    let num = JSON.number(.integer(0))

    #expect(boolTrue < num)  // boolean < number
    #expect(!(num < boolTrue))  // number < boolean is false
    #expect(!(boolTrue > num))  // boolean > number is false
    #expect(num > boolTrue)  // number > boolean
    #expect(boolTrue <= num)  // boolean <= number
    #expect(!(num <= boolTrue))  // number <= boolean is false
    #expect(!(boolTrue >= num))  // boolean >= number is false
    #expect(num >= boolTrue)  // number >= boolean

    #expect(boolFalse < num)  // boolean(false) < number
    #expect(!(num < boolFalse))  // number < boolean(false) is false
  }

  @Test("cross-type number vs string — number < string per type hierarchy")
  func crossTypeNumberVsString() {
    let num = JSON.number(.integer(42))
    let str = JSON.string("hello")

    #expect(num < str)  // number < string
    #expect(!(str < num))  // string < number is false
    #expect(!(num > str))  // number > string is false
    #expect(str > num)  // string > number
    #expect(num <= str)  // number <= string
    #expect(!(str <= num))  // string <= number is false
    #expect(!(num >= str))  // number >= string is false
    #expect(str >= num)  // string >= number
  }

  @Test("cross-type string vs object — object < string per type hierarchy")
  func crossTypeStringVsObject() {
    let str = JSON.string("hello")
    let obj = JSON.object(["key": JSON.string("val")])

    #expect(obj < str)  // object < string
    #expect(!(str < obj))  // string < object is false
  }

  @Test("cross-type array vs null — null is less than everything")
  func crossTypeNullVsArray() {
    let nullVal = JSON.null
    let arr = JSON.array([JSON.number(.integer(1))])

    #expect(nullVal < arr)
    #expect((arr < nullVal) == false)
  }

  // MARK: - Comparable consistency

  @Test("comparable consistency — a < b implies !(b < a)")
  func comparableConsistencyLessThan() {
    let values: [JSON] = [
      .null,
      .boolean(false),
      .boolean(true),
      .number(.integer(0)),
      .number(.integer(1)),
      .number(.float(2.0)),
      .string("a"),
      .string("b"),
      .array([.number(.integer(1))]),
      .array([.number(.integer(1)), .number(.integer(2))]),
      .object(["a": .number(.integer(1))]),
      .object(["a": .number(.integer(1)), "b": .number(.integer(2))]),
    ]

    for i in 0..<values.count {
      for j in 0..<values.count {
        let a = values[i]
        let b = values[j]
        if a < b {
          #expect(!(b < a))
        }
      }
    }
  }

  @Test("comparable consistency — a < a is always false")
  func comparableConsistencySelfComparison() {
    let values: [JSON] = [
      .null,
      .boolean(false),
      .boolean(true),
      .number(.integer(0)),
      .number(.float(Double.nan)),
      .number(.float(1.5)),
      .string(""),
      .string("hello"),
      .array([]),
      .array([.number(.integer(1))]),
      .object([:]),
      .object(["k": .string("v")]),
    ]

    for v in values {
      #expect(!(v < v))
    }
  }

  @Test("comparable consistency — a == b implies !(a < b)")
  func comparableConsistencyEqualNotLess() {
    let values: [JSON] = [
      .null,
      .boolean(false),
      .boolean(true),
      .number(.integer(0)),
      .number(.float(0.0)),
      .string("a"),
      .array([.number(.integer(1))]),
      .object(["k": .string("v")]),
    ]

    for i in 0..<values.count {
      for j in 0..<values.count {
        let a = values[i]
        let b = values[j]
        if a == b {
          #expect(!(a < b))
        }
      }
    }
  }

  // MARK: - Array element-wise comparison

  @Test("array element-wise — same prefix, different length")
  func arrayElementWiseDifferentLength() {
    let short = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    let long = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2)), JSON.number(.integer(3))])

    #expect(short < long)
    #expect(!(long < short))
    #expect(long > short)
    #expect(!(short > long))
  }

  @Test("array element-wise — same prefix, first differing element decides")
  func arrayElementWiseFirstDifference() {
    let a = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    let b = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(3))])

    #expect(a < b)
    #expect(!(b < a))
  }

  @Test("array element-wise — mixed type elements use type hierarchy")
  func arrayElementWiseMixedTypes() {
    let a = JSON.array([JSON.number(.integer(1)), JSON.boolean(true)])
    let b = JSON.array([JSON.number(.integer(1)), JSON.string("x")])

    // boolean(1) < string(5) per type hierarchy, so a < b
    #expect(a < b)
    #expect(!(b < a))
  }

  @Test("array element-wise — equal arrays are not less")
  func arrayElementWiseEqual() {
    let a = JSON.array([JSON.number(.integer(1)), JSON.string("x")])
    let b = JSON.array([JSON.number(.integer(1)), JSON.string("x")])

    #expect(!(a < b))
    #expect(!(b < a))
  }

  @Test("array element-wise — empty arrays are equal")
  func arrayElementWiseEmpty() {
    let empty1 = JSON.array([])
    let empty2 = JSON.array([])

    #expect(!(empty1 < empty2))
    #expect(!(empty2 < empty1))
  }

  // MARK: - Object key-value comparison

  @Test("object key-value — same keys, different values")
  func objectKeyValueDifferentValues() {
    let a = JSON.object(["a": JSON.number(.integer(1))])
    let b = JSON.object(["a": JSON.number(.integer(2))])

    #expect(a < b)
    #expect(!(b < a))
  }

  @Test("object key-value — different keys sort and compare")
  func objectKeyValueDifferentKeys() {
    let a = JSON.object(["a": JSON.number(.integer(1))])
    let b = JSON.object(["b": JSON.number(.integer(1))])

    // "a" < "b" so a < b
    #expect(a < b)
    #expect(!(b < a))
  }

  @Test("object key-value — superset keys use count comparison")
  func objectKeyValueSupersetKeys() {
    let small = JSON.object(["a": JSON.number(.integer(1))])
    let big = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.number(.integer(2))])

    #expect(small < big)
    #expect(!(big < small))
  }

  @Test("object key-value — equal objects are not less")
  func objectKeyValueEqual() {
    let a = JSON.object(["a": JSON.number(.integer(1))])
    let b = JSON.object(["a": JSON.number(.integer(1))])

    #expect(!(a < b))
    #expect(!(b < a))
  }

  @Test("object key-value — empty objects are equal")
  func objectKeyValueEmpty() {
    let empty1 = JSON.object([:])
    let empty2 = JSON.object([:])

    #expect(!(empty1 < empty2))
    #expect(!(empty2 < empty1))
  }

  // MARK: - Type ordering
  func typeOrdering() {
    #expect(JSON.null < JSON.boolean(true))
    #expect(JSON.boolean(false) < JSON.number(.integer(0)))
    #expect(JSON.number(.integer(0)) < JSON.object([:]))
    #expect(JSON.object([:]) < JSON.array([]))
    #expect(JSON.array([]) < JSON.string(""))

    // Reverse direction
    #expect(!(JSON.boolean(true) < JSON.null))
    #expect(!(JSON.number(.integer(0)) < JSON.boolean(true)))
    #expect(!(JSON.object([:]) < JSON.number(.integer(0))))
    #expect(!(JSON.array([]) < JSON.object([:])))
    #expect(!(JSON.string("") < JSON.array([])))
  }

  @Test("cross-type — all type pairs respect hierarchy")
  func crossTypeAllPairs() {
    let types: [(JSON, String)] = [
      (.null, "null"),
      (.boolean(false), "boolean"),
      (.number(.integer(0)), "number"),
      (.object([:]), "object"),
      (.array([]), "array"),
      (.string(""), "string"),
    ]

    for i in 0..<types.count {
      for j in 0..<types.count {
        let a = types[i].0
        let b = types[j].0
        if i < j {
          #expect(a < b, "\(types[i].1) < \(types[j].1) should be true")
          #expect(!(b < a), "\(types[j].1) < \(types[i].1) should be false")
        } else if i == j {
          #expect(!(a < b), "\(types[i].1) < \(types[i].1) should be false")
        } else {
          #expect(!(a < b), "\(types[i].1) < \(types[j].1) should be false")
          #expect(b < a, "\(types[j].1) < \(types[i].1) should be true")
        }
      }
    }
  }
}

@Suite("Sequence Edge Case Tests") struct JSONSequenceEdgeCaseTests {

  @Test("sequence empty array yields no elements")
  func emptyArray() {
    var count = 0
    for _ in JSON.array([]) {
      count += 1
    }
    #expect(count == 0)
  }

  @Test("sequence empty object yields no elements")
  func emptyObject() {
    var count = 0
    for _ in JSON.object([:]) {
      count += 1
    }
    #expect(count == 0)
  }

  @Test("sequence single element scalar")
  func singleScalar() {
    let vals: [JSON] = [
      .null,
      .boolean(true),
      .boolean(false),
      .number(.integer(42)),
      .number(.float(Double.nan)),
      .string("hello"),
    ]

    for v in vals {
      var collected: [JSON] = []
      for element in v {
        collected.append(element)
      }
      #expect(collected.count == 1)
      // NaN != NaN per IEEE 754, so check NaN via pattern matching
      if case .number(.float(let d)) = v.storage, d.isNaN {
        #expect(collected[0].isFloat)
        #expect(collected[0].doubleValue?.isNaN == true)
      } else {
        #expect(collected[0] == v)
      }
    }
  }

  @Test("iterator exhaustion after partial iteration")
  func partialIterationThenExhaustion() {
    let arr = JSON.array([.string("a"), .string("b"), .string("c")])
    var iter = arr.makeIterator()

    #expect(iter.next() == JSON.string("a"))
    var iter2 = arr.makeIterator()
    #expect(iter2.next() == JSON.string("a"))
    #expect(iter2.next() == JSON.string("b"))
    #expect(iter2.next() == JSON.string("c"))
    #expect(iter2.next() == nil)
    #expect(iter2.next() == nil)
  }

  @Test("keyValuePairs on non-object returns empty")
  func keyValuePairsNonObject() {
    #expect(JSON.null.keyValuePairs().isEmpty)
    #expect(JSON.boolean(true).keyValuePairs().isEmpty)
    #expect(JSON.number(.integer(0)).keyValuePairs().isEmpty)
    #expect(JSON.string("").keyValuePairs().isEmpty)
    #expect(JSON.array([]).keyValuePairs().isEmpty)
  }

  @Test("keyValuePairs preserves order")
  func keyValuePairsOrder() {
    let obj = JSON.object([
      "z": .number(.integer(3)),
      "a": .number(.integer(1)),
      "m": .number(.integer(2)),
    ])
    let pairs = obj.keyValuePairs()
    #expect(pairs.count == 3)
    #expect(pairs[0].key == "z")
    #expect(pairs[1].key == "a")
    #expect(pairs[2].key == "m")
  }

  @Test("sequence for-in with break still works on re-iteration")
  func sequenceBreakAndReiterate() {
    let arr = JSON.array([.string("a"), .string("b"), .string("c")])
    var count = 0
    for _ in arr {
      count += 1
      break
    }
    #expect(count == 1)

    var count2 = 0
    for _ in arr {
      count2 += 1
    }
    #expect(count2 == 3)
  }
}
