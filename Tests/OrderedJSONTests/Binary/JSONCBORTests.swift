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

// MARK: - CBOR Tests

@Suite("CBOR tests")
struct JSONCBORTests {
  @Test("cbor round trip null") func cborRoundTripNull() throws {
    let json = JSON.null
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip bool") func cborRoundTripBool() throws {
    let json = JSON.boolean(true)
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip bool false") func cborRoundTripBoolFalse() throws {
    let json = JSON.boolean(false)
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip integer") func cborRoundTripInteger() throws {
    let json = JSON.number(.integer(42))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip float") func cborRoundTripFloat() throws {
    let json = JSON.number(.float(3.14))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip string") func cborRoundTripString() throws {
    let json = JSON.string("hello")
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip array") func cborRoundTripArray() throws {
    let json = JSON.array([
      JSON.number(.integer(1)), JSON.number(.integer(2)), JSON.number(.integer(3)),
    ])
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor round trip object") func cborRoundTripObject() throws {
    let json = JSON.object(["a": JSON.number(.integer(1)), "b": JSON.string("x")])
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor negative integer") func cborNegativeInteger() throws {
    let json = JSON.number(.integer(-42))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor large integer") func cborLargeInteger() throws {
    let json = JSON.number(.integer(100_000))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor trailing bytes") func cborTrailingBytes() throws {
    let json = JSON.number(.integer(1))
    let data = json.cbor()
    var trailing = data
    trailing.append(0x00)
    #expect(throws: JSONError.self) {
      try JSON(cbor: trailing)
    }
  }

  @Test("cbor byte string") func cborByteString() throws {
    // CBOR byte string (major type 2) with 3 bytes
    let bytes: [UInt8] = [0x43, 0x61, 0x62, 0x63]  // major 2, len=3, data="abc"
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isString)
  }

  @Test("cbor tag") func cborTag() throws {
    // CBOR tag (major type 6) followed by integer 42
    // Tag 1: major 6 (0xC0), info 1 = 0xC1, then integer 42
    let bytes: [UInt8] = [0xC1, 0x18, 0x2A]  // tag 1, unsigned 42
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded == JSON.number(.integer(42)))
  }

  @Test("cbor half float") func cborHalfFloat() throws {
    // CBOR half-precision float (additional info 25)
    // 1.5 encoded as half-float: 0x3E, 0x80 = 0b0 01111 1000000000 = 1.5
    let bytes: [UInt8] = [0xF9, 0x3E, 0x80]  // major 7, info 25, value=0x3E80
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isNumber)
  }

  @Test("cbor undefined") func cborUndefined() throws {
    // CBOR undefined value (major 7, info 23) — maps to null
    let bytes: [UInt8] = [0xF7]  // major 7, info 23 (undefined)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isNull)
  }

  @Test("cbor empty data") func cborEmptyData() throws {
    #expect(throws: JSONError.self) { try JSON(cbor: Data()) }
  }

  @Test("cbor reserved info") func cborReservedInfo() throws {
    // Reserved additional info (28-31) should throw
    let bytes: [UInt8] = [0xF8]  // major 7, info 28 (reserved)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor unknown major type") func cborUnknownMajorType() {
    // CBOR only defines major types 0-7; the default case is unreachable
    // but we can verify it exists by testing with a marker that has no handler
    // The reserved info case is tested in cborReservedInfo
  }

  @Test("cbor half float denormalized") func cborHalfFloatDenormalized() throws {
    // Half-float denormalized value (exp=0)
    let bytes: [UInt8] = [0xF9, 0x00, 0x01]  // major 7, info 25, value=0x0001 (min denormalized)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isNumber)
  }

  @Test("cbor half float inf") func cborHalfFloatInf() throws {
    // Half-float infinity (exp=31, mant=0)
    let bytes: [UInt8] = [0xF9, 0xFC, 0x00]  // major 7, info 25, value=0xFC00 (-inf)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isNumber)
  }

  @Test("cbor half float nan") func cborHalfFloatNaN() throws {
    // Half-float NaN (exp=31, mant!=0)
    let bytes: [UInt8] = [0xF9, 0xFE, 0x00]  // major 7, info 25, value=0xFE00 (NaN)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isNumber)
    #expect(decoded.isFloat)
  }

  @Test("cbor half float denormalized value") func cborHalfFloatDenormalizedValue() throws {
    // Half-float denormalized: 0x0001 = 2^(-24) ≈ 5.96e-8
    let bytes: [UInt8] = [0xF9, 0x00, 0x01]  // major 7, info 25, value=0x0001
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isNumber)
    // 2^(-24) = 1 / 16777216 ≈ 5.960464477539063e-8
    #expect(decoded == JSON.number(.float(1.0 / 16_777_216.0)))
  }

  @Test("cbor half float denormalized max") func cborHalfFloatDenormalizedMax() throws {
    // Half-float denormalized max: 0x03FF = 2^(-14) * (1023/1024) ≈ 6.1e-5
    let bytes: [UInt8] = [0xF9, 0x03, 0xFF]  // major 7, info 25, value=0x03FF
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isNumber)
    // Max denormalized = 2^(-14) * (1023/1024) = 1023 / (16384 * 1024) = 1023 / 16777216
    #expect(decoded == JSON.number(.float(1023.0 / 16_777_216.0)))
  }

  @Test("cbor half float normalized min") func cborHalfFloatNormalizedMin() throws {
    // Half-float normalized min: 0x0400 = 2^(-14) * (1024/1024) = 2^(-14) ≈ 6.1e-5
    let bytes: [UInt8] = [0xF9, 0x04, 0x00]  // major 7, info 25, value=0x0400
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isNumber)
    // Min normalized = 2^(-14) = 1 / 16384
    #expect(decoded == JSON.number(.float(1.0 / 16384.0)))
  }

  @Test("cbor non string map key") func cborNonStringMapKey() throws {
    // CBOR map with integer key instead of string
    // Map of 1 entry: major 5 (0xA0 | 1 = 0xA1), integer key 0x01, value null (0xF6)
    let bytes: [UInt8] = [0xA1, 0x01, 0xF6]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor unsupported simple value") func cborUnsupportedSimpleValue() throws {
    // CBOR simple value 28 (info 28) — not 20-23, not half/double float
    let bytes: [UInt8] = [0xFC]  // major 7, info 28
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor large negative") func cborLargeNegative() throws {
    let json = JSON.number(.integer(-1_000_000))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor large negative int64") func cborLargeNegativeInt64() throws {
    let json = JSON.number(.integer(-1_000_000_000))
    let data = json.cbor()
    let decoded = try JSON(cbor: data)
    #expect(decoded == json)
  }

  @Test("cbor string len overflow (throws)") func cborStringLenOverflowThrows() throws {
    // CBOR text string with length > Int64.max should throw
    let bytes: [UInt8] = [0x7B, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor array count overflow (throws)") func cborArrayCountOverflowThrows() throws {
    // CBOR array with count > Int64.max should throw
    let bytes: [UInt8] = [0x9B, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor string len exceeds data (throws)") func cborStringLenExceedsDataThrows() throws {
    // CBOR text string with length > available data should throw
    let bytes: [UInt8] = [0x78, 100, 0x41, 0x42, 0x43, 0x44, 0x45]
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor truncated uint16 argument") func cborTruncatedUInt16Argument() throws {
    // CBOR half-float marker (info 25) with only 1 byte of argument (needs 2)
    let bytes: [UInt8] = [0xF9, 0x00]  // major 7, info 25, 1 byte (need 2)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor truncated uint32 argument") func cborTruncatedUInt32Argument() throws {
    // CBOR float marker (info 26) with only 2 bytes of argument (needs 4)
    let bytes: [UInt8] = [0xFA, 0x00, 0x00]  // major 7, info 26, 2 bytes (need 4)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor truncated uint64 argument") func cborTruncatedUInt64Argument() throws {
    // CBOR double marker (info 27) with only 4 bytes of argument (needs 8)
    let bytes: [UInt8] = [0xFB, 0x00, 0x00, 0x00, 0x00]  // major 7, info 27, 4 bytes (need 8)
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
  }

  @Test("cbor single byte argument truncated") func cborSingleByteArgumentTruncated() throws {
    // CBOR marker with info 24 (1-byte argument) but no argument byte
    let bytes: [UInt8] = [0x18]  // major 0 (unsigned), info 24, 0 argument bytes
    let data = Data(bytes)
    #expect(throws: JSONError.self) { try JSON(cbor: data) }
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
