import Foundation
import Testing

@testable import OrderedJSON

@Suite("Super Encoder Edge Cases") struct SuperEncoderEdgeCaseTests {
  @Test("super encoder forKey writes correct key") func superEncoderForKey() throws {
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
        // Super encoder for the parent class under explicit key "parent"
        let superEncoder = container.superEncoder(forKey: .parent)
        try super.encode(to: superEncoder)
      }
      enum CodingKeys: CodingKey {
        case derivedValue
        case parent
      }
    }

    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Derived())
    #expect(json["derivedValue"] == .string("hello"))
    #expect(json["parent"]?.isObject == true)
    #expect(json["parent"]?["baseValue"] == .number(.integer(42)))
  }

  @Test("super encoder nested subclass") func superEncoderNestedSubclass() throws {
    class GrandBase: Encodable {
      let grandValue: String = "grand"
      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(grandValue, forKey: .grandValue)
      }
      enum CodingKeys: CodingKey {
        case grandValue
      }
    }

    class Mid: GrandBase {
      let midValue: Int = 1
      override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(midValue, forKey: .midValue)
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
      }
      enum CodingKeys: CodingKey {
        case midValue
      }
    }

    class Derived: Mid {
      let derivedValue: Bool = true
      override func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(derivedValue, forKey: .derivedValue)
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
      }
      enum CodingKeys: CodingKey {
        case derivedValue
      }
    }

    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Derived())
    #expect(json["derivedValue"] == .boolean(true))
    #expect(json["super"]?.isObject == true)
    let mid = json["super"]
    #expect(mid?["midValue"] == .number(.integer(1)))
    let grand = mid?["super"]
    #expect(grand?["grandValue"] == .string("grand"))
  }

  @Test("super encoder round trip encodes correct structure") func superEncoderRoundTrip() throws {
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
        let superEncoder = container.superEncoder()
        try super.encode(to: superEncoder)
      }
      enum CodingKeys: CodingKey {
        case derivedValue
      }
    }

    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Derived())
    #expect(json["derivedValue"] == .string("hello"))
    #expect(json["super"]?.isObject == true)
    #expect(json["super"]?["baseValue"] == .number(.integer(42)))
  }
}
