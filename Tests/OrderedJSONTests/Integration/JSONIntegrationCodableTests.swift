import Foundation
import Testing

@testable import OrderedJSON

@Suite("Integration: Codable → JSON → patch")
struct JSONIntegrationCodableTests {
  struct IntegrationPerson: Codable, Equatable {
    let name: String
    let age: Int
    let active: Bool
  }

  @Test("Codable encode → JSON → patch → decode back")
  func codableJsonPatchDecode() throws {
    let person = IntegrationPerson(name: "Alice", age: 30, active: true)
    let json = try JSON.encode(person)

    // Apply a patch that modifies age and adds a new field
    let patch = try JSON.parse(
      #"""
      [
        {"op": "replace", "path": "/age", "value": 31},
        {"op": "add", "path": "/role", "value": "admin"}
      ]
      """#)

    let patched = try json.applying(patch)

    // Decode back — should still work (unknown key "role" is ignored by Codable)
    let decoder = OrderedJSONDecoder()
    let decoded = try decoder.decode(IntegrationPerson.self, from: patched)

    #expect(decoded.name == "Alice")
    #expect(decoded.age == 31)
    #expect(decoded.active == true)
  }

  @Test("Codable encode → dump → parse → patch → encode → decode")
  func codableDumpParsePatchEncodeDecode() throws {
    let person = IntegrationPerson(name: "Bob", age: 25, active: false)
    let json = try JSON.encode(person)

    // Dump and re-parse
    let dumped = json.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == json)

    // Apply patch
    let patch = try JSON.parse(
      #"""
      [{"op": "replace", "path": "/active", "value": true}]
      """#)
    let patched = try reparsed.applying(patch)

    // Decode the patched JSON back to IntegrationPerson
    let decoded = try OrderedJSONDecoder().decode(IntegrationPerson.self, from: patched)

    #expect(decoded.name == "Bob")
    #expect(decoded.age == 25)
    #expect(decoded.active == true)
  }

  @Test("Codable → JSON → merge patch → decode back")
  func codableJsonMergePatchDecode() throws {
    let person = IntegrationPerson(name: "Alice", age: 30, active: true)
    let json = try JSON.encode(person)

    // Apply merge patch that changes age and removes active (set to null)
    let mergePatch = try JSON.parse(
      #"""
      {"age": 31, "active": null}
      """#)
    let merged = json.mergePatch(mergePatch)

    // Verify merge result structure — active was removed (null in merge = remove)
    #expect(merged["name"] == .string("Alice"))
    #expect(merged["age"] == .number(.integer(31)))
    #expect(merged["active"] == nil)

    // Decode with a version that only has name and age (active is optional)
    struct PersonWithOptionalActive: Codable {
      let name: String
      let age: Int
      let active: Bool?
    }
    let decoded = try OrderedJSONDecoder().decode(PersonWithOptionalActive.self, from: merged)
    #expect(decoded.name == "Alice")
    #expect(decoded.age == 31)
    #expect(decoded.active == nil)
  }

  @Test("JSONWithUnknownKeys → patch → decode back")
  func jsonWithUnknownKeysPatchDecode() throws {
    struct Person: Codable {
      let name: String
    }

    let data = Data(
      #"""
      {"name": "Alice", "color": "blue", "city": "NYC"}
      """#.utf8)

    let wrapped = try OrderedJSONDecoder().decode(
      JSONWithUnknownKeys<Person>.self, from: data)

    let json = try JSON.encode(wrapped.value)

    // Apply a patch that changes name
    let patch = try JSON.parse(
      #"""
      [{"op": "replace", "path": "/name", "value": "Bob"}]
      """#)
    let patched = try json.applying(patch)

    let decoded = try OrderedJSONDecoder().decode(Person.self, from: patched)
    #expect(decoded.name == "Bob")
  }
}
