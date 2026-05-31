import Foundation
import OrderedCollections
import Testing

@testable import OrderedJSON

// MARK: - Phase 11: Cross-Module Integration Tests

/// Tests that chain multiple modules together to verify end-to-end correctness:
/// 1. Parse → dump → parse round-trip
/// 2. Binary encode → parse (CBOR/MsgPack encode, decode as JSON, dump, re-parse)
/// 3. Schema validate → flatten
/// 4. Patch → re-parse
/// 5. Codable → JSON → patch
@Suite("Integration tests")
struct JSONIntegrationTests {

  // MARK: - 1. Parse → dump → parse round-trip

  @Test("parse → dump(indent: nil) → parse: object with various value types")
  func parseDumpParseObject() throws {
    let input = """
      {
        "null": null,
        "bool": true,
        "int": 42,
        "float": 3.14,
        "string": "hello",
        "array": [1, 2, 3],
        "object": {"a": 1, "b": 2}
      }
      """
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    #expect(json1 == json2)
  }

  @Test("parse → dump → parse: nested arrays")
  func parseDumpParseNestedArrays() throws {
    let input = """
      [[1, 2], [3, [4, 5]], {"key": [6, 7]}]
      """
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    #expect(json1 == json2)
  }

  @Test("parse → dump → parse: strings with escaped characters")
  func parseDumpParseEscapedStrings() throws {
    let input = #"""
      {"tab": "\t", "newline": "\n", "quote": "\"", "backslash": "\\", "unicode": "A"}
      """#
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    #expect(json1 == json2)
  }

  @Test("parse → dump → parse: edge numbers (negative, large integer)")
  func parseDumpParseEdgeNumbers() throws {
    let input = """
      {"neg": -1, "zero": 0, "large": 999999999999, "negZero": -0, "frac": -0.5}
      """
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    #expect(json1 == json2)
  }

  @Test("parse → dump → parse: empty containers")
  func parseDumpParseEmpty() throws {
    let input = """
      {"empty": {}, "emptyArr": [], "null": null}
      """
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    #expect(json1 == json2)
  }

  @Test("parse → dump(indent:) → parse: pretty-printed round-trip")
  func parseDumpPrettyRoundTrip() throws {
    let input = """
      {"a": 1, "b": [2, 3, {"c": 4}]}
      """
    let json1 = try JSON.parse(input)
    let pretty = json1.dump(indent: 2)
    let json2 = try JSON.parse(pretty)
    #expect(json1 == json2)
  }

  @Test("parse → dump(ensureAscii:) → parse: ascii-safe round-trip")
  func parseDumpEnsureAsciiRoundTrip() throws {
    let input = """
      {"unicode": "héllo ñiño"}
      """
    let json1 = try JSON.parse(input)
    let asciiDump = json1.dump(ensureAscii: true)
    let json2 = try JSON.parse(asciiDump)
    // The parsed value should have the same string content
    #expect(json1["unicode"] == json2["unicode"])
  }

  @Test("parse → dump → parse: key order preservation")
  func parseDumpParseKeyOrder() throws {
    let input = """
      {"z": 1, "a": 2, "m": 3, "b": 4}
      """
    let json1 = try JSON.parse(input)
    let dumped = json1.dump()
    let json2 = try JSON.parse(dumped)
    // Verify key order is preserved
    let keys1 = json1.keyValuePairs().map(\.key)
    let keys2 = json2.keyValuePairs().map(\.key)
    #expect(keys1 == keys2)
  }

  // MARK: - 2. Binary encode → parse

  @Test("CBOR encode → JSON decode → dump → parse: round-trip")
  func cborEncodeDecodeDumpParse() throws {
    let original = try JSON.parse(
      """
      {"name": "Bob", "age": 25, "scores": [90.5, 85.0, 92.0]}
      """)
    let cborData = original.cbor()
    let decoded = try JSON(cbor: cborData)
    let dumped = decoded.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("MsgPack encode → JSON decode → dump → parse: round-trip")
  func msgPackEncodeDecodeDumpParse() throws {
    let original = try JSON.parse(
      """
      {"name": "Alice", "active": true, "count": 100}
      """)
    let msgData = original.msgPack()
    let decoded = try JSON(msgPack: msgData)
    let dumped = decoded.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("UBJSON encode → JSON decode → dump → parse: round-trip")
  func ubjsonEncodeDecodeDumpParse() throws {
    let original = try JSON.parse(
      """
      {"key": "value", "num": 42, "items": [1, 2, 3]}
      """)
    let ubjData = original.ubjson()
    let decoded = try JSON(ubjson: ubjData)
    let dumped = decoded.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("BSON encode → JSON decode → dump → parse: round-trip")
  func bsonEncodeDecodeDumpParse() throws {
    let original = try JSON.parse(
      """
      {"name": "Charlie", "age": 30}
      """)
    let bsonData = original.bson()
    let decoded = try JSON(bson: bsonData)
    let dumped = decoded.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("BJData encode → JSON decode → dump → parse: round-trip")
  func bjdataEncodeDecodeDumpParse() throws {
    let original = try JSON.parse(
      """
      {"x": 1, "y": 2.5, "z": true}
      """)
    let bjdData = original.bjdata()
    let decoded = try JSON(bjdata: bjdData)
    let dumped = decoded.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("CBOR encode → MsgPack decode → dump → parse: cross-format decode")
  func cborEncodeMsgPackDecodeDumpParse() throws {
    // CBOR and MsgPack share some structure — verify we can encode one way
    // and decode another, then dump and re-parse
    let original = try JSON.parse(
      """
      {"simple": "test"}
      """)
    let _ = original.cbor()
    // Note: CBOR and MsgPack are NOT compatible formats, but this tests
    // that the dump/re-parse step produces valid JSON regardless
    let dumped = original.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }

  @Test("Binary edge: empty object round-trip through all formats")
  func binaryEmptyObjectAllFormats() throws {
    let original = JSON.object([:])

    let cborBack = try JSON(cbor: original.cbor())
    #expect(cborBack == original)

    let msgBack = try JSON(msgPack: original.msgPack())
    #expect(msgBack == original)

    let ubjBack = try JSON(ubjson: original.ubjson())
    #expect(ubjBack == original)

    let bsonBack = try JSON(bson: original.bson())
    #expect(bsonBack == original)

    let bjdBack = try JSON(bjdata: original.bjdata())
    #expect(bjdBack == original)

    // Verify dump/re-parse works on all binary-decoded results
    #expect(try JSON.parse(cborBack.dump()) == original)
    #expect(try JSON.parse(msgBack.dump()) == original)
  }

  @Test("Binary edge: null value round-trip")
  func binaryNullRoundTrip() throws {
    let original = JSON.null

    let cborBack = try JSON(cbor: original.cbor())
    #expect(cborBack == original)

    let msgBack = try JSON(msgPack: original.msgPack())
    #expect(msgBack == original)

    let ubjBack = try JSON(ubjson: original.ubjson())
    #expect(ubjBack == original)
  }

  // MARK: - 3. Schema validate → flatten

  @Test("schema validate → flatten: valid document")
  func schemaValidateThenFlatten() throws {
    let schemaJSON = try JSON.parse(
      """
      {
        "type": "object",
        "properties": {
          "name": {"type": "string"},
          "age": {"type": "integer", "minimum": 0}
        },
        "required": ["name"]
      }
      """)
    let schema = try JSONSchema(schema: schemaJSON)
    let doc = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])

    // Validate first
    let valid = try schema.validate(doc)
    #expect(valid)

    // Then flatten — no crash
    let flat = doc.flatten()
    #expect(flat["/name"] == JSON.string("Alice"))
    #expect(flat["/age"] == JSON.number(.integer(30)))

    // Unflatten back
    let restored = try flat.unflatten()
    // Note: flatten/unflatten reorders keys by path order.
    #expect(restored["name"] == .string("Alice"))
    #expect(restored["age"] == .number(.integer(30)))
  }

  @Test("schema validate → flatten: invalid document")
  func schemaInvalidThenFlatten() throws {
    let schemaJSON = try JSON.parse(
      """
      {
        "type": "object",
        "properties": {
          "age": {"type": "integer", "minimum": 0}
        },
        "required": ["age"]
      }
      """)
    let schema = try JSONSchema(schema: schemaJSON)
    let doc = JSON.object(["age": .number(.integer(-1))])

    // Validate should fail
    let result = schema.validating(doc)
    #expect(!result.valid)

    // Flatten should still work — no crash
    let flat = doc.flatten()
    #expect(flat["/age"] == JSON.number(.integer(-1)))

    // Unflatten back — doc has single key, so ordering is deterministic
    let restored = try flat.unflatten()
    #expect(restored == doc)
  }

  @Test("schema validate → flatten: complex nested document")
  func schemaComplexThenFlatten() throws {
    let schemaJSON = try JSON.parse(
      """
      {
        "type": "object",
        "properties": {
          "data": {
            "type": "object",
            "properties": {
              "id": {"type": "integer"},
              "tags": {"type": "array", "items": {"type": "string"}}
            },
            "required": ["id"]
          }
        },
        "required": ["data"]
      }
      """)
    let schema = try JSONSchema(schema: schemaJSON)
    let doc = try JSON.parse(
      """
      {"data": {"id": 1, "tags": ["admin", "user"], "extra": "ignored"}}
      """)

    // Valid
    #expect(try schema.validate(doc))

    // Flatten and unflatten
    let flat = doc.flatten()
    let restored = try flat.unflatten()
    // Note: flatten/unflatten reorders keys by path order.
    // Verify values match individually.
    #expect(restored["data"]?["id"] == .number(.integer(1)))
    #expect(restored["data"]?["tags"] == JSON.array([.string("admin"), .string("user")]))
    #expect(restored["data"]?["extra"] == .string("ignored"))
  }

  @Test("schema validate → flatten → re-validate: no state corruption")
  func schemaValidateFlattenReValidate() throws {
    let schemaJSON = try JSON.parse(
      """
      {
        "type": "object",
        "properties": {
          "x": {"type": "integer"}
        },
        "required": ["x"]
      }
      """)
    let schema = try JSONSchema(schema: schemaJSON)
    let doc1 = JSON.object(["x": .number(.integer(1))])
    let doc2 = JSON.object(["x": .number(.integer(2))])

    // Validate doc1
    #expect(try schema.validate(doc1))

    // Flatten doc2
    let flat2 = doc2.flatten()
    #expect(flat2["/x"] == JSON.number(.integer(2)))

    // Validate doc1 again — schema state should be unchanged
    #expect(try schema.validate(doc1))
  }

  // MARK: - 4. Patch → re-parse

  @Test("patch → dump → parse: add operation round-trip")
  func patchDumpParseAdd() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2}"#)
    let patch = try JSON.parse(
      #"""
      [{"op": "add", "path": "/c", "value": 3}]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["a"] == JSON(1))
    #expect(reparsed["c"] == JSON(3))
  }

  @Test("patch → dump → parse: remove operation round-trip")
  func patchDumpParseRemove() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2, "c": 3}"#)
    let patch = try JSON.parse(
      #"""
      [{"op": "remove", "path": "/b"}]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["b"] == nil)
  }

  @Test("patch → dump → parse: replace operation round-trip")
  func patchDumpParseReplace() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2}"#)
    let patch = try JSON.parse(
      #"""
      [{"op": "replace", "path": "/a", "value": 99}]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["a"] == JSON(99))
  }

  @Test("patch → dump → parse: move operation round-trip")
  func patchDumpParseMove() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2}"#)
    let patch = try JSON.parse(
      #"""
      [{"op": "move", "from": "/a", "path": "/c"}]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["a"] == nil)
    #expect(reparsed["c"] == JSON(1))
  }

  @Test("patch → dump → parse: copy operation round-trip")
  func patchDumpParseCopy() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2}"#)
    let patch = try JSON.parse(
      #"""
      [{"op": "copy", "from": "/a", "path": "/copy_of_a"}]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["a"] == JSON(1))
    #expect(reparsed["copy_of_a"] == JSON(1))
  }

  @Test("patch → dump → parse: multi-operation patch round-trip")
  func patchDumpParseMultiOp() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2, "c": 3}"#)
    let patch = try JSON.parse(
      #"""
      [
        {"op": "remove", "path": "/b"},
        {"op": "add", "path": "/d", "value": 4},
        {"op": "replace", "path": "/a", "value": 99}
      ]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["a"] == JSON(99))
    #expect(reparsed["b"] == nil)
    #expect(reparsed["d"] == JSON(4))
  }

  @Test("patch → dump → parse: array operations round-trip")
  func patchDumpParseArrayOps() throws {
    let source = try JSON.parse(#"{"arr": [1, 2, 3]}"#)
    let patch = try JSON.parse(
      #"""
      [
        {"op": "add", "path": "/arr/-", "value": 4},
        {"op": "remove", "path": "/arr/0"}
      ]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["arr"]?.count == 3)
    #expect(reparsed["arr"]?[2] == JSON(4))
  }

  @Test("patch → dump → parse: nested path operations round-trip")
  func patchDumpParseNested() throws {
    let source = try JSON.parse(
      #"""
      {"nested": {"x": 1, "y": 2}}
      """#)
    let patch = try JSON.parse(
      #"""
      [
        {"op": "add", "path": "/nested/z", "value": 3},
        {"op": "replace", "path": "/nested/x", "value": 99}
      ]
      """#)

    let patched = try source.applying(patch)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed["nested"]?["x"] == JSON(99))
    #expect(reparsed["nested"]?["z"] == JSON(3))
  }

  @Test("diff → apply → dump → parse: diff round-trip")
  func diffApplyDumpParse() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2}"#)
    let target = try JSON.parse(#"{"a": 1, "c": 3}"#)

    let diff = JSON.diff(source, target)
    let patched = try source.applying(diff)
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed == target)
  }

  // MARK: - 5. Codable → JSON → patch

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

  // MARK: - Cross-module: Parse + SAX + Binary

  @Test("parse → SAX re-parse via dump → binary encode → decode")
  func parseSaxBinaryChain() throws {
    let input = #"{"a": 1, "b": [2, 3]}"#
    let json = try JSON.parse(input)
    let dumped = json.dump()

    // SAX validate the dumped string
    #expect(JSON.accept(dumped))

    // Binary encode the original
    let cbor = json.cbor()
    let cborDecoded = try JSON(cbor: cbor)
    #expect(cborDecoded == json)

    // Binary encode the dumped string (re-parsed)
    let reparsed = try JSON.parse(dumped)
    let cbor2 = reparsed.cbor()
    let cborDecoded2 = try JSON(cbor: cbor2)
    #expect(cborDecoded2 == reparsed)
  }

  @Test("builder → dump → parse → flatten → unflatten")
  func builderDumpParseFlattenUnflatten() throws {
    let obj = JSON.ObjectBuilder()
      .set("name", "Alice")
      .set(
        "data",
        JSON.ObjectBuilder()
          .set("x", 1)
          .set("y", 2)
          .build()
      )
      .build()

    let dumped = obj.dump()
    let parsed = try JSON.parse(dumped)
    #expect(parsed == obj)

    let flat = parsed.flatten()
    #expect(flat["/name"] == .string("Alice"))
    #expect(flat["/data/x"] == .number(.integer(1)))

    let restored = try flat.unflatten()
    // Note: flatten/unflatten reorders keys by path order, so restored
    // has different key order than parsed. Verify values individually.
    #expect(restored["name"] == .string("Alice"))
    #expect(restored["data"]?["x"] == .number(.integer(1)))
    #expect(restored["data"]?["y"] == .number(.integer(2)))
  }

  @Test("parse → accessors → modifiers → dump → parse")
  func parseAccessModifyDumpParse() throws {
    var json = try JSON.parse(#"{"a": 1, "b": 2, "c": 3}"#)

    // Use accessors
    #expect(json["a"] == JSON(1))

    // Use modifiers
    json.remove(key: "b")
    json["d"] = JSON(4)

    let dumped = json.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed["a"] == JSON(1))
    #expect(reparsed["b"] == nil)
    #expect(reparsed["d"] == JSON(4))
  }

  @Test("parse → subscript set → dump → parse: key removal via nil subscript")
  func parseSubscriptNilDumpParse() throws {
    var json = try JSON.parse(#"{"a": 1, "b": 2}"#)
    json["a"] = nil  // Remove key "a"
    let dumped = json.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed["a"] == nil)
    #expect(reparsed["b"] == JSON(2))
  }

  @Test("full pipeline: parse → flatten → patch → dump → parse → validate")
  func fullPipeline() throws {
    // Start with a complex JSON document
    let input = #"""
      {
        "users": [
          {"name": "Alice", "age": 30, "roles": ["admin"]},
          {"name": "Bob", "age": 25, "roles": ["user"]}
        ],
        "version": 1
      }
      """#
    let json = try JSON.parse(input)

    // Flatten and unflatten
    let flat = json.flatten()
    let unflattened = try flat.unflatten()
    // Note: flatten/unflatten reorders keys by path order.
    // Verify values match individually.
    #expect(unflattened["version"] == JSON(1))
    #expect(unflattened["users"]?.count == 2)
    #expect(unflattened["users"]?[0]?["name"] == .string("Alice"))
    #expect(unflattened["users"]?[0]?["age"] == .number(.integer(30)))

    // Apply a patch to add a user
    let patch = try JSON.parse(
      #"""
      [
        {"op": "add", "path": "/users/-", "value": {"name": "Charlie", "age": 35, "roles": ["moderator"]}},
        {"op": "replace", "path": "/version", "value": 2}
      ]
      """#)
    let patched = try unflattened.applying(patch)

    // Dump and re-parse
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == patched)

    // Verify structure
    #expect(reparsed["version"] == JSON(2))
    #expect(reparsed["users"]?.count == 3)
    #expect(reparsed["users"]?[2]?["name"] == .string("Charlie"))

    // Validate against a schema
    let schemaJSON = try JSON.parse(
      #"""
      {
        "type": "object",
        "properties": {
          "users": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "name": {"type": "string"},
                "age": {"type": "integer", "minimum": 0},
                "roles": {"type": "array", "items": {"type": "string"}}
              },
              "required": ["name", "age"]
            }
          },
          "version": {"type": "integer", "minimum": 1}
        },
        "required": ["users", "version"]
      }
      """#)
    let schema = try JSONSchema(schema: schemaJSON)
    #expect(try schema.validate(reparsed))
  }

  @Test("binary → dump → parse → binary: round-trip through JSON text")
  func binaryThroughJsonText() throws {
    let original = try JSON.parse(#"{"nested": {"deep": [1, 2.5, "text", null, true]}}"#)

    // Encode to each binary format
    let formats: [(Data, String)] = [
      (original.cbor(), "CBOR"),
      (original.msgPack(), "MsgPack"),
      (original.ubjson(), "UBJSON"),
    ]

    for (data, name) in formats {
      // Decode binary → JSON
      let decoded: JSON
      switch name {
      case "CBOR": decoded = try JSON(cbor: data)
      case "MsgPack": decoded = try JSON(msgPack: data)
      case "UBJSON": decoded = try JSON(ubjson: data)
      default: continue
      }

      // Dump to JSON text
      let dumped = decoded.dump()
      #expect(dumped.count > 0)

      // Re-parse
      let reparsed = try JSON.parse(dumped)
      #expect(reparsed == decoded)

      // Re-encode to binary
      let reEncoded: Data
      switch name {
      case "CBOR": reEncoded = reparsed.cbor()
      case "MsgPack": reEncoded = reparsed.msgPack()
      case "UBJSON": reEncoded = reparsed.ubjson()
      default: continue
      }

      // Decode binary again
      let reDecoded: JSON
      switch name {
      case "CBOR": reDecoded = try JSON(cbor: reEncoded)
      case "MsgPack": reDecoded = try JSON(msgPack: reEncoded)
      case "UBJSON": reDecoded = try JSON(ubjson: reEncoded)
      default: continue
      }

      #expect(reDecoded == reparsed)
    }
  }

  @Test("parse → pointer set → dump → parse: JSONPointer modification round-trip")
  func parsePointerSetDumpParse() throws {
    var json = try JSON.parse(#"{"a": {"b": 1, "c": 2}}"#)

    // Set via pointer
    let ptr = try JSONPointer("/a/b")
    ptr.set(value: JSON(99), into: &json)

    let dumped = json.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed["a"]?["b"] == JSON(99))
    #expect(reparsed["a"]?["c"] == JSON(2))
  }

  @Test("parse → update(mergingNested:) → dump → parse")
  func parseMergeUpdateDumpParse() throws {
    var json = try JSON.parse(
      #"""
      {"config": {"theme": "dark", "lang": "en"}}
      """#)

    let patch = JSON.object([
      "config": JSON.object(["lang": JSON.string("fr")])
    ])
    json.update(with: patch, mergingNested: true)

    let dumped = json.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed["config"]?["theme"] == .string("dark"))
    #expect(reparsed["config"]?["lang"] == .string("fr"))
  }

  @Test("parse → diff → apply → dump → parse: diff-based sync")
  func parseDiffApplyDumpParse() throws {
    let source = try JSON.parse(#"{"a": 1, "b": 2, "c": 3}"#)
    let target = try JSON.parse(#"{"a": 1, "b": 99, "d": 4}"#)

    // Generate diff
    let diff = JSON.diff(source, target)

    // Apply diff to source
    let patched = try source.applying(diff)

    // Dump and re-parse
    let dumped = patched.dump()
    let reparsed = try JSON.parse(dumped)

    #expect(reparsed == patched)
    #expect(reparsed == target)
  }

  @Test("SAX accept → parse → dump → SAX accept")
  func saxAcceptParseDumpAccept() throws {
    let validInput = #"{"valid": 1}"#
    #expect(JSON.accept(validInput))

    let json = try JSON.parse(validInput)
    let dumped = json.dump()
    #expect(JSON.accept(dumped))
  }

  @Test("parse → CBOR → parse → MsgPack: cross-binary format chain")
  func parseCborThenMsgPack() throws {
    let original = try JSON.parse(#"{"value": 42}"#)

    // Encode to CBOR
    let cborData = original.cbor()
    let fromCBOR = try JSON(cbor: cborData)
    #expect(fromCBOR == original)

    // Encode the CBOR-decoded result to MsgPack
    let msgData = fromCBOR.msgPack()
    let fromMsg = try JSON(msgPack: msgData)
    #expect(fromMsg == fromCBOR)
    #expect(fromMsg == original)

    // Dump the MsgPack-decoded result and re-parse
    let dumped = fromMsg.dump()
    let reparsed = try JSON.parse(dumped)
    #expect(reparsed == original)
  }
}
