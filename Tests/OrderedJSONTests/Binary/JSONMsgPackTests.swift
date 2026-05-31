import Foundation
import OrderedCollections
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

// MARK: - MessagePack Tests

@Suite("MessagePack tests")
struct JSONMsgPackTests {
  @Test("msg pack round trip null") func msgPackRoundTripNull() throws {
    let json = JSON.null
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip bool") func msgPackRoundTripBool() throws {
    let json = JSON.boolean(true)
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip bool false") func msgPackRoundTripBoolFalse() throws {
    let json = JSON.boolean(false)
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip integer") func msgPackRoundTripInteger() throws {
    let json = JSON.number(.integer(42))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip float") func msgPackRoundTripFloat() throws {
    let json = JSON.number(.float(3.14))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip string") func msgPackRoundTripString() throws {
    let json = JSON.string("hello")
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip array") func msgPackRoundTripArray() throws {
    let json = JSON.array([JSON.number(.integer(1)), JSON.number(.integer(2))])
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack round trip object") func msgPackRoundTripObject() throws {
    let json = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack negative integer") func msgPackNegativeInteger() throws {
    let json = JSON.number(.integer(-42))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack large integer") func msgPackLargeInteger() throws {
    let json = JSON.number(.integer(100_000))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack trailing bytes") func msgPackTrailingBytes() throws {
    let json = JSON.number(.integer(1))
    let data = json.msgPack()
    var trailing = data
    trailing.append(0x00)
    #expect(throws: JSONError.self) {
      try JSON(msgPack: trailing)
    }
  }

  @Test("msg pack empty data") func msgPackEmptyData() throws {
    #expect(throws: JSONError.self) { try JSON(msgPack: Data()) }
  }

  @Test("msg pack negative fix int") func msgPackNegativeFixInt() throws {
    let json = JSON.number(.integer(-10))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack uint8") func msgPackUInt8() throws {
    let json = JSON.number(.integer(200))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack uint16") func msgPackUInt16() throws {
    let json = JSON.number(.integer(1000))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack uint64 positive") func msgPackUInt64Positive() throws {
    let json = JSON.number(.integer(Int64(UInt32.max) + 1))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack int16") func msgPackInt16() throws {
    let json = JSON.number(.integer(-200))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack int64") func msgPackInt64() throws {
    let json = JSON.number(.integer(Int64(Int32.min) - 1))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack float32") func msgPackFloat32() throws {
    let json = JSON.number(.float(1.5))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack string32 plus") func msgPackString32Plus() throws {
    // String with length 32-255 (uses 0xD9 marker)
    let s = String(repeating: "x", count: 100)
    let json = JSON.string(s)
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack large array16") func msgPackLargeArray16() throws {
    // Build raw bytes for a 16-element array (0xDC marker)
    var bytes: [UInt8] = [0xDC, 0x00, 0x10]  // array of 16
    for _ in 0..<16 {
      bytes.append(0x2A)  // 42 encoded as positive fixint
    }
    let data = Data(bytes)
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isArray)
    #expect(decoded.count == 16)
  }

  @Test("msg pack large array32") func msgPackLargeArray32() throws {
    // Build raw bytes for array with 0xDD marker (3 elements)
    var bytes: [UInt8] = [0xDD, 0x00, 0x00, 0x00, 0x03]  // array of 3
    for _ in 0..<3 {
      bytes.append(0x2A)
    }
    let data = Data(bytes)
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isArray)
    #expect(decoded.count == 3)
  }

  @Test("msg pack large map16") func msgPackLargeMap16() throws {
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
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isObject)
    #expect(decoded.count == 2)
  }

  @Test("msg pack large map32") func msgPackLargeMap32() throws {
    // Build raw bytes for a map with 0xDF marker (1 entry)
    var bytes: [UInt8] = [0xDF, 0x00, 0x00, 0x00, 0x01]
    bytes.append(0xA1)
    bytes.append(0x61)  // "a"
    bytes.append(0x01)
    let data = Data(bytes)
    let decoded = try JSON(msgPack: data)
    #expect(decoded.isObject)
    #expect(decoded["a"] == JSON.number(.integer(1)))
  }

  @Test("msg pack string8") func msgPackString8() throws {
    // Build raw bytes for string with 0xD9 marker (len=32)
    var bytes: [UInt8] = [0xD9, 32]
    for _ in 0..<32 {
      bytes.append(0x61)
    }  // "a" * 32
    let data = Data(bytes)
    let decoded = try JSON(msgPack: data)
    #expect(decoded == JSON.string(String(repeating: "a", count: 32)))
  }

  @Test("msg pack string16") func msgPackString16() throws {
    // Build raw bytes for string with 0xDA marker (len=256)
    var bytes: [UInt8] = [0xDA, 0x01, 0x00]
    for _ in 0..<256 {
      bytes.append(0x61)
    }
    let data = Data(bytes)
    let decoded = try JSON(msgPack: data)
    #expect(decoded == JSON.string(String(repeating: "a", count: 256)))
  }

  @Test("msg pack string32") func msgPackString32() throws {
    // Build raw bytes for string with 0xDB marker (len=100)
    var bytes: [UInt8] = [0xDB, 0x00, 0x00, 0x00, 0x64]
    for _ in 0..<100 {
      bytes.append(0x61)
    }
    let data = Data(bytes)
    let decoded = try JSON(msgPack: data)
    #expect(decoded == JSON.string(String(repeating: "a", count: 100)))
  }

  @Test("msg pack unknown type") func msgPackUnknownType() throws {
    let data = Data([0xC1])  // 0xC1 is unused in MsgPack spec
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack invalid utf8") func msgPackInvalidUTF8() throws {
    // String with invalid UTF-8 continuation byte
    let bytes: [UInt8] = [0xA1, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack non string map key") func msgPackNonStringMapKey() throws {
    // Map where key is an integer (0x01) instead of a string
    let data = Data([0x81, 0x01, 0x03])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack encode uint8") func msgPackEncodeUInt8() throws {
    let json = JSON.number(.integer(128))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack encode uint16") func msgPackEncodeUInt16() throws {
    let json = JSON.number(.integer(256))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack encode large array") func msgPackEncodeLargeArray() throws {
    var arr: [JSON] = []
    for idx in 0..<20 {
      arr.append(JSON.number(.integer(Int64(idx))))
    }
    let json = JSON.array(arr)
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack encode large object") func msgPackEncodeLargeObject() throws {
    var dict = OrderedDictionary<String, JSON>()
    for idx in 0..<20 {
      dict["k\(idx)"] = JSON.number(.integer(Int64(idx)))
    }
    let json = JSON.object(dict)
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack encode long string") func msgPackEncodeLongString() throws {
    let s = String(repeating: "x", count: 50)
    let json = JSON.string(s)
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack bin types") func msgPackBinTypes() throws {
    // Binary 0xC4 (8-bit length)
    let bin1 = Data([0xC4, 3, 0x61, 0x62, 0x63])
    let decoded1 = try JSON(msgPack: bin1)
    #expect(decoded1.isString)

    // Binary 0xC5 (16-bit length)
    let bin2 = Data([0xC5, 0x00, 0x03, 0x61, 0x62, 0x63])
    let decoded2 = try JSON(msgPack: bin2)
    #expect(decoded2.isString)

    // Binary 0xC6 (32-bit length)
    let bin3 = Data([0xC6, 0x00, 0x00, 0x00, 0x03, 0x61, 0x62, 0x63])
    let decoded3 = try JSON(msgPack: bin3)
    #expect(decoded3.isString)
  }

  @Test("msg pack large negative") func msgPackLargeNegative() throws {
    let json = JSON.number(.integer(-1_000_000))
    let data = json.msgPack()
    let decoded = try JSON(msgPack: data)
    #expect(decoded == json)
  }

  @Test("msg pack string len exceeds data (throws)") func msgPackStringLenExceedsDataThrows() throws
  {
    // MsgPack string 32 with length > available data should throw
    let bytes: [UInt8] = [0xDB, 0xFF, 0xFF, 0xFF, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack bin len exceeds data (throws)") func msgPackBinLenExceedsDataThrows() throws {
    // MsgPack bin 32 with length > available data should throw
    let bytes: [UInt8] = [0xC6, 0xFF, 0xFF, 0xFF, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  // MARK: - Truncated data bounds checks

  @Test("msg pack truncated uint16 (throws)") func msgPackTruncatedUInt16() throws {
    // 0xCD (uint16) with only 1 byte (needs 2)
    let data = Data([0xCD, 0x01])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated uint32 (throws)") func msgPackTruncatedUInt32() throws {
    // 0xCE (uint32) with only 2 bytes (needs 4)
    let data = Data([0xCE, 0x00, 0x01])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated uint64 (throws)") func msgPackTruncatedUInt64() throws {
    // 0xCF (uint64) with only 4 bytes (needs 8)
    let data = Data([0xCF, 0x00, 0x00, 0x00, 0x01])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated uint8 (throws)") func msgPackTruncatedUInt8() throws {
    // 0xCC (uint8) with no data byte
    let data = Data([0xCC])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated int8 (throws)") func msgPackTruncatedInt8() throws {
    // 0xD0 (int8) with no data byte
    let data = Data([0xD0])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated float32 (throws)") func msgPackTruncatedFloat32() throws {
    // 0xCA (float32) with only 2 bytes (needs 4)
    let data = Data([0xCA, 0x00, 0x00])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated float64 (throws)") func msgPackTruncatedFloat64() throws {
    // 0xCB (float64) with only 4 bytes (needs 8)
    let data = Data([0xCB, 0x00, 0x00, 0x00, 0x00])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated string8 (throws)") func msgPackTruncatedString8() throws {
    // 0xD9 (string8) with no length byte
    let data = Data([0xD9])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated string16 (throws)") func msgPackTruncatedString16() throws {
    // 0xDA (string16) with only 1 byte (needs 2)
    let data = Data([0xDA, 0x01])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated array16 (throws)") func msgPackTruncatedArray16() throws {
    // 0xDC (array16) with only 1 byte (needs 2)
    let data = Data([0xDC, 0x01])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated map16 (throws)") func msgPackTruncatedMap16() throws {
    // 0xDE (map16) with only 1 byte (needs 2)
    let data = Data([0xDE, 0x01])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated bin8 (throws)") func msgPackTruncatedBin8() throws {
    // 0xC4 (bin8) with no length byte
    let data = Data([0xC4])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated bin16 (throws)") func msgPackTruncatedBin16() throws {
    // 0xC5 (bin16) with only 1 byte (needs 2)
    let data = Data([0xC5, 0x01])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
  }

  @Test("msg pack truncated bin32 (throws)") func msgPackTruncatedBin32() throws {
    // 0xC6 (bin32) with only 2 bytes (needs 4)
    let data = Data([0xC6, 0x00, 0x01])
    #expect(throws: JSONError.self) { try JSON(msgPack: data) }
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
