import Foundation
import Testing

@testable import OrderedJSON

// MARK: - README Example Verification Tests
// Each test corresponds to a code example from the README.
// These verify that the examples compile and produce the expected output.

// MARK: - Quick Start

@Test func readmeQuickStart() throws {
  let json = """
    {"z": 1, "a": 2, "m": 3}
    """
  let value = try JSON.parse(json)

  #expect(value.count == 3)
  #expect(value["z"] == JSON.number(.integer(1)))

  let output = value.dump()
  #expect(output == "{\"z\":1,\"a\":2,\"m\":3}")
}

// MARK: - Creating Values

@Test func readmeCreatingValues() {
  // Factory methods
  let str = JSON.string("hello")
  let num = JSON.number(.integer(42))
  let flt = JSON.number(.float(3.14))
  let bool = JSON.boolean(true)
  let nul = JSON.null
  let nul2 = JSON.null

  #expect(str.isString)
  #expect(num.isNumber)
  #expect(flt.isNumber)
  #expect(bool.isBoolean)
  #expect(nul.isNull)
  #expect(nul2.isNull)

  // Convenience initializers
  let s = JSON("hello")
  let n = JSON(42)
  let x = JSON(3.14)
  let b = JSON(true)

  #expect(s.isString)
  #expect(n.isInteger)
  #expect(x.isFloat)
  #expect(b.isBoolean)

  // Arrays
  let arr = JSON.array([
    JSON.string("a"),
    JSON.number(.integer(1)),
    JSON.boolean(false),
    JSON.null,
  ])
  #expect(arr.isArray)
  #expect(arr.count == 4)

  // Objects
  let obj = JSON.object([
    "name": JSON.string("Alice"),
    "age": JSON.number(.integer(30)),
    "city": JSON.string("New York"),
  ])
  #expect(obj.isObject)
  #expect(obj.count == 3)
}

// MARK: - JSONBuilder

@Test func readmeObjectBuilder() {
  let person = JSON.ObjectBuilder()
    .set("name", "Alice")
    .set("age", 30)
    .set("active", true)
    .set("pi", 3.14)
    .build()
  #expect(person.isObject)
  #expect(person.count == 4)
  #expect(person["name"] == JSON.string("Alice"))
}

@Test func readmeObjectBuilderNested() {
  let nested = JSON.ObjectBuilder()
    .set("name", "Alice")
    .set(
      "address",
      JSON.ObjectBuilder()
        .set("city", "NYC")
        .set("zip", "10001")
        .build()
    )
    .set(
      "tags",
      JSON.ArrayBuilder()
        .add("admin")
        .add("user")
        .build()
    )
    .build()
  #expect(nested.isObject)
  #expect(nested.count == 3)
}

@Test func readmeArrayBuilder() {
  let items = JSON.ArrayBuilder()
    .add("a")
    .add(42)
    .add(true)
    .add(3.14)
    .build()
  #expect(items.isArray)
  #expect(items.count == 4)
}

@Test func readmeArrayBuilderNested() {
  let mixed = JSON.ArrayBuilder()
    .add("outer")
    .add(
      JSON.ObjectBuilder()
        .set("x", 1)
        .build()
    )
    .add(
      JSON.ArrayBuilder()
        .add("inner")
        .add(99)
        .build()
    )
    .build()
  #expect(mixed.isArray)
  #expect(mixed.count == 3)
}

// MARK: - Parsing JSON

@Test func readmeParsing() throws {
  let jsonString = """
    {"c": 3, "a": 1, "b": 2}
    """
  let parsed = try JSON.parse(jsonString)
  #expect(parsed.isObject)
  #expect(parsed.count == 3)
}

@Test func readmeDuplicateKeys() throws {
  let dupes = try JSON.parse(
    """
    {"x": 1, "x": 2, "x": 3}
    """)
  #expect(dupes["x"] == JSON.number(.integer(3)))
}

@Test func readmeParserOptions() throws {
  // Default options
  let _ = JSON.ParserOptions.default

  // Custom options
  var opts = JSON.ParserOptions(allowTrailingCommas: true)
  opts.maxDepth = 512

  // Trailing commas
  let trailing = try JSON.parse("[1, 2, 3,]", options: opts)
  #expect(trailing.isArray)
  #expect(trailing.count == 3)

  // Safety: limit nesting
  let safe = JSON.ParserOptions(maxDepth: 64)
  let untrustedInput = "{\"a\": 1}"
  let parsed = try JSON.parse(untrustedInput, options: safe)
  #expect(parsed.isObject)
}

@Test func readmeParsingFromData() throws {
  let data = "{\"key\": \"value\"}".data(using: .utf8)!
  let parsed = try JSON.parse(data)
  #expect(parsed["key"] == JSON.string("value"))

  // With options
  let opts = JSON.ParserOptions(allowTrailingCommas: true)
  let parsed2 = try JSON.parse(data, options: opts)
  #expect(parsed2["key"] == JSON.string("value"))
}

@Test func readmeErrorHandling() throws {
  do {
    let _ = try JSON.parse("{\"a\": }")
  } catch let error as JSONParseError {
    let desc = String(describing: error)
    #expect(desc.contains("line") || desc.contains("Expected"))
  }
}

// MARK: - Encoding / Serialization

@Test func readmeEncodingSerialization() {
  let value = JSON.object([
    "name": JSON.string("Bob"),
    "age": JSON.number(.integer(25)),
  ])

  let compact = value.dump()
  #expect(compact == "{\"name\":\"Bob\",\"age\":25}")

  let pretty = value.dump(indent: 2)
  #expect(pretty.contains("\n"))
  #expect(pretty.contains("  "))
}

// MARK: - Type Checks

@Test func readmeTypeChecks() throws {
  let json = try JSON.parse("{\"x\": 1, \"y\": [2], \"z\": null}")

  let x = try #require(json["x"])
  #expect(x.isNull == false)
  #expect(x.isBoolean == false)
  #expect(x.isNumber)
  #expect(x.isInteger)
  #expect(x.isFloat == false)
  #expect(x.isString == false)
  #expect(x.isObject == false)
  #expect(x.isArray == false)
  #expect(x.isPrimitive)
  #expect(x.isStructured == false)

  #expect(x.type == JSON.JSONType.number)
  #expect(x.typeName == "number")
}

// MARK: - Subscript / At / Value Access

@Test func readmeSubscriptAccess() throws {
  let json = try JSON.parse(
    """
    {"name": "Alice", "items": [10, 20]}
    """)

  // Key subscript
  #expect(json["name"] == JSON.string("Alice"))
  #expect(json["missing"] == nil)

  // Index subscript on array
  #expect(json["items"]?[0] == JSON.number(.integer(10)))

  // Key subscript set
  var mutable = json
  mutable["name"] = JSON.string("Bob")
  #expect(mutable["name"] == JSON.string("Bob"))

  // Index subscript set
  mutable["items"]?[0] = JSON.number(.integer(99))
  #expect(mutable["items"]?[0] == JSON.number(.integer(99)))

  // Throwing access
  #expect(throws: JSONError.self) { try json.at(key: "missing") }
  let name = try json.at(key: "name")
  #expect(name == JSON.string("Alice"))

  // Value with default
  #expect(json.value(forKey: "name", default: JSON.null) == JSON.string("Alice"))
  #expect(json.value(forKey: "missing", default: JSON("x")) == JSON.string("x"))

  // Array value with default
  let arr = JSON.array([.string("a"), .number(.integer(1))])
  #expect(arr.value(at: 0, default: JSON.null) == JSON.string("a"))
  #expect(arr.value(at: 99, default: JSON("x")) == JSON.string("x"))
}

// MARK: - Capacity / Lookup

@Test func readmeCapacityLookup() throws {
  let json = try JSON.parse(
    """
    {"a": 1, "b": 2, "c": 3}
    """)

  #expect(json.count == 3)
  #expect(json.isEmpty == false)

  #expect(json.first == JSON.number(.integer(1)))
  #expect(json.last == JSON.number(.integer(3)))

  #expect(json.contains(key: "b"))
  #expect(json.find(key: "b") == JSON.number(.integer(2)))
  #expect(json.find(key: "missing") == nil)

  let arr = JSON.array([
    .string("a"),
    .number(.integer(1)),
    .boolean(true),
  ])
  #expect(arr.contains(element: .string("a")))
  #expect(!arr.contains(element: .string("z")))
}

// MARK: - Modifiers

@Test func readmeModifiers() throws {
  var json = try JSON.parse(
    """
    {"a": 1, "b": 2}
    """)

  json.clear()
  #expect(json.count == 0)

  json["a"] = JSON(10)
  #expect(json["a"] == JSON(10))

  json.remove(key: "a")
  #expect(json.count == 0)

  var arr = JSON.array([JSON(1), JSON(2), JSON(3)])
  arr.append(JSON(4))
  #expect(arr.count == 4)
  #expect(arr.last == JSON(4))

  arr.insert(JSON(0), at: 0)
  #expect(arr.count == 5)
  #expect(arr.first == JSON(0))

  arr.append(JSON(5))
  #expect(arr.last == JSON(5))

  var obj = JSON.object(["x": JSON(1)])
  obj.setDefault(key: "y", JSON(2))
  #expect(obj.count == 2)
  obj.setDefault(key: "x", JSON(99))
  #expect(obj["x"] == JSON(1))

  obj.update(with: JSON.object(["y": JSON(3), "z": JSON(4)]))
  #expect(obj.count == 3)
  #expect(obj["y"] == JSON(3))

  var config = JSON.object([
    "app": JSON.object(["theme": JSON.string("dark"), "lang": JSON.string("en")])
  ])
  let patch = JSON.object([
    "app": JSON.object(["lang": JSON.string("fr")])
  ])
  config.update(with: patch, mergingNested: true)
  #expect(config["app"]?["theme"] == JSON.string("dark"))
  #expect(config["app"]?["lang"] == JSON.string("fr"))

  var a = JSON(1)
  var b = JSON(2)
  a.swap(with: &b)
  #expect(a == JSON(2))
  #expect(b == JSON(1))
}

// MARK: - Flatten / Unflatten

@Test func readmeFlatten() throws {
  let json = try JSON.parse(
    """
    {"a": "x", "b": {"c": "deep"}, "d": [1, {"e": "nested"}]}
    """)

  let flat = json.flatten()
  #expect(flat["/a"] == JSON.string("x"))
  #expect(flat["/b/c"] == JSON.string("deep"))
  #expect(flat["/d/0"] == JSON.number(.integer(1)))
  #expect(flat["/d/1/e"] == JSON.string("nested"))

  let restored = try flat.unflatten()
  #expect(restored == json)
}

// MARK: - JSON Pointer

@Test func readmeJSONPointer() throws {
  let json = try JSON.parse(
    """
    {"a": {"b": {"c": 42}}}
    """)

  let ptr = try JSONPointer("/a/b/c")
  #expect(ptr.resolve(json) == JSON.number(.integer(42)))
}

@Test func readmeJSONPointerError() throws {
  // Invalid syntax
  #expect(throws: JSONPointerError.self) { try JSONPointer("foo") }

  // Leading zero
  #expect(throws: JSONPointerError.self) { try JSONPointer("/01") }
  _ = try JSONPointer("/0")  // OK
}

@Test func readmeJSONPointerInit() throws {
  // Standard pointer
  let ptr1 = try JSONPointer("/foo/bar")
  #expect(ptr1.segments == ["foo", "bar"])

  // Root pointer
  let root = try JSONPointer("")
  #expect(root.segments.isEmpty)

  // URI fragment
  let ptr2 = try JSONPointer(fragment: "#/c%25d")
  #expect(ptr2.segments == ["c%d"])

  // Valid single digit
  let ptr4 = try JSONPointer("/0")
  #expect(ptr4.segments == ["0"])

  // Invalid fragment
  #expect(throws: JSONPointerError.self) { try JSONPointer(fragment: "/foo") }
}

@Test func readmeJSONPointerResolution() throws {
  let json = try JSON.parse(
    """
    {"a": {"b": [1, 2, 3]}}
    """)

  let ptr = try JSONPointer("/a/b/2")
  #expect(ptr.resolve(json) == JSON.number(.integer(3)))

  // Missing key returns nil
  let missing = try JSONPointer("/x")
  #expect(missing.resolve(json) == nil)

  // "-" token returns nil
  let dash = try JSONPointer("/-/")
  #expect(dash.resolve(json) == nil)

  // Throwing resolution
  let value = try ptr.resolveOrThrow(json)
  #expect(value == JSON.number(.integer(3)))
}

@Test func readmeJSONPointerSet() throws {
  var json = JSON.object(["a": JSON.number(.integer(1))])

  let ptr = try JSONPointer("/b/c")
  ptr.set(value: JSON.string("deep"), into: &json)
  #expect(json["b"]?["c"] == JSON.string("deep"))

  // Root pointer replaces entire value
  let root = try JSONPointer("")
  root.set(value: JSON.number(.integer(42)), into: &json)
  #expect(json == JSON.number(.integer(42)))

  // "-" token appends to array
  var arr = JSON.array([JSON.string("a")])
  let append = try JSONPointer("/-")
  append.set(value: JSON.string("b"), into: &arr)
  #expect(arr.count == 2)
  #expect(arr.last == JSON.string("b"))

  // "-" on non-array creates one
  var obj = JSON.object([:])
  let force = try JSONPointer("/-")
  force.set(value: JSON.string("first"), into: &obj)
  #expect(obj.isArray)
  #expect(obj.first == JSON.string("first"))
}

@Test func readmeJSONPointerDescription() throws {
  let ptr = try JSONPointer("/a~1b/m~0n")
  #expect(ptr.description == "/a~1b/m~0n")

  let root = try JSONPointer("")
  #expect(root.description == "")

  let roundtrip = try JSONPointer(ptr.description)
  #expect(roundtrip.segments == ptr.segments)
}

// MARK: - Comparison Operators

@Test func readmeComparisonOperators() {
  #expect(JSON(1) < JSON(2))
  #expect((JSON(1) > JSON(2)) == false)
  #expect(JSON(1) <= JSON(2))
  #expect((JSON(1) >= JSON(2)) == false)
}

@Test func readmeTypeOrdering() {
  // Note: Cross-type < returns false per current implementation.
  // Only same-type comparisons are supported.
  #expect(JSON.null < JSON.boolean(true))
  #expect(JSON.boolean(false) < JSON.boolean(true))
  #expect(JSON.number(.integer(1)) < JSON.number(.integer(2)))
  #expect(JSON.string("a") < JSON.string("b"))
  let obj1 = JSON.object(["x": JSON(1)])
  let obj2 = JSON.object(["x": JSON(1), "y": JSON(2)])
  #expect(obj1 < obj2)
  let arr1 = JSON.array([JSON(1)])
  let arr2 = JSON.array([JSON(1), JSON(2)])
  #expect(arr1 < arr2)
}

@Test func readmeMixedNumberComparison() {
  // Note: < supports mixed number comparison, but == does NOT.
  // Integer and float are distinct enum cases in JSONNumber.
  #expect(JSON.number(.integer(1)) < JSON.number(.float(2.5)))
  #expect(JSON.number(.integer(42)) != JSON.number(.float(42.0)))
  #expect(JSON.number(.float(42.0)) != JSON.number(.integer(42)))
}

// MARK: - Sequence Conformance

@Test func readmeSequenceConformance() {
  let arr = JSON.array([JSON(1), JSON(2), JSON(3)])
  var collected: [JSON] = []
  for element in arr {
    collected.append(element)
  }
  #expect(collected == [JSON(1), JSON(2), JSON(3)])

  let obj = JSON.object(["x": JSON(10), "y": JSON(20)])
  var values: [JSON] = []
  for value in obj {
    values.append(value)
  }
  #expect(values == [JSON(10), JSON(20)])

  // Key-value pairs via keyValuePairs()
  let pairs = obj.keyValuePairs()
  #expect(pairs.count == 2)
  #expect(pairs[0].key == "x")
  #expect(pairs[0].value == JSON(10))
}

// MARK: - JSON Patch (RFC 6902)

@Test func readmeJSONPatch() throws {
  let source = try JSON.parse(
    """
    {"a": 1, "b": 2}
    """)

  let patch = try JSON.parse(
    """
    [{"op": "add",     "path": "/c", "value": 3},
     {"op": "remove",  "path": "/b"},
     {"op": "replace", "path": "/a", "value": 99}]
    """)

  // Non-mutating — applying()
  let patched = try source.applying(patch)
  #expect(patched["a"] == JSON(99))
  #expect(patched["c"] == JSON(3))
  #expect(patched["b"] == nil)

  // Mutating — patch()
  var mutable = source
  try mutable.patch(patch)
  #expect(mutable["a"] == JSON(99))
  #expect(mutable["c"] == JSON(3))
  #expect(mutable["b"] == nil)
}

// MARK: - Diff

@Test func readmeDiff() throws {
  let source = try JSON.parse(
    """
    {"a": 1, "b": 2}
    """)
  let target = try JSON.parse(
    """
    {"a": 1, "c": 3}
    """)

  let diff = JSON.diff(source, target)
  #expect(diff.isArray)
}

// MARK: - JSON Merge Patch (RFC 7396)

@Test func readmeMergePatch() throws {
  let source = try JSON.parse(
    """
    {"a": 1, "b": {"c": 2, "d": 3}}
    """)

  let patch = try JSON.parse(
    """
    {"a": null, "b": {"c": 99}}
    """)

  let merged = source.mergePatch(patch)
  #expect(merged["b"]?["c"] == JSON(99))
}

// MARK: - SAX Parsing

@Test func readmeSAX() {
  class MyHandler: JSONSAXEventHandler {
    var events: [String] = []
    func null() -> Bool {
      events.append("null")
      return true
    }
    func boolean(_ v: Bool) -> Bool {
      events.append("bool:\(v)")
      return true
    }
    func integer(_ v: Int64) -> Bool {
      events.append("int:\(v)")
      return true
    }
    func float(_ v: Double, string: String) -> Bool {
      events.append("float:\(v)")
      return true
    }
    func string(_ v: String) -> Bool {
      events.append("string:\(v)")
      return true
    }
    func startObject() -> Bool {
      events.append("{")
      return true
    }
    func key(_ v: String) -> Bool {
      events.append("key:\(v)")
      return true
    }
    func endObject() -> Bool {
      events.append("}")
      return true
    }
    func startArray() -> Bool {
      events.append("[")
      return true
    }
    func endArray() -> Bool {
      events.append("]")
      return true
    }
    func parseError(_ e: JSONParseError, data: Data) -> Bool {
      events.append("error")
      return false
    }
  }

  let handler = MyHandler()
  let ok = JSON.parse("{\"a\": 1}", handler: handler)
  #expect(ok)
  #expect(handler.events.contains("key:a"))
  #expect(handler.events.contains("int:1"))

  // accept() validation
  #expect(JSON.accept("{\"valid\": 1}"))
  #expect(JSON.accept("invalid") == false)
}

// MARK: - Binary Formats

@Test func readmeBinaryFormats() throws {
  let json = JSON.object([
    "name": JSON.string("Bob"),
    "age": JSON.number(.integer(25)),
  ])

  // CBOR
  let cbor = json.cbor()
  let back = try JSON(cbor: cbor)
  #expect(back == json)

  // MessagePack
  let msg = json.msgPack()
  let back2 = try JSON(msgPack: msg)
  #expect(back2 == json)

  // UBJSON
  let ubj = json.ubjson()
  let back3 = try JSON(ubjson: ubj)
  #expect(back3 == json)

  // BSON
  let bson = json.bson()
  let back4 = try JSON(bson: bson)
  #expect(back4 == json)

  // BJData
  let bjd = json.bjdata()
  let back5 = try JSON(bjdata: bjd)
  #expect(back5 == json)
}

// MARK: - JSON Schema

@Test func readmeSchemaCreating() throws {
  let schemaJSON = try JSON.parse(
    """
    {
      "$schema": "https://json-schema.org/draft/2020-12/schema",
      "type": "object",
      "properties": {
        "name": {"type": "string"},
        "age": {"type": "integer", "minimum": 0}
      },
      "required": ["name"]
    }
    """)

  let schema = try JSONSchema(schema: schemaJSON)
  #expect(schema.isValid(JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])))

  // Explicit draft
  let schema2 = try JSONSchema(schema: schemaJSON, draft: .draft7)
  #expect(schema2.isValid(JSON.object(["name": .string("Bob"), "age": .number(.integer(25))])))
}

@Test func readmeSchemaValidation() throws {
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
  let document = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])

  // validate() throws on first error, returns true on success
  let valid = try schema.validate(document)
  #expect(valid)

  // validating() returns VerboseResult (never throws)
  let result = schema.validating(document)
  #expect(result.valid)

  // isValid() boolean check
  #expect(schema.isValid(document))

  // Access errors
  for error in result.errors {
    #expect(error.keyword != "")
  }

  // throwOnError doesn't throw for valid
  try result.throwOnError()
}

@Test func readmeSchemaDrafts() throws {
  #expect(JSONSchema.Draft.draft7 == .draft7)
  #expect(JSONSchema.Draft.draft202012 == .draft202012)
  #expect(JSONSchema.Draft.auto == .auto)
}

@Test func readmeSchemaFormatOptions() throws {
  var formatOptions = JSONSchemaFormatOptions()
  formatOptions.disable(.email)
  #expect(formatOptions.isEnabled(.email) == false)
  formatOptions.enable(.email)
  #expect(formatOptions.isEnabled(.email))
  #expect(formatOptions.isEnabled(.dateTime))
}

@Test func readmeSchemaOutputModes() throws {
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

  let schema = try JSONSchema(schema: schemaJSON, outputMode: .verbose)
  let result = schema.validating(JSON.object(["age": .number(.integer(-1))]))
  #expect(!result.valid)
}

@Test func readmeSchemaInference() throws {
  let instance = try JSON.parse(
    """
    {"name": "Alice", "age": 30, "tags": ["admin", "user"]}
    """)

  let generatedSchema = JSONSchemaGeneration.generate(from: instance)
  #expect(generatedSchema.isObject)

  let schema = try instance.schema()
  #expect(schema.isValid(instance))

  let schema2 = try instance.schema(
    draft: .draft202012,
    formatOptions: JSONSchemaFormatOptions(),
    outputMode: .verbose
  )
  #expect(schema2.isValid(instance))
}

// MARK: - Swift Idioms

@Test func readmeDynamicMemberLookup() throws {
  let json = try JSON.parse(#"{"user": {"name": "Alice", "age": 30}}"#)

  #expect(json.user.name == JSON.string("Alice"))
  #expect(json.user.age == JSON.number(.integer(30)))

  #expect(json.missingKey == JSON.null)

  var mutable = json
  mutable.user.name = JSON.string("Bob")
  #expect(mutable.user.name == JSON.string("Bob"))
}

// MARK: - Sendable & StrictConcurrency

@Test func readmeSendable() throws {
  let json = try JSON.parse("{\"key\": \"value\"}")
  // Verify it's Sendable by passing across a Task
  Task {
    let value = json["key"]
    #expect(value == JSON.string("value"))
  }
}

// MARK: - Codable Support

@Test func readmeJSONCodable() throws {
  let json = JSON.object([
    "name": .string("Alice"),
    "age": .number(.integer(30)),
  ])

  let data = try JSONEncoder().encode(json)
  let decoded = try JSONDecoder().decode(JSON.self, from: data)
  #expect(decoded["name"] == .string("Alice"))
}

@Test func readmeOrderedJSONEncoder() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }

  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(Person(name: "Alice", age: 30))
  #expect(json["name"] == .string("Alice"))
  #expect(json["age"] == .number(.integer(30)))

  let string = try encoder.encodeAsString(Person(name: "Bob", age: 25))
  #expect(string == "{\"name\":\"Bob\",\"age\":25}")
}

@Test func readmeOrderedJSONDecoder() throws {
  struct Person: Decodable {
    let name: String
    let age: Int
  }

  let decoder = OrderedJSONDecoder()

  // Decode from JSON value
  let json = try JSON.parse(#"{"name": "Alice", "age": 30}"#)
  let person1 = try decoder.decode(Person.self, from: json)
  #expect(person1.name == "Alice")

  // Decode from raw data
  let data = Data(#"{"name": "Bob", "age": 25}"#.utf8)
  let person2 = try decoder.decode(Person.self, from: data)
  #expect(person2.name == "Bob")

  // Decode from JSON string
  let person3 = try decoder.decode(Person.self, from: "{\"name\": \"Charlie\", \"age\": 35}")
  #expect(person3.name == "Charlie")

  // Decode JSON itself
  let ordered = try decoder.decode(JSON.self, from: #"{"z": 1, "a": 2, "m": 3}"#)
  #expect(ordered["z"] == .number(.integer(1)))
}

// MARK: - Foundation Type Support

@Test func readmeDateStrategies() throws {
  struct Event: Codable {
    let timestamp: Date
  }

  let event = Event(timestamp: Date(timeIntervalSince1970: 1_234_567_890))

  // Seconds since 1970
  var encoder = OrderedJSONEncoder()
  encoder.dateEncodingStrategy = .secondsSince1970
  let json = try encoder.encode(event)
  #expect(json["timestamp"]?.isNumber == true)

  var decoder = OrderedJSONDecoder()
  decoder.dateDecodingStrategy = .secondsSince1970
  let back = try decoder.decode(Event.self, from: json)
  #expect(Int64(back.timestamp.timeIntervalSince1970) == 1_234_567_890)

  // ISO 8601
  encoder.dateEncodingStrategy = .iso8601
  decoder.dateDecodingStrategy = .iso8601

  // Custom date formatter
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd"
  encoder.dateEncodingStrategy = .formatted(formatter)
  decoder.dateDecodingStrategy = .formatted(formatter)

  // Milliseconds since 1970
  encoder.dateEncodingStrategy = .millisecondsSince1970
  decoder.dateDecodingStrategy = .millisecondsSince1970

  // Custom closure
  encoder.dateEncodingStrategy = .custom { date, encoder in
    return .object(["epoch": .number(.integer(Int64(date.timeIntervalSince1970)))])
  }
  decoder.dateDecodingStrategy = .custom { json, decoder in
    return Date(timeIntervalSince1970: try json["epoch"]?.requireDouble() ?? 0)
  }
}

@Test func readmeDataStrategies() throws {
  struct Container: Codable {
    let data: Data
  }

  let raw = Data([0xDE, 0xAD, 0xBE, 0xEF])

  var encoder = OrderedJSONEncoder()
  encoder.dataEncodingStrategy = .base64
  let json = try encoder.encode(Container(data: raw))

  var decoder = OrderedJSONDecoder()
  decoder.dataDecodingStrategy = .base64
  let back = try decoder.decode(Container.self, from: json)
  #expect(back.data == raw)
}

@Test func readmeURLUUIDDecimal() throws {
  struct Document: Codable {
    let url: URL
    let id: UUID
    let price: Decimal
  }

  let doc = Document(
    url: URL(string: "https://example.com")!,
    id: UUID(),
    price: Decimal(string: "19.99")!
  )

  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(doc)

  let decoder = OrderedJSONDecoder()
  let back = try decoder.decode(Document.self, from: json)
  #expect(back.url == doc.url)
  #expect(back.id == doc.id)
  #expect(back.price == doc.price)
}

// MARK: - Convenience JSON.encode / decode

@Test func readmeJSONEncodeConvenience() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }

  let json = try JSON.encode(Person(name: "Alice", age: 30))
  #expect(json["name"] == .string("Alice"))
  #expect(json["age"] == .number(.integer(30)))

  let arr = try JSON.encode([1, 2, 3])
  #expect(arr.isArray)

  let str = try JSON.encode("hello")
  #expect(str.isString)
}

@Test func readmeJSONDecodeConvenience() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }

  // From existing JSON value
  let json = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])
  let p1 = try JSON.decode(Person.self, from: json)
  #expect(p1.name == "Alice")

  // From JSON string
  let p2 = try JSON.decode(Person.self, from: "{\"name\": \"Bob\", \"age\": 25}")
  #expect(p2.name == "Bob")

  // From raw data
  let data = Data(#"{"name": "Charlie", "age": 35}"#.utf8)
  let p3 = try JSON.decode(Person.self, from: data)
  #expect(p3.name == "Charlie")

  // With parser options
  let opts = JSON.ParserOptions(allowTrailingCommas: true)
  let p4 = try JSON.decode(Person.self, from: "{\"name\": \"Dave\", \"age\": 45,}", options: opts)
  #expect(p4.name == "Dave")
}

// MARK: - JSONWithUnknownKeys

@Test func readmeJSONWithUnknownKeys() throws {
  struct Person: Codable {
    let name: String
    let age: Int
  }

  let data = Data(
    #"""
    {"name": "Alice", "age": 30, "color": "blue", "city": "NYC"}
    """#.utf8)

  let wrapped = try OrderedJSONDecoder().decode(
    JSONWithUnknownKeys<Person>.self, from: data)

  #expect(wrapped.value.name == "Alice")
  #expect(wrapped.value.age == 30)
  #expect(wrapped.unknownKeys["color"] == .string("blue"))
  #expect(wrapped.unknownKeys["city"] == .string("NYC"))
}

// MARK: - Throwing Typed Accessors

@Test func readmeThrowingAccessors() throws {
  let json = try JSON.parse(#"{"name": "Alice", "count": 42, "rate": 3.14, "active": true}"#)

  let name = try json["name"]?.requireString()
  #expect(name == "Alice")

  let active = try json["active"]?.requireBool()
  #expect(active == true)

  let count = try json["count"]?.requireInt64()
  #expect(count == 42)

  let rate = try json["rate"]?.requireDouble()
  #expect(rate == 3.14)

  let count32 = try json["count"]?.requireInt32()
  #expect(count32 == 42)
}

// MARK: - Optional Value Accessors

@Test func readmeOptionalValueAccessors() throws {
  let json = try JSON.parse(#"{"name": "Alice", "count": 42, "pi": 3.14, "ok": true}"#)

  #expect(json["name"]?.stringValue == "Alice")
  #expect(json["count"]?.intValue == 42)
  #expect(json["pi"]?.doubleValue == 3.14)
  #expect(json["ok"]?.boolValue == true)
  #expect(json["count"]?.numberValue == .integer(42))

  // Integer widened to double
  #expect(json["count"]?.doubleValue == 42.0)
}

// MARK: - Round-Trip Example

@Test func readmeRoundTrip() throws {
  struct Person: Codable {
    let name: String
    let age: Int
    let address: String?
  }

  let original = Person(name: "Alice", age: 30, address: nil)

  let encoder = OrderedJSONEncoder()
  let json = try encoder.encode(original)

  let jsonString = json.dump()
  #expect(jsonString == "{\"name\":\"Alice\",\"age\":30}")

  let parsed = try JSON.parse(jsonString)

  let decoder = OrderedJSONDecoder()
  let roundTripped = try decoder.decode(Person.self, from: parsed)
  #expect(roundTripped.name == original.name)
  #expect(roundTripped.age == original.age)
  #expect(roundTripped.address == original.address)
}
