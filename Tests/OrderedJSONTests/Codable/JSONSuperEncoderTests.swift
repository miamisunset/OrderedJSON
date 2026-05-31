import Testing

@testable import OrderedJSON

@Suite("Super Encoder Tests") struct JSONSuperEncoderTests {
  @Test("super encoder writes under super key") func superEncoderWritesUnderSuperKey() throws {
    class Base: Encodable {
      let baseValue: Int = 42
      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseValue, forKey: .baseValue)
      }

      enum CodingKeys: CodingKey {
        case baseValue
      }
    }

    class Derived: Base {
      let derivedValue: String = "hello"

      override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(derivedValue, forKey: .derivedValue)

        // Super encoder for the parent class — writes under "super" key
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
      }

      enum CodingKeys: CodingKey {
        case derivedValue
      }
    }

    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Derived())
    // The "super" key should contain the base class's encoded value
    #expect(json["derivedValue"] == .string("hello"))
    #expect(json["super"]?.isObject == true)
    #expect(json["super"]?["baseValue"] == .number(.integer(42)))
  }
}
