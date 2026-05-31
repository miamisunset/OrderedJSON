import Foundation
import Testing

@testable import OrderedJSON

@Suite("Integration: cross-module tests")
struct JSONIntegrationCrossModuleTests {
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
