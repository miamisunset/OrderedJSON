import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Phase 9 Edge Cases: Accessors and Subscripts

@Suite("Access Edge Case Tests") struct JSONAccessEdgeCaseTests {

  // MARK: - subscript[key: String] setter with nil

  @Test("set nil on non-object is silent no-op")
  func subscriptSetNilOnNonObject() {
    var str = JSON.string("hello")
    str["key"] = nil
    #expect(str == JSON.string("hello"))

    var arr = JSON.array([JSON.number(.integer(1))])
    arr["key"] = nil
    #expect(arr == JSON.array([JSON.number(.integer(1))]))
  }

  @Test("set nil removes key from object")
  func subscriptSetNilRemovesKey() {
    var obj = JSON.object(["a": JSON.string("x"), "b": JSON.number(.integer(1))])
    obj["a"] = nil
    #expect(obj["a"] == nil)
    #expect(obj.count == 1)
    #expect(obj["b"] == JSON.number(.integer(1)))
  }

  @Test("removing last key produces empty object, not null")
  func subscriptSetNilLastKey() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj["a"] = nil
    #expect(obj["a"] == nil)
    #expect(obj.count == 0)
    #expect(obj.isEmpty)
    #expect(obj.isObject)
    #expect(obj.isNull == false)
    #expect(obj.type == .object)
  }

  @Test("set nil on missing key is no-op")
  func subscriptSetNilMissingKey() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj["nonexistent"] = nil
    #expect(obj.count == 1)
    #expect(obj["a"] == JSON.string("x"))
  }

  @Test("set nil then add key reuses object")
  func subscriptSetNilThenAdd() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj["a"] = nil
    #expect(obj.count == 0)
    obj["b"] = JSON.number(.integer(2))
    #expect(obj.count == 1)
    #expect(obj["b"] == JSON.number(.integer(2)))
  }

  // MARK: - @dynamicMemberLookup setter edge cases

  @Test("dynamicMember set on non-object is silent no-op")
  func dynamicMemberSetOnNonObject() {
    var scalar = JSON.number(.integer(42))
    scalar.foo = JSON.string("bar")
    #expect(scalar == JSON.number(.integer(42)))

    var arr = JSON.array([JSON.boolean(true)])
    arr.x = JSON.null
    #expect(arr == JSON.array([JSON.boolean(true)]))
  }

  @Test("dynamicMember set on null is silent no-op")
  func dynamicMemberSetOnNull() {
    var nullVal = JSON.null
    nullVal.key = JSON.string("value")
    #expect(nullVal == JSON.null)
  }

  @Test("dynamicMember set adds new key")
  func dynamicMemberSetAddsNewKey() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj.b = JSON.number(.integer(1))
    #expect(obj.b == JSON.number(.integer(1)))
    #expect(obj.count == 2)
  }

  @Test("dynamicMember set overwrites existing key")
  func dynamicMemberSetOverwrites() {
    var obj = JSON.object(["a": JSON.string("x")])
    obj.a = JSON.number(.integer(1))
    #expect(obj.a == JSON.number(.integer(1)))
    #expect(obj.count == 1)
  }

  @Test("dynamicMember get on non-object returns null")
  func dynamicMemberGetOnNonObject() {
    let arr = JSON.array([JSON.string("a")])
    #expect(arr.nonexistent == .null)

    let num = JSON.number(.integer(42))
    #expect(num.foo == .null)

    let bool = JSON.boolean(true)
    #expect(bool.anything == .null)

    let nullVal = JSON.null
    #expect(nullVal.missing == .null)
  }

  // MARK: - intValue / doubleValue NaN and Infinity

  @Test("intValue on NaN returns nil")
  func intValueOnNaN() {
    let nan = JSON.number(.float(Double.nan))
    #expect(nan.intValue == nil)
  }

  @Test("intValue on Infinity returns nil")
  func intValueOnInfinity() {
    let inf = JSON.number(.float(Double.infinity))
    #expect(inf.intValue == nil)
  }

  @Test("intValue on negative infinity returns nil")
  func intValueOnNegativeInfinity() {
    let ninf = JSON.number(.float(-Double.infinity))
    #expect(ninf.intValue == nil)
  }

  @Test("intValue on clean float returns integer")
  func intValueOnCleanFloat() {
    let clean = JSON.number(.float(1.0))
    #expect(clean.intValue == Int64(1))
  }

  @Test("intValue on float with fractional part returns nil")
  func intValueOnFractionalFloat() {
    let fractional = JSON.number(.float(1.5))
    #expect(fractional.intValue == nil)
  }

  @Test("intValue on large float beyond Int64 range returns nil")
  func intValueOnOutOfRangeFloat() {
    let large = JSON.number(.float(Double(Int64.max) * 2.0))
    #expect(large.intValue == nil)
  }

  @Test("doubleValue on NaN returns NaN")
  func doubleValueOnNaN() {
    let nan = JSON.number(.float(Double.nan))
    #expect(nan.doubleValue != nil)
    #expect(nan.doubleValue!.isNaN)
  }

  @Test("doubleValue on infinity returns infinity")
  func doubleValueOnInfinity() {
    let inf = JSON.number(.float(Double.infinity))
    #expect(inf.doubleValue != nil)
    #expect(inf.doubleValue!.isInfinite)
  }

  @Test("doubleValue on negative infinity returns negative infinity")
  func doubleValueOnNegativeInfinity() {
    let ninf = JSON.number(.float(-Double.infinity))
    #expect(ninf.doubleValue != nil)
    #expect(ninf.doubleValue!.isInfinite)
    #expect(ninf.doubleValue! < 0)
  }

  @Test("doubleValue on integer widens to Double")
  func doubleValueOnInteger() {
    let int = JSON.number(.integer(42))
    #expect(int.doubleValue == Double(42))
  }

  @Test("doubleValue on large integer preserves value")
  func doubleValueOnLargeInteger() {
    let large = JSON.number(.integer(Int64.max))
    #expect(large.doubleValue == Double(Int64.max))
  }

  @Test("doubleValue on non-number returns nil")
  func doubleValueOnNonNumber() {
    #expect(JSON.string("hello").doubleValue == nil)
    #expect(JSON.boolean(true).doubleValue == nil)
    #expect(JSON.null.doubleValue == nil)
    #expect(JSON.object([:]).doubleValue == nil)
    #expect(JSON.array([]).doubleValue == nil)
  }

  @Test("intValue on non-number returns nil")
  func intValueOnNonNumber() {
    #expect(JSON.string("hello").intValue == nil)
    #expect(JSON.boolean(true).intValue == nil)
    #expect(JSON.null.intValue == nil)
    #expect(JSON.object([:]).intValue == nil)
    #expect(JSON.array([]).intValue == nil)
  }

  // MARK: - requireFloat() / requireDouble() NaN and Infinity

  @Test("requireDouble on NaN returns NaN")
  func requireDoubleOnNaN() throws {
    let nan = JSON.number(.float(Double.nan))
    let result = try nan.requireDouble()
    #expect(result.isNaN)
  }

  @Test("requireDouble on infinity returns infinity")
  func requireDoubleOnInfinity() throws {
    let inf = JSON.number(.float(Double.infinity))
    let result = try inf.requireDouble()
    #expect(result.isInfinite)
    #expect(result > 0)
  }

  @Test("requireDouble on negative infinity returns negative infinity")
  func requireDoubleOnNegativeInfinity() throws {
    let ninf = JSON.number(.float(-Double.infinity))
    let result = try ninf.requireDouble()
    #expect(result.isInfinite)
    #expect(result < 0)
  }

  @Test("requireDouble on integer widens")
  func requireDoubleOnInteger() throws {
    let int = JSON.number(.integer(42))
    let result = try int.requireDouble()
    #expect(result == 42.0)
  }

  @Test("requireDouble on non-number throws")
  func requireDoubleOnNonNumberThrows() throws {
    #expect(throws: JSONError.self) { try JSON.string("hello").requireDouble() }
    #expect(throws: JSONError.self) { try JSON.boolean(true).requireDouble() }
    #expect(throws: JSONError.self) { try JSON.null.requireDouble() }
    #expect(throws: JSONError.self) { try JSON.object([:]).requireDouble() }
    #expect(throws: JSONError.self) { try JSON.array([]).requireDouble() }
  }

  @Test("requireFloat on NaN throws")
  func requireFloatOnNaN() throws {
    let nan = JSON.number(.float(Double.nan))
    #expect(throws: JSONError.self) { try nan.requireFloat() }
  }

  @Test("requireFloat on infinity throws")
  func requireFloatOnInfinity() throws {
    let inf = JSON.number(.float(Double.infinity))
    #expect(throws: JSONError.self) { try inf.requireFloat() }
  }

  @Test("requireFloat on negative infinity throws")
  func requireFloatOnNegativeInfinity() throws {
    let ninf = JSON.number(.float(-Double.infinity))
    #expect(throws: JSONError.self) { try ninf.requireFloat() }
  }

  @Test("requireFloat on subnormal double throws")
  func requireFloatOnSubnormal() throws {
    let subnormal = JSON.number(.float(Double.leastNonzeroMagnitude))
    #expect(throws: JSONError.self) { try subnormal.requireFloat() }
  }

  @Test("requireFloat on integer succeeds")
  func requireFloatOnInteger() throws {
    let int = JSON.number(.integer(42))
    let result = try int.requireFloat()
    #expect(result == 42.0)
  }

  @Test("requireFloat on non-number throws")
  func requireFloatOnNonNumberThrows() throws {
    #expect(throws: JSONError.self) { try JSON.string("hello").requireFloat() }
    #expect(throws: JSONError.self) { try JSON.boolean(true).requireFloat() }
    #expect(throws: JSONError.self) { try JSON.null.requireFloat() }
    #expect(throws: JSONError.self) { try JSON.object([:]).requireFloat() }
    #expect(throws: JSONError.self) { try JSON.array([]).requireFloat() }
  }

  @Test("requireFloat on representable double succeeds")
  func requireFloatOnRepresentableDouble() throws {
    let d = JSON.number(.float(Double(3.14)))
    // 3.14 is not exactly representable as Float, so Float(exactly:) fails
    #expect(throws: JSONError.self) { try d.requireFloat() }
  }

  @Test("requireFloat on exactly representable double succeeds")
  func requireFloatOnExactDouble() throws {
    let exact = JSON.number(.float(Double(1.0)))
    let result = try exact.requireFloat()
    #expect(result == 1.0)
  }

  // MARK: - Additional subscript edge cases

  @Test("key subscript get on empty object")
  func keySubscriptGetOnEmptyObject() {
    let obj = JSON.object([:])
    #expect(obj["any"] == nil)
  }

  @Test("index subscript get on empty array")
  func indexSubscriptGetOnEmptyArray() {
    let arr = JSON.array([])
    #expect(arr[0] == nil)
    #expect(arr[-1] == nil)
  }

  @Test("index subscript set on empty array is no-op")
  func indexSubscriptSetOnEmptyArray() {
    var arr = JSON.array([])
    arr[0] = JSON.string("a")
    #expect(arr.count == 0)
    arr[0] = nil
    #expect(arr.count == 0)
  }

  @Test("key subscript set value on empty object adds key")
  func keySubscriptSetOnEmptyObject() {
    var obj = JSON.object([:])
    obj["key"] = JSON.number(.integer(1))
    #expect(obj["key"] == JSON.number(.integer(1)))
    #expect(obj.count == 1)
  }
}
