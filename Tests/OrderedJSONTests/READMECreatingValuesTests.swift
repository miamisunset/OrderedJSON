import Testing

@testable import OrderedJSON

@Test func readmeCreatingValues() {
  // Factory methods
  let str = JSON.string("hello")
  let num = JSON.number(.integer(42))
  let flt = JSON.number(.float(3.14))
  let bool = JSON.boolean(true)
  let nul = JSON.null
  let nul2 = JSON.null

  #expect(str.isString)
  #expect(num.isNumber)
  #expect(flt.isNumber)
  #expect(bool.isBoolean)
  #expect(nul.isNull)
  #expect(nul2.isNull)

  // Convenience initializers
  let s = JSON("hello")
  let n = JSON(42)
  let x = JSON(3.14)
  let b = JSON(true)

  #expect(s.isString)
  #expect(n.isInteger)
  #expect(x.isFloat)
  #expect(b.isBoolean)

  // Arrays
  let arr = JSON.array([
    JSON.string("a"),
    JSON.number(.integer(1)),
    JSON.boolean(false),
    JSON.null,
  ])
  #expect(arr.isArray)
  #expect(arr.count == 4)

  // Objects
  let obj = JSON.object([
    "name": JSON.string("Alice"),
    "age": JSON.number(.integer(30)),
    "city": JSON.string("New York"),
  ])
  #expect(obj.isObject)
  #expect(obj.count == 3)
}
