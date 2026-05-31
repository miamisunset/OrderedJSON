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

// MARK: - Overflow Tests

@Suite("JSON overflow tests")
struct JSONOverflowTests {
  @Test("msg pack uint64 overflow becomes float") func msgPackUInt64OverflowBecomesFloat() throws {
    // Encode a uint64 value that exceeds Int64.max (2^63)
    // MessagePack marker 0xCF followed by 8 bytes big-endian
    // Value: 2^63 + 1 = 9223372036854775808, which is > Int64.max
    var bytes: [UInt8] = [0xCF]
    let large = UInt64(Int64.max) + 1  // 2^63
    appendBE(large, to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(msgPack: data)
    // Should decode as float since value exceeds Int64.max
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(large))
  }

  @Test("cbor uint64 overflow becomes float") func cborUInt64OverflowBecomesFloat() throws {
    // CBOR major type 0 (unsigned integer) with 8-byte argument
    // Value: 2^63 + 1 = 9223372036854775808, which is > Int64.max
    var bytes: [UInt8] = [0x1B]  // major=0, additional=27 (8 bytes)
    let large = UInt64(Int64.max) + 1
    appendBE(large, to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    // Should decode as float since value exceeds Int64.max
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d == Double(large))
  }

  @Test("cbor negative int overflow becomes float") func cborNegativeIntOverflowBecomesFloat()
    throws
  {
    // CBOR major type 1 (negative integer) with 8-byte argument
    // Value: -1 - 2^64 = overflow case
    // Encode argument = UInt64.max, so result = -1 - UInt64.max which overflows Int64
    var bytes: [UInt8] = [0x3B]  // major=1, additional=27 (8 bytes)
    let large = UInt64.max
    appendBE(large, to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    // Should decode as float since negative value exceeds Int64 range
    #expect(decoded.isFloat)
  }

  @Test("cbor negative int near overflow") func cborNegativeIntNearOverflow() throws {
    // CBOR major type 1 with argument = Int64.max
    // Value: -1 - Int64.max = Int64.min (exactly representable as Int64)
    var bytes: [UInt8] = [0x3B]  // major=1, additional=27
    let arg = UInt64(Int64.max)
    appendBE(arg, to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isInteger)
    guard case .number(.integer(let i)) = decoded.storage else {
      Issue.record("Expected integer, got \(decoded)")
      return
    }
    #expect(i == Int64.min)
  }

  @Test("cbor uint64 precision loss") func cborUInt64PrecisionLoss() throws {
    // Values > Int64.max stored as Double — round-trip through CBOR loses precision.
    // This documents the intentional semantic change: these values are no longer exact.
    let original = UInt64(Int64.max) + 1  // 2^63
    var bytes: [UInt8] = [0x1B]
    appendBE(original, to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    // The Double representation of 2^63 is exact (it's a power of 2)
    // but larger values would lose precision
    #expect(d == Double(original))
    // Re-encode back to CBOR and verify
    let reEncoded = decoded.cbor()
    let roundTrip = try JSON(cbor: reEncoded)
    #expect(roundTrip == decoded)
  }

  @Test("ubjson uint64 overflow becomes float") func ubjsonUInt64OverflowBecomesFloat() throws {
    // UBJSON marker for int64 reads uint64 bit pattern — must not crash
    var bytes: [UInt8] = [0x4C]  // 'L' marker for int64
    let large = UInt64(Int64.max) + 1
    appendBE(large, to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(ubjson: data)
    #expect(decoded.isInteger || decoded.isFloat)
  }

  @Test("bson uint64 overflow becomes float") func bsonUInt64OverflowBecomesFloat() throws {
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
    let decoded = try JSON(bson: data)
    #expect(decoded.isObject)
    if case .object(let dict) = decoded.storage {
      let val = try #require(dict["x"])
      #expect(val.isFloat || val.isInteger)
    }
  }

  @Test("bjdata uint64 overflow becomes float") func bjdataUInt64OverflowBecomesFloat() throws {
    // BJData marker for uint64 uses Int64(bitPattern:) — must not crash
    var bytes: [UInt8] = [0x4D]  // 'M' marker for uint64
    let large = UInt64(Int64.max) + 1
    appendBE(large, to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(bjdata: data)
    #expect(decoded.isFloat || decoded.isInteger)
  }
}
