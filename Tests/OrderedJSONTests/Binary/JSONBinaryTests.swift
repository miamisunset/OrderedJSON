import Foundation
import Testing

@testable import OrderedJSON

// MARK: - CBOR Tests

@Test func cborRoundTripNull() throws {
  let json = JSON.null
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func cborRoundTripBool() throws {
  let json = JSON.boolean(true)
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func cborRoundTripBoolFalse() throws {
  let json = JSON.boolean(false)
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func cborRoundTripInteger() throws {
  let json = JSON.number(.integer(42))
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func cborRoundTripFloat() throws {
  let json = JSON.number(.float(3.14))
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func cborRoundTripString() throws {
  let json = JSON.string("hello")
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func cborRoundTripArray() throws {
  let json = JSON.array([
    JSON.number(.integer(1)), JSON.number(.integer(2)), JSON.number(.integer(3)),
  ])
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func cborRoundTripObject() throws {
  let json = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func cborNegativeInteger() throws {
  let json = JSON.number(.integer(-42))
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func cborLargeInteger() throws {
  let json = JSON.number(.integer(100_000))
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func cborTrailingBytes() throws {
  let json = JSON.number(.integer(1))
  let data = json.toCBOR()
  var trailing = data
  trailing.append(0x00)
  #expect(throws: JSONError.self) {
    try JSON.fromCBOR(trailing)
  }
}

// MARK: - MessagePack Tests

@Test func msgPackRoundTripNull() throws {
  let json = JSON.null
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackRoundTripBool() throws {
  let json = JSON.boolean(true)
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackRoundTripBoolFalse() throws {
  let json = JSON.boolean(false)
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackRoundTripInteger() throws {
  let json = JSON.number(.integer(42))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackRoundTripFloat() throws {
  let json = JSON.number(.float(3.14))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackRoundTripString() throws {
  let json = JSON.string("hello")
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackRoundTripArray() throws {
  let json = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackRoundTripObject() throws {
  let json = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackNegativeInteger() throws {
  let json = JSON.number(.integer(-42))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackLargeInteger() throws {
  let json = JSON.number(.integer(100_000))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackTrailingBytes() throws {
  let json = JSON.number(.integer(1))
  let data = json.toMsgPack()
  var trailing = data
  trailing.append(0x00)
  #expect(throws: JSONError.self) {
    try JSON.fromMsgPack(trailing)
  }
}

// MARK: - UBJSON Tests

@Test func ubjsonRoundTripNull() throws {
  let json = JSON.null
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func ubjsonRoundTripBool() throws {
  let json = JSON.boolean(true)
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func ubjsonRoundTripBoolFalse() throws {
  let json = JSON.boolean(false)
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func ubjsonRoundTripInteger() throws {
  let json = JSON.number(.integer(42))
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func ubjsonRoundTripFloat() throws {
  let json = JSON.number(.float(3.14))
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func ubjsonRoundTripString() throws {
  let json = JSON.string("hello")
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func ubjsonRoundTripArray() throws {
  let json = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func ubjsonRoundTripObject() throws {
  let json = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func ubjsonNegativeInteger() throws {
  let json = JSON.number(.integer(-42))
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func ubjsonLargeInteger() throws {
  let json = JSON.number(.integer(100_000))
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func ubjsonTrailingBytes() throws {
  let json = JSON.number(.integer(1))
  let data = json.toUBJSON()
  var trailing = data
  trailing.append(0x00)
  #expect(throws: JSONError.self) {
    try JSON.fromUBJSON(trailing)
  }
}

// MARK: - BSON Tests

@Test func bsonRoundTripNull() throws {
  let json = JSON.null
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  #expect(decoded["value"] == json)
}

@Test func bsonRoundTripBool() throws {
  let json = JSON.boolean(true)
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  // BSON wraps non-object values in a {"value": ...} document
  #expect(decoded["value"] == json)
}

@Test func bsonRoundTripBoolFalse() throws {
  let json = JSON.boolean(false)
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  #expect(decoded["value"] == json)
}

@Test func bsonRoundTripInteger() throws {
  let json = JSON.number(.integer(42))
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  #expect(decoded["value"] == json)
}

@Test func bsonRoundTripFloat() throws {
  let json = JSON.number(.float(3.14))
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  #expect(decoded["value"] == json)
}

@Test func bsonRoundTripString() throws {
  let json = JSON.string("hello")
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  #expect(decoded["value"] == json)
}

@Test func bsonRoundTripArray() throws {
  let json = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  // BSON wraps arrays as embedded document with numeric keys
  let expected = JSON.object(["0": JSON.number(.integer(1)), "1": JSON.number(.integer(2))])
  #expect(decoded == expected)
}

@Test func bsonRoundTripObject() throws {
  let json = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  #expect(decoded == json)
}

@Test func bsonNegativeInteger() throws {
  let json = JSON.number(.integer(-42))
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  #expect(decoded["value"] == json)
}

@Test func bsonLargeInteger() throws {
  let json = JSON.number(.integer(100_000))
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  #expect(decoded["value"] == json)
}

@Test func bsonTrailingBytes() throws {
  let json = JSON.number(.integer(1))
  let data = json.toBSON()
  var trailing = data
  trailing.append(0x00)
  #expect(throws: JSONError.self) {
    try JSON.fromBSON(trailing)
  }
}

// MARK: - BJData Tests

@Test func bjdataRoundTripNull() throws {
  let json = JSON.null
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}

@Test func bjdataRoundTripBool() throws {
  let json = JSON.boolean(true)
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}

@Test func bjdataRoundTripBoolFalse() throws {
  let json = JSON.boolean(false)
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}

@Test func bjdataRoundTripInteger() throws {
  let json = JSON.number(.integer(42))
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}

@Test func bjdataRoundTripFloat() throws {
  let json = JSON.number(.float(3.14))
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}

@Test func bjdataRoundTripString() throws {
  let json = JSON.string("hello")
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}

@Test func bjdataRoundTripArray() throws {
  let json = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}

@Test func bjdataRoundTripObject() throws {
  let json = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}

@Test func bjdataNegativeInteger() throws {
  let json = JSON.number(.integer(-42))
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}

@Test func bjdataLargeInteger() throws {
  let json = JSON.number(.integer(100_000))
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}

@Test func bjdataTrailingBytes() throws {
  let json = JSON.number(.integer(1))
  let data = json.toBJData()
  var trailing = data
  trailing.append(0x00)
  #expect(throws: JSONError.self) {
    try JSON.fromBJData(trailing)
  }
}

// MARK: - Cross-format consistency

@Test func cborLargeNegative() throws {
  let json = JSON.number(.integer(-1_000_000))
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

@Test func msgPackLargeNegative() throws {
  let json = JSON.number(.integer(-1_000_000))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func ubjsonLargeNegative() throws {
  let json = JSON.number(.integer(-1_000_000))
  let data = json.toUBJSON()
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == json)
}

@Test func bsonLargeNegative() throws {
  let json = JSON.number(.integer(-1_000_000))
  let data = json.toBSON()
  let decoded = try JSON.fromBSON(data)
  #expect(decoded["value"] == json)
}

@Test func bjdataLargeNegative() throws {
  let json = JSON.number(.integer(-1_000_000))
  let data = json.toBJData()
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == json)
}
