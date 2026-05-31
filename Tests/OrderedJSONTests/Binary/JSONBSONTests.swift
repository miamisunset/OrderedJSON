import Foundation
import Testing

@testable import OrderedJSON

// MARK: - BSON Tests

@Suite("BSON tests")
struct JSONBSONTests {
  @Test("bson round trip null") func bsonRoundTripNull() throws {
    let json = JSON.null
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson round trip bool") func bsonRoundTripBool() throws {
    let json = JSON.boolean(true)
    let data = json.bson()
    let decoded = try JSON(bson: data)
    // BSON wraps non-object values in a {"value": ...} document
    #expect(decoded["value"] == json)
  }

  @Test("bson round trip bool false") func bsonRoundTripBoolFalse() throws {
    let json = JSON.boolean(false)
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson round trip integer") func bsonRoundTripInteger() throws {
    let json = JSON.number(.integer(42))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson round trip float") func bsonRoundTripFloat() throws {
    let json = JSON.number(.float(3.14))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson round trip string") func bsonRoundTripString() throws {
    let json = JSON.string("hello")
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson round trip array") func bsonRoundTripArray() throws {
    let json = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    let data = json.bson()
    let decoded = try JSON(bson: data)
    // BSON wraps arrays as embedded document with numeric keys
    let expected = JSON.object(["0": JSON.number(.integer(1)), "1": JSON.number(.integer(2))])
    #expect(decoded == expected)
  }

  @Test("bson round trip object") func bsonRoundTripObject() throws {
    let json = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded == json)
  }

  @Test("bson negative integer") func bsonNegativeInteger() throws {
    let json = JSON.number(.integer(-42))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson large integer") func bsonLargeInteger() throws {
    let json = JSON.number(.integer(100_000))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson trailing bytes") func bsonTrailingBytes() throws {
    let json = JSON.number(.integer(1))
    let data = json.bson()
    var trailing = data
    trailing.append(0x00)
    #expect(throws: JSONError.self) {
      try JSON(bson: trailing)
    }
  }

  @Test("bson unsupported type") func bsonUnsupportedType() throws {
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
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson empty data") func bsonEmptyData() throws {
    #expect(throws: JSONError.self) { try JSON(bson: Data()) }
  }

  @Test("bson unexpected end") func bsonUnexpectedEnd() throws {
    // Truncated BSON document (incomplete length bytes)
    let data = Data([0x05, 0x00])  // only 2 bytes, need 4 for length
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson large negative") func bsonLargeNegative() throws {
    let json = JSON.number(.integer(-1_000_000))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded["value"] == json)
  }

  @Test("bson doc len too small (throws)") func bsonDocLenTooSmallThrows() throws {
    // BSON document with length < 5 should throw
    let bytes: [UInt8] = [0x03, 0x00, 0x00, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson string len negative (throws)") func bsonStringLenNegativeThrows() throws {
    // BSON string with negative length should throw
    let bytes: [UInt8] = [0x02, 0x78, 0x00, 0xFF, 0xFF, 0xFF, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson string len exceeds data (throws)") func bsonStringLenExceedsDataThrows() throws {
    // BSON string with length > available data should throw
    let bytes: [UInt8] = [0x02, 0x78, 0x00, 0x64, 0x00, 0x00, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson binary len exceeds data (throws)") func bsonBinaryLenExceedsDataThrows() throws {
    // BSON binary with length > available data should throw
    let bytes: [UInt8] = [0x05, 0x78, 0x00, 0x64, 0x00, 0x00, 0x00, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson binary missing subtype (throws)") func bsonBinaryMissingSubtypeThrows() throws {
    // BSON binary with no subtype byte should throw
    let bytes: [UInt8] = [0x05, 0x78, 0x00, 0x01, 0x00, 0x00, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson array len too small (throws)") func bsonArrayLenTooSmallThrows() throws {
    // BSON array with length < 5 should throw
    let bytes: [UInt8] = [0x03, 0x00, 0x00, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson embedded array round trip") func bsonEmbeddedArrayRoundTrip() throws {
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
    let decoded = try JSON(bson: data)
    #expect(decoded.isObject)
    #expect(decoded["arr"] != nil)
    let arr = try #require(decoded["arr"])
    #expect(arr.isArray)
    #expect(decoded["arr"]?[0] == JSON.number(.integer(1)))
  }

  @Test("bson truncated string no null terminator (throws)")
  func bsonTruncatedStringNoNullTerminatorThrows() throws {
    // BSON string element (type 0x02) without null terminator should throw
    // Document: [length][type=0x02][key "a"][string length][string without null]
    let bytes: [UInt8] = [
      0x13, 0x00, 0x00, 0x00,  // doc length = 19
      0x02,  // type = UTF-8 string
      0x61, 0x00,  // key "a" + null
      0x06, 0x00, 0x00, 0x00,  // string length = 6 (including null)
      0x48, 0x65, 0x6C, 0x6C, 0x6F,  // "Hello" (5 bytes, missing null terminator)
      0xFF,  // not a valid null terminator (should throw)
      0x00,  // doc null terminator
    ]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson cstring key no null terminator (throws)") func bsonCStringKeyNoNullTerminatorThrows()
    throws
  {
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
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson truncated uint32 argument") func bsonTruncatedUInt32Argument() throws {
    // BSON document with only 2 bytes of length (needs 4)
    let bytes: [UInt8] = [0x02, 0x00]  // doc length: 2 bytes (need 4)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson binary subtype zero length") func bsonBinarySubtypeZeroLength() throws {
    // BSON binary data with len=0 — subtype byte at data.count - 1 is safe
    // Document with one binary element, length 0
    // BSON: { key: \x00\x00\x00\x00\x00\x05\x00\x00\x00\x00\x00\x00 }
    // doc length = 0x0C (12), then key "\x00" (null byte), then type 0x05, len 0, subtype byte
    // Actually this is a valid 0-length binary — the subtype byte exists
    // But we need to test: truncated before subtype byte when len=0
    let bytes: [UInt8] = [
      0x0C, 0x00, 0x00, 0x00,  // doc length = 12
      0x00,  // key = ""
      0x05,  // type = binary
      0x00, 0x00, 0x00, 0x00,  // length = 0
      // missing subtype byte
    ]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }
}

// MARK: - BSON Edge Tests

@Suite("BSON edge case tests")
struct JSONBSONEdgeCaseTests {
  @Test("bson string len zero throws") func bsonStringLenZeroThrows() throws {
    // BSON string element (type 0x02) with length = 0 should throw
    // Document: [length][type=0x02][key "a"][string length = 0]
    let bytes: [UInt8] = [
      0x0D, 0x00, 0x00, 0x00,  // doc length = 13
      0x02,  // type = UTF-8 string
      0x61, 0x00,  // key "a" + null
      0x00, 0x00, 0x00, 0x00,  // string length = 0 (should throw)
      0x00,  // doc null terminator
    ]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }

  @Test("bson string len one (empty string)") func bsonStringLenOne() throws {
    // BSON string element with length = 1 (just null terminator) = empty string
    // Document: [length][type=0x02][key "a"][string length = 1][null]
    let bytes: [UInt8] = [
      0x0D, 0x00, 0x00, 0x00,  // doc length = 13
      0x02,  // type = UTF-8 string
      0x61, 0x00,  // key "a" + null
      0x01, 0x00, 0x00, 0x00,  // string length = 1 (just null terminator)
      0x00,  // null terminator for string body
      0x00,  // doc null terminator
    ]
    let data = Data(bytes)
    let decoded = try JSON(bson: data)
    #expect(decoded.isObject)
    let val = decoded["a"]
    #expect(val != nil)
    #expect(val == JSON.string(""))
  }

  @Test("bson binary len zero") func bsonBinaryLenZero() throws {
    // BSON binary data with length = 0 — should produce empty base64 string
    let bytes: [UInt8] = [
      0x0C, 0x00, 0x00, 0x00,  // doc length = 12
      0x05,  // type = binary
      0x78, 0x00,  // key "x" + null
      0x00, 0x00, 0x00, 0x00,  // length = 0
      0x00,  // subtype byte (safe: pos + 1 + 0 <= count)
      0x00,  // doc null terminator
    ]
    let data = Data(bytes)
    let decoded = try JSON(bson: data)
    #expect(decoded.isObject)
    let val = decoded["x"]
    #expect(val != nil)
    #expect(val == JSON.string(""))
  }

  @Test("bson doc len exactly 5 (empty document)") func bsonDocLenExactly5() throws {
    // BSON document with length = 5 (empty: no elements, just null terminator)
    let bytes: [UInt8] = [
      0x05, 0x00, 0x00, 0x00,  // doc length = 5
      // no elements
      0x00,  // null terminator
    ]
    let data = Data(bytes)
    let decoded = try JSON(bson: data)
    #expect(decoded.isObject)
    #expect(decoded.count == 0)
  }

  @Test("bson doc len 5 array (empty array)") func bsonDocLen5Array() throws {
    // BSON array with length = 5 (empty array) — test through a document
    // containing an embedded array element
    let outerBytes: [UInt8] = [
      0x0D, 0x00, 0x00, 0x00,  // outer doc length = 13
      0x04,  // type = array
      0x61, 0x00,  // key "a" + null
      0x05, 0x00, 0x00, 0x00,  // inner array length = 5 (empty)
      0x00,  // inner array null terminator
      0x00,  // outer doc null terminator
    ]
    let data = Data(outerBytes)
    let decoded = try JSON(bson: data)
    #expect(decoded.isObject)
    let arr = decoded["a"]
    #expect(arr != nil)
    #expect(arr?.isArray ?? false)
    #expect(arr?.count == 0)
  }

  @Test("bson doc len int32 max near overflow") func bsonDocLenNearOverflow() throws {
    // docLen = Int32.max is read successfully (4 bytes available), but the decode
    // loop hits a bounds check since data.count = 4 < endPos → throws
    let bytes: [UInt8] = [
      0xFF, 0xFF, 0xFF, 0x7F,  // BSON LE: Int32.max = 2147483647
    ]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bson: data) }
  }
}
