import Foundation
import Testing
import OrderedCollections

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

// MARK: - MessagePack Edge Cases

@Test func msgPackEmptyData() throws {
  #expect(throws: JSONError.self) { try JSON.fromMsgPack(Data()) }
}

@Test func msgPackNegativeFixInt() throws {
  let json = JSON.number(.integer(-10))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackUInt8() throws {
  let json = JSON.number(.integer(200))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackUInt16() throws {
  let json = JSON.number(.integer(1000))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackUInt64Positive() throws {
  let json = JSON.number(.integer(Int64(UInt32.max) + 1))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackInt16() throws {
  let json = JSON.number(.integer(-200))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackInt64() throws {
  let json = JSON.number(.integer(Int64(Int32.min) - 1))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackFloat32() throws {
  let json = JSON.number(.float(1.5))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackString32Plus() throws {
  // String with length 32-255 (uses 0xD9 marker)
  let s = String(repeating: "x", count: 100)
  let json = JSON.string(s)
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackLargeArray16() throws {
  // Build raw bytes for a 16-element array (0xDC marker)
  var bytes: [UInt8] = [0xDC, 0x00, 0x10] // array of 16
  for _ in 0..<16 {
    bytes.append(0x2A) // 42 encoded as positive fixint
  }
  let data = Data(bytes)
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded.isArray)
  #expect(decoded.count == 16)
}

@Test func msgPackLargeArray32() throws {
  // Build raw bytes for array with 0xDD marker (3 elements)
  var bytes: [UInt8] = [0xDD, 0x00, 0x00, 0x00, 0x03] // array of 3
  for _ in 0..<3 {
    bytes.append(0x2A)
  }
  let data = Data(bytes)
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded.isArray)
  #expect(decoded.count == 3)
}

@Test func msgPackLargeMap16() throws {
  // Build raw bytes for a map with 0xDE marker (2 entries)
  var bytes: [UInt8] = [0xDE, 0x00, 0x02]
  // key "a", value 1
    bytes.append(0xA1)
    bytes.append(0x61) // "a"
    bytes.append(0x01)
  // key "b", value 2
    bytes.append(0xA1)
    bytes.append(0x62) // "b"
    bytes.append(0x02)
  let data = Data(bytes)
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded.isObject)
  #expect(decoded.count == 2)
}

@Test func msgPackLargeMap32() throws {
  // Build raw bytes for a map with 0xDF marker (1 entry)
  var bytes: [UInt8] = [0xDF, 0x00, 0x00, 0x00, 0x01]
  bytes.append(0xA1)
  bytes.append(0x61) // "a"
  bytes.append(0x01)
  let data = Data(bytes)
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded.isObject)
  #expect(decoded["a"] == JSON.number(.integer(1)))
}

@Test func msgPackString8() throws {
  // Build raw bytes for string with 0xD9 marker (len=32)
  var bytes: [UInt8] = [0xD9, 32]
  for _ in 0..<32 { bytes.append(0x61) } // "a" * 32
  let data = Data(bytes)
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == JSON.string(String(repeating: "a", count: 32)))
}

@Test func msgPackString16() throws {
  // Build raw bytes for string with 0xDA marker (len=256)
  var bytes: [UInt8] = [0xDA, 0x01, 0x00]
  for _ in 0..<256 { bytes.append(0x61) }
  let data = Data(bytes)
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == JSON.string(String(repeating: "a", count: 256)))
}

@Test func msgPackString32() throws {
  // Build raw bytes for string with 0xDB marker (len=100)
  var bytes: [UInt8] = [0xDB, 0x00, 0x00, 0x00, 0x64]
  for _ in 0..<100 { bytes.append(0x61) }
  let data = Data(bytes)
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == JSON.string(String(repeating: "a", count: 100)))
}

@Test func msgPackUnknownType() throws {
  let data = Data([0xC1]) // 0xC1 is unused in MsgPack spec
  #expect(throws: JSONError.self) { try JSON.fromMsgPack(data) }
}

@Test func msgPackInvalidUTF8() throws {
  // String with invalid UTF-8 continuation byte
  let bytes: [UInt8] = [0xA1, 0xFF]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromMsgPack(data) }
}

@Test func msgPackNonStringMapKey() throws {
  // Map where key is an integer (0x01) instead of a string
  let data = Data([0x81, 0x01, 0x03])
  #expect(throws: JSONError.self) { try JSON.fromMsgPack(data) }
}

@Test func msgPackEncodeUInt8() throws {
  let json = JSON.number(.integer(128))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackEncodeUInt16() throws {
  let json = JSON.number(.integer(256))
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackEncodeLargeArray() throws {
  var arr: [JSON] = []
  for idx in 0..<20 { arr.append(JSON.number(.integer(Int64(idx)))) }
  let json = JSON.array(arr)
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackEncodeLargeObject() throws {
  var dict = OrderedDictionary<String, JSON>()
  for idx in 0..<20 { dict["k\(idx)"] = JSON.number(.integer(Int64(idx))) }
  let json = JSON.object(dict)
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackEncodeLongString() throws {
  let s = String(repeating: "x", count: 50)
  let json = JSON.string(s)
  let data = json.toMsgPack()
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded == json)
}

@Test func msgPackBinTypes() throws {
  // Binary 0xC4 (8-bit length)
  let bin1 = Data([0xC4, 3, 0x61, 0x62, 0x63])
  let decoded1 = try JSON.fromMsgPack(bin1)
  #expect(decoded1.isString)

  // Binary 0xC5 (16-bit length)
  let bin2 = Data([0xC5, 0x00, 0x03, 0x61, 0x62, 0x63])
  let decoded2 = try JSON.fromMsgPack(bin2)
  #expect(decoded2.isString)

  // Binary 0xC6 (32-bit length)
  let bin3 = Data([0xC6, 0x00, 0x00, 0x00, 0x03, 0x61, 0x62, 0x63])
  let decoded3 = try JSON.fromMsgPack(bin3)
  #expect(decoded3.isString)
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
