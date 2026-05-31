import Testing

@testable import OrderedJSON

@Suite("Nested Container Tests") struct JSONNestedContainerTests {
  @Test("explicit nested container encode") func explicitNestedContainerEncode() throws {
    struct Inner: Encodable {
      let x: Int
    }
    struct Outer: Encodable {
      let inner: Inner

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var nested = container.nestedContainer(
          keyedBy: InnerKeys.self, forKey: .inner
        )
        try nested.encode(inner.x, forKey: .x)
      }

      enum CodingKeys: CodingKey {
        case inner
      }

      enum InnerKeys: CodingKey {
        case x
      }
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Outer(inner: Inner(x: 42)))
    // The inner object should be populated, not empty/null
    #expect(json["inner"]?.isObject == true)
    #expect(json["inner"]?["x"] == .number(.integer(42)))
  }

  @Test("explicit nested unkeyed container encode") func explicitNestedUnkeyedContainerEncode()
    throws
  {
    struct Wrapper: Encodable {
      let items: [Int]

      func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        var nested = container.nestedUnkeyedContainer(forKey: .items)
        try nested.encode(1)
        try nested.encode(2)
        try nested.encode(3)
      }

      enum CodingKeys: CodingKey {
        case items
      }
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Wrapper(items: []))
    // The array should be populated, not empty
    #expect(json["items"]?.isArray == true)
    #expect(json["items"]?.count == 3)
    #expect(json["items"]?[0] == .number(.integer(1)))
    #expect(json["items"]?[1] == .number(.integer(2)))
    #expect(json["items"]?[2] == .number(.integer(3)))
  }
}
