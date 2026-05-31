import OrderedCollections
import Testing

@testable import OrderedJSON

@Suite("Key Order Preservation Edge Cases") struct KeyOrderPreservationEdgeCaseTests {
  @Test("key order through JSONWithUnknownKeys") func keyOrderThroughJSONWithUnknownKeys() throws {
    struct Person: Decodable {
      let name: String
      let age: Int
    }
    // Keys in non-alphabetical order
    let jsonString = #"{"z": "last", "a": "first", "m": "middle", "name": "Alice", "age": 30}"#
    let decoder = OrderedJSONDecoder()
    let wrapped = try decoder.decode(JSONWithUnknownKeys<Person>.self, from: jsonString)
    // Check that unknown keys preserve order: z, a, m
    guard case .object(let unknownDict) = wrapped.unknownKeys.storage else {
      #expect(Bool(false), "expected object")
      return
    }
    let unknownKeys = Array(unknownDict.keys)
    #expect(unknownKeys[0] == "z")
    #expect(unknownKeys[1] == "a")
    #expect(unknownKeys[2] == "m")
  }

  @Test("key order through nested decoder") func keyOrderThroughNestedDecoder() throws {
    // Decode a JSON with specific key order, then verify JSON's keys match
    let jsonString = #"{"c": 1, "b": 2, "a": 3}"#
    let decoder = OrderedJSONDecoder()
    let json: JSON = try decoder.decode(JSON.self, from: jsonString)
    guard case .object(let dict) = json.storage else {
      #expect(Bool(false), "expected object")
      return
    }
    let keys = Array(dict.keys)
    #expect(keys[0] == "c")
    #expect(keys[1] == "b")
    #expect(keys[2] == "a")
  }

  @Test("key order through encode then decode preserves") func keyOrderEncodeDecodePreserves()
    throws
  {
    struct Ordered: Codable {
      let z: String
      let a: String
      let m: String
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Ordered(z: "1", a: "2", m: "3"))
    let decoder = OrderedJSONDecoder()
    let decoded: JSON = try decoder.decode(JSON.self, from: json)
    guard case .object(let dict) = decoded.storage else {
      #expect(Bool(false), "expected object")
      return
    }
    let keys = Array(dict.keys)
    // Keys should be in declaration order: z, a, m
    #expect(keys[0] == "z")
    #expect(keys[1] == "a")
    #expect(keys[2] == "m")
  }

  @Test("key order with nested objects preserves") func keyOrderNestedObjects() throws {
    struct Inner: Encodable {
      let b: Int
      let a: Int
    }
    struct Outer: Encodable {
      let inner: Inner
      let z: Int
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Outer(inner: Inner(b: 1, a: 2), z: 3))
    guard case .object(let outerDict) = json.storage else {
      #expect(Bool(false), "expected object")
      return
    }
    let outerKeys = Array(outerDict.keys)
    #expect(outerKeys[0] == "inner")
    #expect(outerKeys[1] == "z")
    guard case .object(let innerDict) = outerDict["inner"]?.storage else {
      #expect(Bool(false), "expected inner object")
      return
    }
    let innerKeys = Array(innerDict.keys)
    #expect(innerKeys[0] == "b")
    #expect(innerKeys[1] == "a")
  }
}
