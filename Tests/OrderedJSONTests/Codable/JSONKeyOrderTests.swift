import Testing

@testable import OrderedJSON

@Suite("Key Order Tests") struct JSONKeyOrderTests {
  @Test("ordered decoder key order for struct") func orderedDecoderKeyOrderForStruct() throws {
    struct Ordered: Decodable {
      let z: String
      let a: String
      let m: String

      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // Record the order of allKeys
        let keys = container.allKeys.map { $0.stringValue }
        // allKeys should be in insertion order: z, a, m
        #expect(keys == ["z", "a", "m"])
        z = try container.decode(String.self, forKey: .z)
        a = try container.decode(String.self, forKey: .a)
        m = try container.decode(String.self, forKey: .m)
      }

      enum CodingKeys: CodingKey {
        case z, a, m
      }
    }
    let jsonString = #"{"z": "1", "a": "2", "m": "3"}"#
    let decoder = OrderedJSONDecoder()
    _ = try decoder.decode(Ordered.self, from: jsonString)
  }
}
