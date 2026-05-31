import Testing

@testable import OrderedJSON

@Suite("Comparison Tests") struct JSONComparisonTests {
  @Test("comparison less than null") func comparisonLessThanNull() {
    #expect(JSON.null < JSON.boolean(true))
    #expect(JSON.null < JSON.number(.integer(0)))
    #expect(JSON.null < JSON.string(""))
    #expect((JSON.null < JSON.null) == false)
  }

  @Test("comparison less than boolean") func comparisonLessThanBoolean() {
    #expect(JSON.boolean(false) < JSON.boolean(true))
    #expect((JSON.boolean(true) < JSON.boolean(false)) == false)
    #expect((JSON.boolean(false) < JSON.null) == false)
  }

  @Test("comparison less than integer") func comparisonLessThanInteger() {
    #expect(JSON.number(.integer(1)) < JSON.number(.integer(2)))
    #expect((JSON.number(.integer(2)) < JSON.number(.integer(1))) == false)
    #expect((JSON.number(.integer(1)) < JSON.number(.integer(1))) == false)
  }

  @Test("comparison less than float") func comparisonLessThanFloat() {
    #expect(JSON.number(.float(1.5)) < JSON.number(.float(2.5)))
    #expect((JSON.number(.float(2.5)) < JSON.number(.float(1.5))) == false)
  }

  @Test("comparison mixed number") func comparisonMixedNumber() {
    #expect(JSON.number(.integer(1)) < JSON.number(.float(2.0)))
    #expect(JSON.number(.float(1.0)) < JSON.number(.integer(2)))
    #expect((JSON.number(.integer(3)) < JSON.number(.float(2.0))) == false)
  }

  @Test("comparison less than string") func comparisonLessThanString() {
    #expect(JSON.string("a") < JSON.string("b"))
    #expect((JSON.string("b") < JSON.string("a")) == false)
    #expect((JSON.string("a") < JSON.string("a")) == false)
  }

  @Test("comparison array by count") func comparisonArrayByCount() {
    let small = JSON.array([JSON.string("a")])
    let large = JSON.array([JSON.string("a"), JSON.string("b")])
    #expect(small < large)
    #expect((large < small) == false)
  }

  @Test("comparison object by count") func comparisonObjectByCount() {
    let small = JSON.object(["a": JSON.string("x")])
    let large = JSON.object(["a": JSON.string("x"), "b": JSON.string("y")])
    #expect(small < large)
    #expect((large < small) == false)
  }

  @Test("comparison greater than") func comparisonGreaterThan() {
    #expect(JSON.number(.integer(2)) > JSON.number(.integer(1)))
    #expect((JSON.number(.integer(1)) > JSON.number(.integer(2))) == false)
  }

  @Test("comparison greater than or equal") func comparisonGreaterThanOrEqual() {
    #expect(JSON.number(.integer(2)) >= JSON.number(.integer(1)))
    #expect(JSON.number(.integer(2)) >= JSON.number(.integer(2)))
    #expect((JSON.number(.integer(1)) >= JSON.number(.integer(2))) == false)
  }

  @Test("comparison less than or equal") func comparisonLessThanOrEqual() {
    #expect(JSON.number(.integer(1)) <= JSON.number(.integer(2)))
    #expect(JSON.number(.integer(2)) <= JSON.number(.integer(2)))
    #expect((JSON.number(.integer(3)) <= JSON.number(.integer(2))) == false)
  }

  @Test("comparable conformance — sorted() works")
  func comparableSorted() {
    let values: [JSON] = [
      .number(.integer(3)),
      .number(.integer(1)),
      .number(.integer(2)),
    ]
    let sorted = values.sorted()
    #expect(sorted == [.number(.integer(1)), .number(.integer(2)), .number(.integer(3))])
  }

  @Test("comparable conformance — max/min work")
  func comparableMaxMin() {
    let values: [JSON] = [
      .number(.integer(1)),
      .number(.integer(5)),
      .number(.integer(3)),
    ]
    #expect(values.max() == .number(.integer(5)))
    #expect(values.min() == .number(.integer(1)))
  }
}
