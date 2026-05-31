import Foundation
import Testing

@testable import OrderedJSON

// MARK: - Helpers

/// Appends the big-endian bytes of a UInt64 value to a byte array.
private func appendBE(_ value: UInt64, to bytes: inout [UInt8]) {
  withUnsafeBytes(of: value.bigEndian) { ptr in
    for i in 0..<8 {
      bytes.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)[i])
    }
  }
}

/// Appends the little-endian bytes of a UInt64 value to a byte array.
private func appendLE(_ value: UInt64, to bytes: inout [UInt8]) {
  withUnsafeBytes(of: value.littleEndian) { ptr in
    for i in 0..<8 {
      bytes.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)[i])
    }
  }
}

// MARK: - CBOR Half-Float Edge Tests

@Suite("CBOR half-float edge tests")
struct JSONCBORHalfFloatEdgeTests {
  @Test("half float negative infinity preserves sign") func halfFloatNegativeInfinitySign() throws {
    // 0xFC00 = sign=1, exp=31, mant=0 → -infinity
    let bytes: [UInt8] = [0xF9, 0xFC, 0x00]
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -Double.infinity)
    #expect(d.sign == .minus)
  }

  @Test("half float positive infinity preserves sign") func halfFloatPositiveInfinitySign() throws {
    // 0x7C00 = sign=0, exp=31, mant=0 → +infinity
    let bytes: [UInt8] = [0xF9, 0x7C, 0x00]
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double.infinity)
    #expect(d.sign == .plus)
  }

  @Test("half float negative zero") func halfFloatNegativeZero() throws {
    // 0x8000 = sign=1, exp=0, mant=0 → -0.0
    let bytes: [UInt8] = [0xF9, 0x80, 0x00]
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
    #expect(d.sign == .minus)
  }

  @Test("half float large denormalized value") func halfFloatLargeDenormalized() throws {
    // 0x03FF = sign=0, exp=0, mant=1023 → max denormalized
    // = 1 * 1023 / 16777216 = 1023.0 / 16777216.0
    let bytes: [UInt8] = [0xF9, 0x03, 0xFF]
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == 1023.0 / 16_777_216.0)
  }

  @Test("half float min normalized positive") func halfFloatMinNormalized() throws {
    // 0x0400 = sign=0, exp=1, mant=0 → 2^(-14) = 1/16384
    let bytes: [UInt8] = [0xF9, 0x04, 0x00]
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == 1.0 / 16384.0)
  }

  @Test("half float max finite") func halfFloatMaxFinite() throws {
    // 0x7BFF = sign=0, exp=30, mant=1023 → 2^15 * (1024+1023)/1024 = 65504
    // Max finite half-float = 65504
    let bytes: [UInt8] = [0xF9, 0x7B, 0xFF]
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == 65504.0)
  }
}

// MARK: - CBOR Indefinite-Length Tests

@Suite("CBOR indefinite-length rejection tests")
struct JSONCBORIndefiniteLengthTests {
  @Test("indefinite-length array throws") func indefiniteLengthArrayThrows() throws {
    // Major type 4 (array), info 31 = 0x9F — indefinite-length array
    // Followed by a value (integer 1) but no BREAK terminator
    let bytes: [UInt8] = [0x9F, 0x01]  // indefinite array marker, then integer 1
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("indefinite-length map throws") func indefiniteLengthMapThrows() throws {
    // Major type 5 (map), info 31 = 0xBF — indefinite-length map
    let bytes: [UInt8] = [0xBF, 0x01]  // indefinite map marker, then integer
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("indefinite-length byte string throws") func indefiniteLengthByteStringThrows() throws {
    // Major type 2 (byte string), info 31 = 0x7F — indefinite-length
    let bytes: [UInt8] = [0x7F, 0x01]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("indefinite-length text string throws") func indefiniteLengthTextStringThrows() throws {
    // Major type 3 (text string), info 31 = 0xBF... wait, major 3 is 0x60+31 = 0x7F? No.
    // Major 3 = 3<<5 = 0x60, info 31 = 0x60 | 31 = 0x7F. Hmm that's same as byte string.
    // Actually CBOR major types: 0=unsigned, 1=negative, 2=byte string, 3=text string
    // 3<<5 = 0x60, plus 31 = 0x7F. Yes same as byte string info 31.
    // Major 3 text string with info 31: 0x7F
    let bytes: [UInt8] = [0x7F, 0x41, 0x61]  // indefinite text, then "a"
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
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

// MARK: - MsgPack Negative Integer and String Length Tests

@Suite("MsgPack edge case tests")
struct JSONMsgPackEdgeCaseTests {
  @Test("msg pack int64 min round trip") func msgPackInt64MinRoundTrip() throws {
    let json = JSON.number(.integer(Int64.min))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack int64 min raw decode") func msgPackInt64MinRawDecode() throws {
    // Int64.min = -9223372036854775808
    // In MsgPack, int64 (0xD3) stores value as big-endian signed 64-bit
    // Int64.min in hex = 0x8000000000000000
    var bytes: [UInt8] = [0xD3]
    appendBE(UInt64(bitPattern: Int64.min), to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(msgPack: data)
    #expect(decoded == JSON.number(.integer(Int64.min)))
  }

  @Test("msg pack string32 len near overflow") func msgPackString32LenNearOverflow() throws {
    // MsgPack string32 (0xDB) with length = UInt32.max — should throw
    // since data is too short for that length
    var bytes: [UInt8] = [0xDB]
    let hugeLen = UInt32.max
    // Append big-endian UInt32
    withUnsafeBytes(of: hugeLen.bigEndian) { ptr in
      for i in 0..<4 {
        bytes.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)[i])
      }
    }
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack string32 len exceeds data") func msgPackString32LenExceedsData() throws {
    // MsgPack string32 (0xDB) with length = 100 but only 5 bytes of data
    var bytes: [UInt8] = [0xDB]
    let len = UInt32(100)
    withUnsafeBytes(of: len.bigEndian) { ptr in
      for i in 0..<4 {
        bytes.append(ptr.baseAddress!.assumingMemoryBound(to: UInt8.self)[i])
      }
    }
    bytes.append(contentsOf: [0x41, 0x42, 0x43, 0x44, 0x45])  // "ABCDE" (5 bytes)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack int64 negative one") func msgPackInt64NegativeOne() throws {
    let json = JSON.number(.integer(-1))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack int64 negative max") func msgPackInt64NegativeMax() throws {
    let json = JSON.number(.integer(-1_000_000_000_000))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack uint64 max as float") func msgPackUInt64MaxAsFloat() throws {
    // UInt64.max = 18446744073709551615
    var bytes: [UInt8] = [0xCF]
    appendBE(UInt64.max, to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(UInt64.max))
  }
}

// MARK: - UBJSON/BJData String Length Marker Tests

@Suite("UBJSON/BJData string length edge tests")
struct JSONUBJSONBJDataStringLenTests {
  @Test("ubjson string len int32 max negative throws") func ubjsonStringLenInt32MaxNegativeThrows()
    throws
  {
    // UBJSON string with Int32 length marker, value = 0x80000000 (Int32.min as bits)
    // This produces a negative length after Int32(bitPattern:) → should throw
    // Marker 'S', then 'L' (int32), then 4 bytes: 0x80,0x00,0x00,0x00
    let bytes: [UInt8] = [0x53, 0x4C, 0x80, 0x00, 0x00, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("bjdata string len int32 max negative throws") func bjdataStringLenInt32MaxNegativeThrows()
    throws
  {
    // BJData string with Int32 length marker, value = 0x80000000 (Int32.min as bits)
    let bytes: [UInt8] = [0x53, 0x6C, 0x80, 0x00, 0x00, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata string len uint32 throws") func bjdataStringLenUInt32Throws() throws {
    // BJData string with UInt32 length marker — NOT supported by decoder
    // The decoder only supports Int8/UInt8/Int16/Int32 for string lengths
    let bytes: [UInt8] = [0x53, 0x6D, 0x03, 0x00, 0x00, 0x00, 0x41, 0x42, 0x43]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("ubjson string len int8 negative throws") func ubjsonStringLenInt8NegativeThrows() throws {
    // UBJSON string with Int8 length = -1
    let bytes: [UInt8] = [0x53, 0x49, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("bjdata string len int8 negative throws") func bjdataStringLenInt8NegativeThrows() throws {
    // BJData string with Int8 length = -1
    let bytes: [UInt8] = [0x53, 0x49, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata string len uint8 works") func bjdataStringLenUInt8Works() throws {
    // BJData string with UInt8 length marker — should work
    let bytes: [UInt8] = [0x53, 0x55, 0x03, 0x41, 0x42, 0x43]
    let data = Data(bytes)
    let decoded = try JSON(bjdata: data)
    #expect(decoded == JSON.string("ABC"))
  }
}

// MARK: - CBOR Negative Integer Edge Tests

@Suite("CBOR negative integer edge tests")
struct JSONCBORNegativeIntEdgeTests {
  @Test("cbor negative int argument zero") func cborNegativeIntArgumentZero() throws {
    // CBOR negative integer with argument = 0 → -1 - 0 = -1
    let bytes: [UInt8] = [0x20]  // major 1, info 0 → argument = 0 → value = -1
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded == JSON.number(.integer(-1)))
  }

  @Test("cbor negative int argument one") func cborNegativeIntArgumentOne() throws {
    // CBOR negative integer with argument = 1 → -1 - 1 = -2
    let bytes: [UInt8] = [0x21]  // major 1, info 1 → argument = 1 → value = -2
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded == JSON.number(.integer(-2)))
  }

  @Test("cbor negative int argument int64 max") func cborNegativeIntArgumentInt64Max() throws {
    // CBOR negative integer with argument = Int64.max → -1 - Int64.max = Int64.min
    var bytes: [UInt8] = [0x3B]  // major 1, info 27 (8 bytes)
    appendBE(UInt64(Int64.max), to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isInteger)
    guard case .number(.integer(let i)) = decoded.storage else {
      Issue.record("Expected integer, got \(decoded)")
      return
    }
    #expect(i == Int64.min)
  }

  @Test("cbor negative int argument uint64 max as float") func cborNegativeIntArgumentUInt64Max()
    throws
  {
    // CBOR negative integer with argument = UInt64.max
    // → -1.0 - Double(UInt64.max) — stored as float
    var bytes: [UInt8] = [0x3B]  // major 1, info 27 (8 bytes)
    appendBE(UInt64.max, to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
  }

  @Test("cbor negative int encode int64 min round trip") func cborNegativeIntEncodeInt64Min()
    throws
  {
    // Encode Int64.min, decode back
    let json = JSON.number(.integer(Int64.min))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }
}

// MARK: - BJData End Marker Edge Tests

@Suite("BJData end marker edge tests")
struct JSONBJDataEndMarkerEdgeTests {
  @Test("bjdata empty array then more data") func bjdataEmptyArrayThenData() throws {
    // BJData: '[', ']' then trailing data should throw
    let bytes: [UInt8] = [0x5B, 0x5D, 0x00]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata array with end marker at wrong position") func bjdataArrayEndMarkerWrongPos()
    throws
  {
    // BJData: '[' with no end marker — runs out of data
    let bytes: [UInt8] = [0x5B]  // just '[', no ']'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata object with end marker at wrong position") func bjdataObjectEndMarkerWrongPos()
    throws
  {
    // BJData: '{' with no end marker — runs out of data
    let bytes: [UInt8] = [0x7B]  // just '{', no '}'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata mismatched end marker in array") func bjdataMismatchedEndMarkerInArray() throws {
    // BJData array with '}' end marker inside (mismatched)
    // The '}' is not ']' so it tries to decode it as a value → unknown marker error
    let bytes: [UInt8] = [0x5B, 0x7D]  // '[', '}' — '}' is not ']'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }

  @Test("bjdata mismatched end marker in object") func bjdataMismatchedEndMarkerInObject() throws {
    // BJData object with ']' end marker inside (mismatched)
    let bytes: [UInt8] = [0x7B, 0x5D]  // '{', ']' — ']' is not '}'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }
}

// MARK: - Missing Round-Trip Edge Tests

@Suite("Binary round-trip missing edge value tests")
struct JSONBinaryRoundTripMissingEdgeTests {
  @Test("msg pack round trip nan") func msgPackRoundTripNaN() throws {
    let json = JSON.number(.float(Double.nan))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d.isNaN)
  }

  @Test("msg pack round trip infinity") func msgPackRoundTripInfinity() throws {
    let json = JSON.number(.float(Double.infinity))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double.infinity)
  }

  @Test("msg pack round trip negative infinity") func msgPackRoundTripNegativeInfinity() throws {
    let json = JSON.number(.float(-Double.infinity))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -Double.infinity)
  }

  @Test("ubjson round trip negative infinity") func ubjsonRoundTripNegativeInfinity() throws {
    let json = JSON.number(.float(-Double.infinity))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -Double.infinity)
  }

  @Test("bson round trip negative infinity") func bsonRoundTripNegativeInfinity() throws {
    let json = JSON.number(.float(-Double.infinity))
    let data = json.bson()
    let decoded = try JSON(bson: data)
    #expect(decoded.isObject)
    guard case .object(let dict) = decoded.storage else {
      Issue.record("Expected object, got \(decoded)")
      return
    }
    let val = try #require(dict["value"])
    #expect(val.isFloat)
  }

  @Test("bjdata round trip negative infinity") func bjdataRoundTripNegativeInfinity() throws {
    let json = JSON.number(.float(-Double.infinity))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -Double.infinity)
  }

  @Test("msg pack round trip negative zero float") func msgPackRoundTripNegativeZeroFloat() throws {
    let json = JSON.number(.float(-0.0))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
    // MsgPack float64 preserves sign bit
    #expect(d.sign == .minus)
  }

  @Test("ubjson round trip negative zero float sign") func ubjsonRoundTripNegativeZeroFloatSign()
    throws
  {
    let json = JSON.number(.float(-0.0))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
    #expect(d.sign == .minus)
  }

  @Test("bjdata round trip negative zero float sign") func bjdataRoundTripNegativeZeroFloatSign()
    throws
  {
    let json = JSON.number(.float(-0.0))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == -0.0)
    #expect(d.sign == .minus)
  }

  @Test("cbor round trip large uint64 as float") func cborRoundTripLargeUInt64AsFloat() throws {
    // CBOR: encode a float that represents a value > Int64.max
    let json = JSON.number(.float(Double(UInt64(Int64.max) + 1)))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(UInt64(Int64.max) + 1))
  }

  @Test("msg pack round trip large uint64 as float") func msgPackRoundTripLargeUInt64AsFloat()
    throws
  {
    let json = JSON.number(.float(Double(UInt64(Int64.max) + 1)))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(UInt64(Int64.max) + 1))
  }

  @Test("ubjson round trip large uint64 as float") func ubjsonRoundTripLargeUInt64AsFloat() throws {
    let json = JSON.number(.float(Double(UInt64(Int64.max) + 1)))
    let data = json.ubjson()
    let decoded = try JSON(ubjson: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(UInt64(Int64.max) + 1))
  }

  @Test("bjdata round trip large uint64 as float") func bjdataRoundTripLargeUInt64AsFloat() throws {
    let json = JSON.number(.float(Double(UInt64(Int64.max) + 1)))
    let data = json.bjdata()
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(UInt64(Int64.max) + 1))
  }

  @Test("cbor round trip negative zero float encode") func cborRoundTripNegativeZeroFloatEncode()
    throws
  {
    // Verify CBOR encode of -0.0 uses float64, preserving sign
    let json = JSON.number(.float(-0.0))
    let data = json.cbor()
    // CBOR float64 has sign bit — should be preserved
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d.sign == .minus)
  }
}

// MARK: - Binary Format Fuzz-Style Truncation Tests

@Suite("Binary format truncation edge tests")
struct JSONBinaryTruncationEdgeTests {
  @Test("cbor truncated after major type marker") func cborTruncatedAfterMajorType() throws {
    // CBOR: marker byte with no additional info bytes when info >= 24
    let bytes: [UInt8] = [0x18]  // major 0, info 24 — needs 1 more byte
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor truncated after 2-byte length prefix") func cborTruncatedAfter2ByteLength() throws {
    // CBOR: marker with info 25, only 1 of 2 bytes
    let bytes: [UInt8] = [0x19, 0x01]  // major 0, info 25 — needs 2 bytes, has 1
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor truncated after 4-byte length prefix") func cborTruncatedAfter4ByteLength() throws {
    // CBOR: marker with info 26, only 2 of 4 bytes
    let bytes: [UInt8] = [0x1A, 0x00, 0x01]  // major 0, info 26 — needs 4 bytes, has 2
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("msg pack truncated string body") func msgPackTruncatedStringBody() throws {
    // MsgPack fixstr with length 3 but only 2 bytes of string data
    let bytes: [UInt8] = [0xA3, 0x41, 0x42]  // str len=3, only 2 bytes of content
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated array elements") func msgPackTruncatedArrayElements() throws {
    // MsgPack fixarray with count 3 but only 1 element
    let bytes: [UInt8] = [0x93, 0x01]  // array of 3, only 1 element
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated map elements") func msgPackTruncatedMapElements() throws {
    // MsgPack fixmap with count 2 but only 1 key-value pair
    let bytes: [UInt8] = [0x82, 0xA1, 0x61, 0x01]  // map of 2, only 1 entry
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("ubjson truncated array element") func ubjsonTruncatedArrayElement() throws {
    // UBJSON array with count 3 but truncated after 2 elements
    let bytes: [UInt8] = [0x5B, 0x49, 0x03, 0x01, 0x02]  // array of 3, 2 int8 elements
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("ubjson truncated object element") func ubjsonTruncatedObjectElement() throws {
    // UBJSON object with count 2 but truncated after 1 element
    let bytes: [UInt8] = [0x7B, 0x49, 0x02, 0x53, 0x49, 0x01, 0x61]  // object of 2, 1 entry
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(ubjson: data) }
  }

  @Test("bjdata truncated array element") func bjdataTruncatedArrayElement() throws {
    // BJData array with no end marker, truncated
    let bytes: [UInt8] = [0x5B, 0x49, 0x01]  // '[', int8 1, no ']'
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(bjdata: data) }
  }
}

// MARK: - CBOR Tag Edge Tests

@Suite("CBOR tag edge tests")
struct JSONCBORTagEdgeTests {
  @Test("cbor tag 0 then value") func cborTag0ThenValue() throws {
    // CBOR tag 0 (major 6, info 0 = 0xC0) followed by unsigned 1
    let bytes: [UInt8] = [0xC0, 0x01]
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded == JSON.number(.integer(1)))
  }

  @Test("cbor tag 65535 then value") func cborTag65535ThenValue() throws {
    // CBOR tag 65535 (major 6, info 25 = 0xD9, 0xFF, 0xFF) followed by value
    let bytes: [UInt8] = [0xD9, 0xFF, 0xFF, 0x01]
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded == JSON.number(.integer(1)))
  }

  @Test("cbor tag truncated") func cborTagTruncated() throws {
    // CBOR tag 65535 with only 1 of 2 bytes
    let bytes: [UInt8] = [0xD9, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }
}
