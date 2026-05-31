import Foundation
import Testing

@testable import OrderedJSON

@Suite("Integer Width Coding Tests") struct JSONIntegerWidthCodingTests {
  @Test("encode decode int8") func encodeDecodeInt8() throws {
    struct Value: Codable {
      let x: Int8
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Value(x: 42))
    #expect(json["x"] == .number(.integer(42)))

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Value.self, from: json)
    #expect(back.x == 42)
  }

  @Test("encode decode int16") func encodeDecodeInt16() throws {
    struct Value: Codable {
      let x: Int16
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Value(x: 42))
    #expect(json["x"] == .number(.integer(42)))

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Value.self, from: json)
    #expect(back.x == 42)
  }

  @Test("encode decode int32") func encodeDecodeInt32() throws {
    struct Value: Codable {
      let x: Int32
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Value(x: 42))
    #expect(json["x"] == .number(.integer(42)))

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Value.self, from: json)
    #expect(back.x == 42)
  }

  @Test("encode decode uint") func encodeDecodeUInt() throws {
    struct Value: Codable {
      let x: UInt
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Value(x: 42))
    #expect(json["x"] == .number(.integer(42)))

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Value.self, from: json)
    #expect(back.x == 42)
  }

  @Test("encode decode uint8") func encodeDecodeUInt8() throws {
    struct Value: Codable {
      let x: UInt8
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Value(x: 255))
    #expect(json["x"] == .number(.integer(255)))

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Value.self, from: json)
    #expect(back.x == 255)
  }

  @Test("encode decode uint16") func encodeDecodeUInt16() throws {
    struct Value: Codable {
      let x: UInt16
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Value(x: 42000))
    #expect(json["x"] == .number(.integer(42000)))

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Value.self, from: json)
    #expect(back.x == 42000)
  }

  @Test("encode decode uint32") func encodeDecodeUInt32() throws {
    struct Value: Codable {
      let x: UInt32
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Value(x: 2_000_000_000))
    #expect(json["x"] == .number(.integer(2_000_000_000)))

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Value.self, from: json)
    #expect(back.x == 2_000_000_000)
  }

  @Test("encode decode uint64") func encodeDecodeUInt64() throws {
    struct Value: Codable {
      let x: UInt64
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Value(x: 42))
    #expect(json["x"] == .number(.integer(42)))

    let decoder = OrderedJSONDecoder()
    let back = try decoder.decode(Value.self, from: json)
    #expect(back.x == 42)
  }

  @Test("encode uint64 overflow throws") func encodeUInt64OverflowThrows() throws {
    struct Value: Encodable {
      let x: UInt64
    }
    let encoder = OrderedJSONEncoder()
    // UInt64.max > Int64.max, so encoding should throw
    #expect {
      try encoder.encode(Value(x: UInt64.max))
    } throws: { error in
      guard let encodingError = error as? EncodingError else { return false }
      switch encodingError {
      case .invalidValue(_, let ctx):
        return ctx.debugDescription.contains("overflows Int64")
      default: return false
      }
    }
  }
}
