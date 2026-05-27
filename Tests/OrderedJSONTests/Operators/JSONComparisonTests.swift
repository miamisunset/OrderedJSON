@testable import OrderedJSON
import Testing

@Test func comparisonLessThanNull() {
    #expect(JSON.null < JSON.boolean(true))
    #expect(JSON.null < JSON.number(.integer(0)))
    #expect(JSON.null < JSON.string(""))
    #expect(!(JSON.null < JSON.null))
}

@Test func comparisonLessThanBoolean() {
    #expect(JSON.boolean(false) < JSON.boolean(true))
    #expect(!(JSON.boolean(true) < JSON.boolean(false)))
    #expect(!(JSON.boolean(false) < JSON.null))
}

@Test func comparisonLessThanInteger() {
    #expect(JSON.number(.integer(1)) < JSON.number(.integer(2)))
    #expect(!(JSON.number(.integer(2)) < JSON.number(.integer(1))))
    #expect(!(JSON.number(.integer(1)) < JSON.number(.integer(1))))
}

@Test func comparisonLessThanFloat() {
    #expect(JSON.number(.float(1.5)) < JSON.number(.float(2.5)))
    #expect(!(JSON.number(.float(2.5)) < JSON.number(.float(1.5))))
}

@Test func comparisonMixedNumber() {
    #expect(JSON.number(.integer(1)) < JSON.number(.float(2.0)))
    #expect(JSON.number(.float(1.0)) < JSON.number(.integer(2)))
    #expect(!(JSON.number(.integer(3)) < JSON.number(.float(2.0))))
}

@Test func comparisonLessThanString() {
    #expect(JSON.string("a") < JSON.string("b"))
    #expect(!(JSON.string("b") < JSON.string("a")))
    #expect(!(JSON.string("a") < JSON.string("a")))
}

@Test func comparisonArrayByCount() {
    let small = JSON.array([JSON.string("a")])
    let large = JSON.array([JSON.string("a"), JSON.string("b")])
    #expect(small < large)
    #expect(!(large < small))
}

@Test func comparisonObjectByCount() {
    let small = JSON.object(["a": JSON.string("x")])
    let large = JSON.object(["a": JSON.string("x"), "b": JSON.string("y")])
    #expect(small < large)
    #expect(!(large < small))
}

@Test func comparisonGreaterThan() {
    #expect(JSON.number(.integer(2)) > JSON.number(.integer(1)))
    #expect(!(JSON.number(.integer(1)) > JSON.number(.integer(2))))
}

@Test func comparisonGreaterThanOrEqual() {
    #expect(JSON.number(.integer(2)) >= JSON.number(.integer(1)))
    #expect(JSON.number(.integer(2)) >= JSON.number(.integer(2)))
    #expect(!(JSON.number(.integer(1)) >= JSON.number(.integer(2))))
}

@Test func comparisonLessThanOrEqual() {
    #expect(JSON.number(.integer(1)) <= JSON.number(.integer(2)))
    #expect(JSON.number(.integer(2)) <= JSON.number(.integer(2)))
    #expect(!(JSON.number(.integer(3)) <= JSON.number(.integer(2))))
}
