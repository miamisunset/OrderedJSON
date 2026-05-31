import Foundation
import OrderedCollections
import Testing

@testable import OrderedJSON

extension JSON {
  /// Returns the keys of an object in insertion order, or nil if not an object.
  package var keys: [String]? {
    guard case .object(let dict) = storage else { return nil }
    return Array(dict.keys)
  }
}

@Suite("OrderedJSONEncoder Tests") struct OrderedJSONEncoderTests {
  @Test("ordered encoder simple struct") func orderedEncoderSimpleStruct() throws {
    struct Person: Encodable {
      let name: String
      let age: Int
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Person(name: "Alice", age: 30))
    #expect(json.isObject)
    #expect(json["name"] == .string("Alice"))
    #expect(json["age"] == .number(.integer(30)))
  }

  @Test("ordered encoder preserves key order") func orderedEncoderPreservesKeyOrder() throws {
    struct Ordered: Encodable {
      let z: Int
      let a: Int
      let m: Int
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Ordered(z: 1, a: 2, m: 3))
    #expect(json.isObject)
    #expect(json.count == 3)
    // Keys should be in declaration order: z, a, m
    let keys = json.keys
    #expect(keys?[0] == "z")
    #expect(keys?[1] == "a")
    #expect(keys?[2] == "m")
  }

  @Test("ordered encoder nested") func orderedEncoderNested() throws {
    struct Address: Encodable {
      let city: String
      let zip: String
    }
    struct Person: Encodable {
      let name: String
      let address: Address
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(
      Person(
        name: "Alice",
        address: Address(city: "NYC", zip: "10001")
      )
    )
    #expect(json["name"] == .string("Alice"))
    #expect(json["address"]?.isObject == true)
    #expect(json["address"]?["city"] == .string("NYC"))
    #expect(json["address"]?["zip"] == .string("10001"))
  }

  @Test("ordered encoder array") func orderedEncoderArray() throws {
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(["a", "b", "c"])
    #expect(json.isArray)
    #expect(json.count == 3)
    #expect(json[0] == .string("a"))
  }

  @Test("ordered encoder to string") func orderedEncoderToString() throws {
    struct Item: Encodable {
      let id: Int
      let value: String
    }
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString(Item(id: 1, value: "test"))
    #expect(str == #"{"id":1,"value":"test"}"#)
  }
}
