import Foundation
import Testing

@testable import OrderedJSON

@Suite("JSON Encoder Special Float Handling") struct JSONEncoderSpecialFloatTests {
  @Test("float nan in JSON encode to encoder") func floatNanInJSONEncode() throws {
    // When JSON (which conforms to Encodable) encodes a NaN float,
    // it should encode as null per the JSON: Encodable implementation
    let json = JSON.number(.float(Double.nan))
    let encoder = JSONEncoder()
    let data = try encoder.encode(json)
    let string = try #require(String(data: data, encoding: .utf8))
    #expect(string == "null")
  }

  @Test("float infinity in JSON encode to encoder") func floatInfinityInJSONEncode() throws {
    let json = JSON.number(.float(Double.infinity))
    let encoder = JSONEncoder()
    let data = try encoder.encode(json)
    let string = try #require(String(data: data, encoding: .utf8))
    #expect(string == "null")
  }

  @Test("ordered encoder float nan in JSON encode") func orderedEncoderFloatNan() throws {
    let json = JSON.number(.float(Double.nan))
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded.isNull)
  }

  @Test("ordered encoder float infinity in JSON encode") func orderedEncoderFloatInfinity() throws {
    let json = JSON.number(.float(Double.infinity))
    let encoder = OrderedJSONEncoder()
    let encoded = try encoder.encode(json)
    #expect(encoded.isNull)
  }

  @Test("JSON encode struct with nan double throws") func structWithNanDoubleThrows() throws {
    struct Container: Encodable {
      let value: Double
    }
    let encoder = OrderedJSONEncoder()
    #expect(throws: EncodingError.self) {
      try encoder.encode(Container(value: Double.nan))
    }
  }

  @Test("JSON encode struct with inf double throws") func structWithInfDoubleThrows() throws {
    struct Container: Encodable {
      let value: Double
    }
    let encoder = OrderedJSONEncoder()
    #expect(throws: EncodingError.self) {
      try encoder.encode(Container(value: Double.infinity))
    }
  }
}
