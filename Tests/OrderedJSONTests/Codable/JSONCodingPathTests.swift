import Testing

@testable import OrderedJSON

@Suite("Coding Path Tests") struct JSONCodingPathTests {
  @Test("coding path includes keys") func codingPathIncludesKeys() throws {
    struct Inner: Decodable {
      let x: Int
    }
    struct Outer: Decodable {
      let inner: Inner
    }
    // Missing "x" key in inner should produce path ["inner", "x"]
    let json = #"{"inner": {}}"#
    let decoder = OrderedJSONDecoder()
    #expect {
      try decoder.decode(Outer.self, from: json)
    } throws: { error in
      guard let decodingError = error as? DecodingError else { return false }
      switch decodingError {
      case .keyNotFound(let key, let ctx):
        // key should be "x" and path should include "inner"
        return key.stringValue == "x" && ctx.codingPath.count >= 1
      default: return false
      }
    }
  }
}
