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

// MARK: - Edge Case Tests

@Suite("JSON edge case tests")
struct JSONEdgeCaseTests {
  @Test("nan float serializes as null") func nanFloatSerializesAsNull() {
    let json = JSON.number(.float(Double.nan))
    let dumped = json.dump(indent: nil)
    #expect(dumped == "null")
  }

  @Test("infinity float serializes as null") func infinityFloatSerializesAsNull() {
    let json = JSON.number(.float(Double.infinity))
    let dumped = json.dump(indent: nil)
    #expect(dumped == "null")
  }

  @Test("negative infinity float serializes as null") func negativeInfinityFloatSerializesAsNull() {
    let json = JSON.number(.float(-Double.infinity))
    let dumped = json.dump(indent: nil)
    #expect(dumped == "null")
  }

  @Test("nan in object serializes correctly") func nanInObjectSerializesCorrectly() {
    let json = JSON.object(["a": JSON.number(.float(Double.nan)), "b": JSON.number(.integer(1))])
    let dumped = json.dump(indent: nil)
    // NaN should serialize as null, not crash
    #expect(dumped == "{\"a\":null,\"b\":1}" || dumped == "{\"b\":1,\"a\":null}")
  }

  @Test("nan round trip through cbor") func nanRoundTripThroughCBOR() throws {
    // NaN is valid in CBOR binary format — decode should preserve it
    var bytes: [UInt8] = [0xFB]
    let bits = Double.nan.bitPattern
    appendBE(bits, to: &bytes)
    let data = Data(bytes)
    let decoded = try JSON(cbor: data)
    #expect(decoded.isFloat)
    guard case .number(.float(let d)) = decoded.storage else {
      Issue.record("Expected float, got \(decoded)")
      return
    }
    #expect(d.isNaN)
    // Serialize to JSON string — should produce null
    let dumped = decoded.dump(indent: nil)
    #expect(dumped == "null")
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
