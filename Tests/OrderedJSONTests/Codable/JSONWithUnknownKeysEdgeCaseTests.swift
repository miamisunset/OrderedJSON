import Foundation
import OrderedCollections
import Testing

@testable import OrderedJSON

@Suite("JSONWithUnknownKeys Edge Cases") struct JSONWithUnknownKeysEdgeCaseTests {
  @Test("all keys matched produces empty extras") func allKeysMatched() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    let json = JSON.object([
      "name": .string("Alice"),
      "age": .number(.integer(30)),
    ])
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: json)
    #expect(wrapped.value.name == "Alice")
    #expect(wrapped.value.age == 30)
    #expect(wrapped.unknownKeys.isEmpty)
  }

  @Test("no keys matched wraps entire object as extras") func noKeysMatched() throws {
    struct Empty: Decodable {
      // No CodingKeys — empty struct
    }
    let json = JSON.object([
      "a": .string("1"),
      "b": .number(.integer(2)),
    ])
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Empty>.self, from: json)
    #expect(wrapped.unknownKeys.count == 2)
    #expect(wrapped.unknownKeys["a"] == .string("1"))
    #expect(wrapped.unknownKeys["b"] == .number(.integer(2)))
  }

  @Test("null values in unknown keys preserved") func nullValuesInUnknownKeys() throws {
    struct Person: Decodable {
      let name: String
    }
    let json = JSON.object([
      "name": .string("Alice"),
      "extra": .null,
    ])
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: json)
    #expect(wrapped.value.name == "Alice")
    #expect(wrapped.unknownKeys["extra"] == .null)
  }

  @Test("decodeIfPresent does not mark absent keys as accessed")
  func decodeIfPresentDoesNotMarkAbsent() throws {
    // Regression: decodeIfPresent for an absent key should not mark it as "accessed",
    // so it should appear in extras
    struct TestStruct: Decodable {
      let x: String
      let y: String?
      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decode(String.self, forKey: .x)
        y = try container.decodeIfPresent(String.self, forKey: .y)
      }
      enum CodingKeys: String, CodingKey {
        case x, y
      }
    }
    // "y" is absent, so decodeIfPresent will call decodeNil which marks it as accessed.
    // This means "y" won't appear in extras (it was accessed).
    // But "z" should appear in extras since it was never accessed.
    let json = JSON.object([
      "x": .string("hello"),
      "z": .string("extra"),
    ])
    let decoder = OrderedJSONDecoder()
    let decoded = try decoder.decode(JSONWithUnknownKeys<TestStruct>.self, from: json)
    #expect(decoded.value.x == "hello")
    #expect(decoded.value.y == nil)
    #expect(decoded.unknownKeys["z"] == .string("extra"))
    // "y" was accessed via decodeNil, so it won't be in extras
    #expect(decoded.unknownKeys["y"] == nil)
  }

  @Test("contains marks key as accessed") func containsMarksKeyAccessed() throws {
    // Regression: using contains(_:) should mark the key as accessed
    struct TestStruct: Decodable {
      let x: String
      let y: String?
      init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        x = try container.decode(String.self, forKey: .x)
        // Using contains marks "y" as accessed even though we don't decode it
        if container.contains(CodingKeys.y) {
          y = try container.decodeIfPresent(String.self, forKey: .y)
        } else {
          y = nil
        }
      }
      enum CodingKeys: String, CodingKey {
        case x, y
      }
    }
    // "y" is present, and contains marks it as accessed, so it won't be in extras
    let json = JSON.object([
      "x": .string("hello"),
      "y": .string("world"),
      "z": .string("extra"),
    ])
    let decoder = OrderedJSONDecoder()
    let decoded = try decoder.decode(JSONWithUnknownKeys<TestStruct>.self, from: json)
    #expect(decoded.value.x == "hello")
    #expect(decoded.value.y == "world")
    #expect(decoded.unknownKeys["z"] == .string("extra"))
    // "y" was accessed via contains, so it won't be in extras
    #expect(decoded.unknownKeys["y"] == nil)
  }
}
