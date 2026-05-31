import Foundation
import Testing

@testable import OrderedJSON

@Suite("Encoder Error Handling Edge Cases") struct EncoderErrorHandlingEdgeCaseTests {
  @Test("UInt64 overflow during encode throws") func uint64Overflow() throws {
    struct Container: Encodable {
      let value: UInt64
    }
    let encoder = OrderedJSONEncoder()
    #expect(throws: EncodingError.self) {
      try encoder.encode(Container(value: UInt64.max))
    }
  }

  @Test("Int overflow during encode as integer") func intOverflow() throws {
    struct Container: Encodable {
      let value: Int
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Container(value: Int.min))
    #expect(json["value"] == .number(.integer(Int64(Int.min))))
  }

  @Test("nan float in encoder throws") func nanFloatInEncoderThrows() throws {
    let encoder = OrderedJSONEncoder()
    #expect(throws: EncodingError.self) {
      try encoder.encode(Double.nan)
    }
  }

  @Test("infinity float in encoder throws") func infinityFloatInEncoderThrows() throws {
    let encoder = OrderedJSONEncoder()
    #expect(throws: EncodingError.self) {
      try encoder.encode(Double.infinity)
    }
  }

  @Test("nan float in json struct encoder produces null") func nanFloatInJSONStructEncoder() throws
  {
    let json = JSON.number(.float(Double.nan))
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded.isNull)
  }
}
