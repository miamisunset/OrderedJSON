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

  @Test("encodeAsString with pretty outputOptions")
  func encodeAsStringPrettyOutputOptions() throws {
    struct Person: Encodable {
      let name: String
      let age: Int
    }
    var encoder = OrderedJSONEncoder()
    encoder.outputOptions.indent = .spaces(2)
    let str = try encoder.encodeAsString(Person(name: "Alice", age: 30))
    #expect(str.contains("\n"))
    #expect(str.contains("  "))
  }

  @Test("encodeAsData returns valid UTF-8 data")
  func encodeAsDataValidUTF8() throws {
    struct Person: Encodable {
      let name: String
      let age: Int
    }
    let encoder = OrderedJSONEncoder()
    let data = try encoder.encodeAsData(Person(name: "Alice", age: 30))
    #expect(data.count > 0)
    // Re-parse to verify validity
    let decoded = try JSON.parse(data)
    #expect(decoded["name"] == .string("Alice"))
    #expect(decoded["age"] == .number(.integer(30)))
  }

  @Test("sortedKeys true produces alphabetically sorted keys")
  func sortedKeysTrue() throws {
    struct Unsorted: Encodable {
      let z: Int
      let a: Int
      let m: Int
    }
    var encoder = OrderedJSONEncoder()
    encoder.outputOptions.sortedKeys = true
    let str = try encoder.encodeAsString(Unsorted(z: 1, a: 2, m: 3))
    // Keys should be a, m, z in sorted output
    let aIdx = try #require(str.firstIndex(of: Character("a")))
    let mIdx = try #require(str.firstIndex(of: Character("m")))
    let zIdx = try #require(str.firstIndex(of: Character("z")))
    #expect(aIdx < mIdx)
    #expect(mIdx < zIdx)
  }

  @Test("sortedKeys false preserves insertion order (default)")
  func sortedKeysFalse() throws {
    struct Unsorted: Encodable {
      let z: Int
      let a: Int
      let m: Int
    }
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString(Unsorted(z: 1, a: 2, m: 3))
    // Default: keys should be in declaration order: z, a, m
    let zIdx = try #require(str.firstIndex(of: Character("z")))
    let aIdx = try #require(str.firstIndex(of: Character("a")))
    #expect(zIdx < aIdx)
  }
}
