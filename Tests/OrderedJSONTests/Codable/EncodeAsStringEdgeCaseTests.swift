import Foundation
import Testing

@testable import OrderedJSON

@Suite("EncodeAsString Edge Cases") struct EncodeAsStringEdgeCaseTests {
  @Test("encode empty struct as string") func encodeEmptyStruct() throws {
    struct Empty: Encodable {}
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString(Empty())
    #expect(str == "{}")
  }

  @Test("encode null as string") func encodeNull() throws {
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString(JSON.null)
    #expect(str == "null")
  }

  @Test("encode empty array as string") func encodeEmptyArray() throws {
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString([String]())
    #expect(str == "[]")
  }

  @Test("encodeAsString matches dump(indent: nil)") func encodeAsStringMatchesDump() throws {
    struct Person: Encodable {
      let name: String
      let age: Int
    }
    let encoder = OrderedJSONEncoder()
    let json = try encoder.encode(Person(name: "Alice", age: 30))
    let dumpString = json.dump(indent: nil)
    let encodeString = try encoder.encodeAsString(Person(name: "Alice", age: 30))
    #expect(encodeString == dumpString)
  }

  @Test("encode deeply nested as string") func encodeDeeplyNested() throws {
    struct Inner: Encodable {
      let value: Int
    }
    struct Outer: Encodable {
      let inner: Inner
    }
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString(Outer(inner: Inner(value: 42)))
    #expect(str == "{\"inner\":{\"value\":42}}")
  }

  @Test("encode array of structs as string") func encodeArrayOfStructs() throws {
    struct Item: Encodable {
      let id: Int
    }
    let encoder = OrderedJSONEncoder()
    let str = try encoder.encodeAsString([Item(id: 1), Item(id: 2)])
    #expect(str == "[{\"id\":1},{\"id\":2}]")
  }

  @Test("encodeAsString with date strategy") func encodeAsStringWithDate() throws {
    struct Container: Encodable {
      let timestamp: Date
    }
    var encoder = OrderedJSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    let date = Date(timeIntervalSince1970: 1_000_000)
    let str = try encoder.encodeAsString(Container(timestamp: date))
    #expect(str == "{\"timestamp\":1000000.0}" || str == "{\"timestamp\":1000000}")
  }
}
