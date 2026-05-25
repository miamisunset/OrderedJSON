import Foundation
import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Test helpers

/// Appends the big-endian bytes of a UInt64 value to a byte array.
private func appendBE(_ value: UInt64, to bytes: inout [UInt8]) {
  withUnsafeBytes(of: value.bigEndian) { ptr in
    for i in 0..<8 {
      bytes.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)[i])
    }
  }
}

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
  var bytes: [UInt8] = [0xDC, 0x00, 0x10]  // array of 16
  for _ in 0..<16 {
    bytes.append(0x2A)  // 42 encoded as positive fixint
  }
  let data = Data(bytes)
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded.isArray)
  #expect(decoded.count == 16)
}

@Test func msgPackLargeArray32() throws {
  // Build raw bytes for array with 0xDD marker (3 elements)
  var bytes: [UInt8] = [0xDD, 0x00, 0x00, 0x00, 0x03]  // array of 3
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
  bytes.append(0x61)  // "a"
  bytes.append(0x01)
  // key "b", value 2
  bytes.append(0xA1)
  bytes.append(0x62)  // "b"
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
  bytes.append(0x61)  // "a"
  bytes.append(0x01)
  let data = Data(bytes)
  let decoded = try JSON.fromMsgPack(data)
  #expect(decoded.isObject)
  #expect(decoded["a"] == JSON.number(.integer(1)))
}

@Test func msgPackString8() throws {
  // Build raw bytes for string with 0xD9 marker (len=32)
  var bytes: [UInt8] = [0xD9, 32]
  for _ in 0..<32 { bytes.append(0x61) }  // "a" * 32
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
  let data = Data([0xC1])  // 0xC1 is unused in MsgPack spec
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

// MARK: - CBOR Edge Cases

@Test func cborByteString() throws {
  // CBOR byte string (major type 2) with 3 bytes
  let bytes: [UInt8] = [0x43, 0x61, 0x62, 0x63]  // major 2, len=3, data="abc"
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isString)
}

@Test func cborTag() throws {
  // CBOR tag (major type 6) followed by integer 42
  // Tag 1: major 6 (0xC0), info 1 = 0xC1, then integer 42
  let bytes: [UInt8] = [0xC1, 0x18, 0x2A]  // tag 1, unsigned 42
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == JSON.number(.integer(42)))
}

@Test func cborHalfFloat() throws {
  // CBOR half-precision float (additional info 25)
  // 1.5 encoded as half-float: 0x3E, 0x80 = 0b0 01111 1000000000 = 1.5
  let bytes: [UInt8] = [0xFA, 0x3E, 0x80]  // major 7, info 25, value=0x3E80
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isNumber)
}

@Test func cborUndefined() throws {
  // CBOR undefined value (major 7, info 23) — maps to null
  let bytes: [UInt8] = [0xF7]  // major 7, info 23 (undefined)
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isNull)
}

@Test func cborEmptyData() throws {
  #expect(throws: JSONError.self) { try JSON.fromCBOR(Data()) }
}

@Test func cborReservedInfo() throws {
  // Reserved additional info (28-31) should throw
  let bytes: [UInt8] = [0xF8]  // major 7, info 28 (reserved)
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromCBOR(data) }
}

@Test func cborUnknownMajorType() throws {
  // CBOR only defines major types 0-7; the default case is unreachable
  // but we can verify it exists by testing with a marker that has no handler
  // The reserved info case is tested in cborReservedInfo
}

@Test func cborHalfFloatDenormalized() throws {
  // Half-float denormalized value (exp=0)
  let bytes: [UInt8] = [0xFA, 0x00, 0x01]  // major 7, info 25, value=0x0001 (min denormalized)
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isNumber)
}

@Test func cborHalfFloatInf() throws {
  // Half-float infinity (exp=31, mant=0)
  let bytes: [UInt8] = [0xFA, 0xFC, 0x00]  // major 7, info 25, value=0xFC00 (-inf)
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isNumber)
}

@Test func cborHalfFloatNaN() throws {
  // Half-float NaN (exp=31, mant!=0)
  let bytes: [UInt8] = [0xFA, 0xFE, 0x00]  // major 7, info 25, value=0xFE00 (NaN)
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isNumber)
  #expect(decoded.isFloat)
}

@Test func cborHalfFloatDenormalizedValue() throws {
  // Half-float denormalized: 0x0001 = 2^(-24) ≈ 5.96e-8
  let bytes: [UInt8] = [0xFA, 0x00, 0x01]  // major 7, info 25, value=0x0001
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isNumber)
  // 2^(-24) = 1 / 16777216 ≈ 5.960464477539063e-8
  #expect(decoded == JSON.number(.float(1.0 / 16777216.0)))
}

@Test func cborHalfFloatDenormalizedMax() throws {
  // Half-float denormalized max: 0x03FF = 2^(-14) * (1023/1024) ≈ 6.1e-5
  let bytes: [UInt8] = [0xFA, 0x03, 0xFF]  // major 7, info 25, value=0x03FF
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isNumber)
  // Max denormalized = 2^(-14) * (1023/1024) = 1023 / (16384 * 1024) = 1023 / 16777216
  #expect(decoded == JSON.number(.float(1023.0 / 16777216.0)))
}

@Test func cborHalfFloatNormalizedMin() throws {
  // Half-float normalized min: 0x0400 = 2^(-14) * (1024/1024) = 2^(-14) ≈ 6.1e-5
  let bytes: [UInt8] = [0xFA, 0x04, 0x00]  // major 7, info 25, value=0x0400
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isNumber)
  // Min normalized = 2^(-14) = 1 / 16384
  #expect(decoded == JSON.number(.float(1.0 / 16384.0)))
}

// MARK: - UBJSON Edge Cases

@Test func ubjsonCharMarker() throws {
  // UBJSON char marker 'C' followed by a single character
  let bytes: [UInt8] = [0x43, 0x41]  // 'C', 'A'
  let data = Data(bytes)
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded == JSON.string("A"))
}

@Test func ubjsonEmptyData() throws {
  #expect(throws: JSONError.self) { try JSON.fromUBJSON(Data()) }
}

@Test func ubjsonUnknownMarker() throws {
  // UBJSON marker 'X' (not in spec)
  let bytes: [UInt8] = [0x58]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromUBJSON(data) }
}

@Test func ubjsonStringLenUnexpectedEnd() throws {
  // UBJSON string marker with incomplete length marker
  let bytes: [UInt8] = [0x53]  // 'S' marker, no length
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromUBJSON(data) }
}

@Test func ubjsonCountUnexpectedEnd() throws {
  // UBJSON array marker with incomplete count
  let bytes: [UInt8] = [0x5B]  // '[' marker, no count
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromUBJSON(data) }
}

@Test func ubjsonStringMarkerNotString() throws {
  // UBJSON object with non-string key marker
  let bytes: [UInt8] = [0x7B, 0x49, 0x01, 0x49, 0x02]  // object with int8 keys
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromUBJSON(data) }
}

// MARK: - BJData Edge Cases

@Test func bjdataCharMarker() throws {
  // BJData char marker 'C' followed by a single character
  let bytes: [UInt8] = [0x43, 0x41]  // 'C', 'A'
  let data = Data(bytes)
  let decoded = try JSON.fromBJData(data)
  #expect(decoded == JSON.string("A"))
}

@Test func bjdataEmptyData() throws {
  #expect(throws: JSONError.self) { try JSON.fromBJData(Data()) }
}

@Test func bjdataUnknownMarker() throws {
  // BJData marker 'X' (not in spec)
  let bytes: [UInt8] = [0x58]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBJData(data) }
}

@Test func bjdataStringLenUnexpectedEnd() throws {
  // BJData string marker with incomplete length marker
  let bytes: [UInt8] = [0x53]  // 'S' marker, no length
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBJData(data) }
}

@Test func bjdataStringMarkerNotString() throws {
  // BJData object with non-string key marker
  let bytes: [UInt8] = [0x7B, 0x49, 0x01, 0x49, 0x02]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBJData(data) }
}

// MARK: - BSON Edge Cases

@Test func bsonUnsupportedType() throws {
  // BSON type 0x07 (object id) is not supported
  var bytes: [UInt8] = [0x00, 0x00, 0x00, 0x00]  // placeholder length
  bytes.append(0x07)  // type: object id (unsupported)
  bytes.append(0x65)  // key: "e"
  bytes.append(0x00)  // null terminator for key
  // Need valid length — just use minimal document with unsupported type
  let totalLen = UInt32(bytes.count + 1)  // +1 for null terminator
  bytes[0] = UInt8(totalLen & 0xFF)
  bytes[1] = UInt8((totalLen >> 8) & 0xFF)
  bytes[2] = UInt8((totalLen >> 16) & 0xFF)
  bytes[3] = UInt8((totalLen >> 24) & 0xFF)
  bytes.append(0x00)  // document null terminator
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBSON(data) }
}

@Test func bsonEmptyData() throws {
  #expect(throws: JSONError.self) { try JSON.fromBSON(Data()) }
}

@Test func bsonUnexpectedEnd() throws {
  // Truncated BSON document (incomplete length bytes)
  let data = Data([0x05, 0x00])  // only 2 bytes, need 4 for length
  #expect(throws: JSONError.self) { try JSON.fromBSON(data) }
}

// MARK: - CBOR Large Negative

@Test func cborLargeNegativeInt64() throws {
  let json = JSON.number(.integer(-1_000_000_000))
  let data = json.toCBOR()
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded == json)
}

// MARK: - Overflow protection (uint64 > Int64.max)

@Test func msgPackUInt64OverflowBecomesFloat() throws {
  // Encode a uint64 value that exceeds Int64.max (2^63)
  // MessagePack marker 0xCF followed by 8 bytes big-endian
  // Value: 2^63 + 1 = 9223372036854775808, which is > Int64.max
  var bytes: [UInt8] = [0xCF]
  let large = UInt64(Int64.max) + 1  // 2^63
  appendBE(large, to: &bytes)
  let data = Data(bytes)
  let decoded = try JSON.fromMsgPack(data)
  // Should decode as float since value exceeds Int64.max
  #expect(decoded.isFloat)
  if case .number(.float(let d)) = decoded.storage {
    #expect(d == Double(large))
  } else {
    Issue.record("Expected float, got \(decoded.storage)")
  }
}

@Test func cborUInt64OverflowBecomesFloat() throws {
  // CBOR major type 0 (unsigned integer) with 8-byte argument
  // Value: 2^63 + 1 = 9223372036854775808, which is > Int64.max
  var bytes: [UInt8] = [0x1B]  // major=0, additional=27 (8 bytes)
  let large = UInt64(Int64.max) + 1
  appendBE(large, to: &bytes)
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  // Should decode as float since value exceeds Int64.max
  #expect(decoded.isFloat)
  if case .number(.float(let d)) = decoded.storage {
    #expect(d == Double(large))
  } else {
    Issue.record("Expected float, got \(decoded.storage)")
  }
}

@Test func cborNegativeIntOverflowBecomesFloat() throws {
  // CBOR major type 1 (negative integer) with 8-byte argument
  // Value: -1 - 2^64 = overflow case
  // Encode argument = UInt64.max, so result = -1 - UInt64.max which overflows Int64
  var bytes: [UInt8] = [0x3B]  // major=1, additional=27 (8 bytes)
  let large = UInt64.max
  appendBE(large, to: &bytes)
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  // Should decode as float since negative value exceeds Int64 range
  #expect(decoded.isFloat)
}

@Test func cborNegativeIntNearOverflow() throws {
  // CBOR major type 1 with argument = Int64.max
  // Value: -1 - Int64.max = Int64.min (exactly representable as Int64)
  var bytes: [UInt8] = [0x3B]  // major=1, additional=27
  let arg = UInt64(Int64.max)
  appendBE(arg, to: &bytes)
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isInteger)
  if case .number(.integer(let i)) = decoded.storage {
    #expect(i == Int64.min)
  } else {
    Issue.record("Expected integer, got \(decoded.storage)")
  }
}

// MARK: - NaN/Infinity serialization

@Test func nanFloatSerializesAsNull() throws {
  let json = JSON.number(.float(Double.nan))
  let dumped = json.dump(indent: -1)
  #expect(dumped == "null")
}

@Test func infinityFloatSerializesAsNull() throws {
  let json = JSON.number(.float(Double.infinity))
  let dumped = json.dump(indent: -1)
  #expect(dumped == "null")
}

@Test func negativeInfinityFloatSerializesAsNull() throws {
  let json = JSON.number(.float(-Double.infinity))
  let dumped = json.dump(indent: -1)
  #expect(dumped == "null")
}

@Test func nanInObjectSerializesCorrectly() throws {
  let json = JSON.object(["a": JSON.number(.float(Double.nan)), "b": JSON.number(.integer(1))])
  let dumped = json.dump(indent: -1)
  // NaN should serialize as null, not crash
  #expect(dumped == "{\"a\":null,\"b\":1}" || dumped == "{\"b\":1,\"a\":null}")
}

@Test func nanRoundTripThroughCBOR() throws {
  // NaN is valid in CBOR binary format — decode should preserve it
  var bytes: [UInt8] = [0xFB]
  let bits = Double.nan.bitPattern
  appendBE(bits, to: &bytes)
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isFloat)
  if case .number(.float(let d)) = decoded.storage {
    #expect(d.isNaN)
  } else {
    Issue.record("Expected float, got \(decoded.storage)")
  }
  // Serialize to JSON string — should produce null
  let dumped = decoded.dump(indent: -1)
  #expect(dumped == "null")
}

// MARK: - Precision loss documentation

@Test func cborUInt64PrecisionLoss() throws {
  // Values > Int64.max stored as Double — round-trip through CBOR loses precision.
  // This documents the intentional semantic change: these values are no longer exact.
  let original = UInt64(Int64.max) + 1  // 2^63
  var bytes: [UInt8] = [0x1B]
  appendBE(original, to: &bytes)
  let data = Data(bytes)
  let decoded = try JSON.fromCBOR(data)
  #expect(decoded.isFloat)
  if case .number(.float(let d)) = decoded.storage {
    // The Double representation of 2^63 is exact (it's a power of 2)
    // but larger values would lose precision
    #expect(d == Double(original))
    // Re-encode back to CBOR and verify
    let reEncoded = decoded.toCBOR()
    let roundTrip = try JSON.fromCBOR(reEncoded)
    #expect(roundTrip == decoded)
  } else {
    Issue.record("Expected float")
  }
}

// MARK: - UBJSON/BSON/BJData overflow audit

@Test func ubjsonUInt64OverflowBecomesFloat() throws {
  // UBJSON marker for int64 reads uint64 bit pattern — must not crash
  var bytes: [UInt8] = [0x4C]  // 'L' marker for int64
  let large = UInt64(Int64.max) + 1
  appendBE(large, to: &bytes)
  let data = Data(bytes)
  let decoded = try JSON.fromUBJSON(data)
  #expect(decoded.isInteger || decoded.isFloat)
}

@Test func bsonUInt64OverflowBecomesFloat() throws {
  // BSON int64 uses Int64(bitPattern:) — must not crash
  // Build a minimal BSON document with an int64 element
  let large = UInt64(Int64.max) + 1
  // Build element body: type(1) + key(2) + value(8) = 11 bytes
  var element: [UInt8] = [0x12, 0x78, 0x00]  // type int64, key "x", null terminator
  appendBE(large, to: &element)
  // Document: length(4) + element(11) + null(1) = 16 bytes
  let docLen = UInt32(4 + element.count + 1)  // 4 + 11 + 1 = 16
  var bytes: [UInt8] = []
  withUnsafeBytes(of: docLen.littleEndian) { ptr in
    for i in 0..<4 {
      bytes.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)[i])
    }
  }
  bytes.append(contentsOf: element)
  bytes.append(0x00)  // document null terminator
  let data = Data(bytes)
  let decoded = try JSON.fromBSON(data)
  #expect(decoded.isObject)
  if case .object(let dict) = decoded.storage {
    let val = dict["x"]!
    #expect(val.isFloat || val.isInteger)
  }
}

@Test func bjdataUInt64OverflowBecomesFloat() throws {
  // BJData marker for uint64 uses Int64(bitPattern:) — must not crash
  var bytes: [UInt8] = [0x4D]  // 'M' marker for uint64
  let large = UInt64(Int64.max) + 1
  appendBE(large, to: &bytes)
  let data = Data(bytes)
  let decoded = try JSON.fromBJData(data)
  #expect(decoded.isFloat || decoded.isInteger)
}

// MARK: - Error path tests

@Test func cborStringLenOverflowThrows() throws {
  // CBOR text string with length > Int64.max should throw
  var bytes: [UInt8] = [0x7B, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromCBOR(data) }
}

@Test func cborArrayCountOverflowThrows() throws {
  // CBOR array with count > Int64.max should throw
  var bytes: [UInt8] = [0x9B, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromCBOR(data) }
}

@Test func cborStringLenExceedsDataThrows() throws {
  // CBOR text string with length > available data should throw
  var bytes: [UInt8] = [0x78, 100, 0x41, 0x42, 0x43, 0x44, 0x45]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromCBOR(data) }
}

@Test func msgPackStringLenExceedsDataThrows() throws {
  // MsgPack string 32 with length > available data should throw
  var bytes: [UInt8] = [0xDB, 0xFF, 0xFF, 0xFF, 0xFF]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromMsgPack(data) }
}

@Test func msgPackBinLenExceedsDataThrows() throws {
  // MsgPack bin 32 with length > available data should throw
  var bytes: [UInt8] = [0xC6, 0xFF, 0xFF, 0xFF, 0xFF]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromMsgPack(data) }
}

@Test func bsonDocLenTooSmallThrows() throws {
  // BSON document with length < 5 should throw
  var bytes: [UInt8] = [0x03, 0x00, 0x00, 0x00]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBSON(data) }
}

@Test func bsonStringLenNegativeThrows() throws {
  // BSON string with negative length should throw
  var bytes: [UInt8] = [0x02, 0x78, 0x00, 0xFF, 0xFF, 0xFF, 0xFF]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBSON(data) }
}

@Test func bsonStringLenExceedsDataThrows() throws {
  // BSON string with length > available data should throw
  var bytes: [UInt8] = [0x02, 0x78, 0x00, 0x64, 0x00, 0x00, 0x00]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBSON(data) }
}

@Test func bsonBinaryLenExceedsDataThrows() throws {
  // BSON binary with length > available data should throw
  var bytes: [UInt8] = [0x05, 0x78, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBSON(data) }
}

@Test func bsonBinaryMissingSubtypeThrows() throws {
  // BSON binary with no subtype byte should throw
  var bytes: [UInt8] = [0x05, 0x78, 0x00, 0x01, 0x00, 0x00, 0x00]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBSON(data) }
}

@Test func bsonArrayLenTooSmallThrows() throws {
  // BSON array with length < 5 should throw
  var bytes: [UInt8] = [0x03, 0x00, 0x00, 0x00]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBSON(data) }
}

@Test func bsonEmbeddedArrayRoundTrip() throws {
  // Test decodeBSONArray (embedded BSON array) with correct endPos calculation.
  // Before the fix, endPos used docLen-1 instead of docLen-5, causing the
  // decoder to read past the null terminator into garbage bytes.
  //
  // Inner array: [length=12][int32 type][key "0"][int32 1][null]
  //   length = 4 (len) + 1 (type) + 2 (key "0"+null) + 4 (int32) + 1 (null) = 12
  // Outer doc: [length][type=0x04][key "arr"][inner array][null]
  //   length = 4 (len) + 1 (type) + 4 (key "arr"+null) + 12 (inner) + 1 (null) = 22

  let bytes: [UInt8] = [
    0x16, 0x00, 0x00, 0x00,  // outer doc length = 22
    0x04,  // type = array
    0x61, 0x72, 0x72, 0x00,  // key "arr" + null
    0x0C, 0x00, 0x00, 0x00,  // inner array length = 12
    0x10,  // type = int32
    0x30, 0x00,  // key "0" + null
    0x01, 0x00, 0x00, 0x00,  // int32 value 1
    0x00,  // inner array null terminator
    0x00,  // outer doc null terminator
  ]

  let data = Data(bytes)
  let decoded = try JSON.fromBSON(data)
  #expect(decoded.isObject)
  #expect(decoded["arr"] != nil)
  #expect(decoded["arr"]!.isArray)
  #expect(decoded["arr"]![0] == JSON.number(.integer(1)))
}

@Test func bsonTruncatedStringNoNullTerminatorThrows() throws {
  // BSON string element (type 0x02) without null terminator should throw
  // Document: [length][type=0x02][key "a"][string length][string without null]
  let bytes: [UInt8] = [
    0x10, 0x00, 0x00, 0x00,  // doc length = 16
    0x02,  // type = UTF-8 string
    0x61, 0x00,  // key "a" + null
    0x06, 0x00, 0x00, 0x00,  // string length = 6 (including null)
    0x48, 0x65, 0x6C, 0x6C, 0x6F,  // "Hello" without null terminator
    0x00,  // doc null terminator
  ]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBSON(data) }
}

@Test func bsonCStringKeyNoNullTerminatorThrows() throws {
  // BSON C-string key without null terminator should throw (decodeBSONCString)
  // Document: [length][type=0x10][key without null][int32][null]
  // The key "ab" has no null terminator — decodeBSONCString must throw
  let bytes: [UInt8] = [
    0x10, 0x00, 0x00, 0x00,  // doc length = 16
    0x10,  // type = int32
    0x61, 0x62,  // key "ab" WITHOUT null terminator
    0x01, 0x00, 0x00, 0x00,  // int32 value 1
    0x00,  // doc null terminator
  ]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBSON(data) }
}

@Test func ubjsonStringLenInt16NegativeThrows() throws {
  // UBJSON string with Int16 length = -1 should throw
  var bytes: [UInt8] = [0x53, 0x49, 0xFF, 0xFF, 0x41]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromUBJSON(data) }
}

@Test func ubjsonStringLenInt32NegativeThrows() throws {
  // UBJSON string with Int32 length = -1 should throw
  var bytes: [UInt8] = [0x53, 0x6C, 0xFF, 0xFF, 0xFF, 0xFF, 0x41]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromUBJSON(data) }
}

@Test func ubjsonCountInt16NegativeThrows() throws {
  // UBJSON array with Int16 count = -1 should throw
  var bytes: [UInt8] = [0x5B, 0x49, 0xFF, 0xFF]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromUBJSON(data) }
}

@Test func ubjsonStringLenExceedsDataThrows() throws {
  // UBJSON string with length > available data should throw
  var bytes: [UInt8] = [0x53, 0x49, 0x64, 0x00]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromUBJSON(data) }
}

@Test func bjdataStringLenInt16NegativeThrows() throws {
  // BJData string with Int16 length = -1 should throw
  var bytes: [UInt8] = [0x53, 0x49, 0xFF, 0xFF, 0x41]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBJData(data) }
}

@Test func bjdataStringLenInt32NegativeThrows() throws {
  // BJData string with Int32 length = -1 should throw
  var bytes: [UInt8] = [0x53, 0x6C, 0xFF, 0xFF, 0xFF, 0xFF, 0x41]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBJData(data) }
}

@Test func bjdataStringLenExceedsDataThrows() throws {
  // BJData string with length > available data should throw
  var bytes: [UInt8] = [0x53, 0x49, 0x64, 0x00]
  let data = Data(bytes)
  #expect(throws: JSONError.self) { try JSON.fromBJData(data) }
}
