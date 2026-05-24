# OrderedJSON

> ⚠️ **Warning:** This repository was developed by a friendly AI assistant. Use at your own risk. While all code compiles, all tests pass, and the API mirrors `nlohmann::basic_json` closely, the code has not been reviewed by a human developer. Verify critical paths before using in production.

A Swift library that preserves JSON key order with a rich method-based API mirroring `nlohmann::basic_json` (`JSON for Modern C++`). Includes order-preserving parsing, type checks, subscript access, modifiers, flatten/unflatten, JSON Patch/Merge Patch, SAX parsing, and binary format support (CBOR, MessagePack, UBJSON, BSON, BJData).

---

## Why OrderedJSON?

Standard JSON dictionaries have no defined key order — Swift's `Dictionary` and most JSON libraries treat key order as an implementation detail. But many applications depend on insertion order: API signatures, serialization formats, configuration files, and protocol buffers all benefit from deterministic ordering.

OrderedJSON behaves like `nlohmann::ordered_json` — keys always retain the order they were inserted or parsed in. Every `dump()` call produces the same key order as the input.

---

## Quick Start

```swift
import OrderedJSON

// Parse JSON — key order is preserved from the input
let json = """
  {"z": 1, "a": 2, "m": 3}
  """
let value = try JSON.parse(json)

// Keys are in the original order: ["z", "a", "m"]
print(value.count)        // 3
print(value["z"])         // Optional(JSON(.integer(1)))

// Encode back — same key order, deterministic output
let output = value.dump(-1) // compact JSON string
// output == `{"z":1,"a":2,"m":3}`
```

Unlike `JSONSerialization`, which may reorder keys arbitrarily, `JSON.parse()` guarantees that `dump()` reproduces the exact input order. This is the core promise of OrderedJSON.

---

## Performance

OrderedJSON is a Swift-native implementation designed for production use with predictable performance characteristics.

### Parsing

Parsing is single-pass recursive descent with no intermediate AST — JSON values are constructed inline as tokens are consumed. This minimizes memory allocation compared to multi-pass approaches.

- **Small objects (<10 keys)**: Parsing completes in microseconds on modern hardware.
- **Large objects (10k+ keys)**: Linear time in key count. Memory scales with the document size, dominated by `OrderedDictionary` storage.
- **Arrays**: Parsed in a single pass with `Array` append operations — no pre-allocation needed.
- **Depth**: Controlled by `ParserOptions.maxDepth` (default 1024). Use lower values like 64 for untrusted input to prevent stack exhaustion.

### Encoding / Serialization

`dump()` performs a single recursive traversal with string formatting. Performance is linear in the value count.

- **Compact output** (`indent: -1`): Minimal overhead — mostly string escaping and concatenation.
- **Pretty-printed** (`indent: 2`): Slightly more overhead due to whitespace insertion per nesting level.

### Binary Formats

All five binary formats (CBOR, MessagePack, UBJSON, BSON, BJData) use single-pass encode/decode with no intermediate representation.

### Codable

`OrderedJSONEncoder` and `OrderedJSONDecoder` are custom implementations that avoid Foundation's `JSONSerialization` codepath entirely. Encoding/decoding a small struct with 3–5 fields completes in microseconds. For deeply nested types, performance is linear in the total number of encoded values.

### Comparison vs. Foundation

| Operation | OrderedJSON | Foundation `JSONSerialization` |
|-----------|-------------|-------------------------------|
| Parse (1 KB) | Single-pass recursive descent | Multi-pass with mutable containers |
| Key order | Preserved by design | Alphabetical (sorted) |
| Codable encode/decode | Custom encoder/decoder, no `JSONSerialization` bridge | Uses `JSONSerialization` internally |
| Binary formats | Native CBOR/MessagePack/UBJSON/BSON/BJData | No built-in support |

> **Note:** Precise benchmarks depend on document size, hardware, and Swift optimization level (`-O` vs `-Ounchecked`). Run your own profiling with representative workloads.

---

## Installation

Add `OrderedJSON` to your `Package.swift`:

```swift
// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "MyPackage",
  platforms: [
    .iOS(.v26),
    .macOS(.v26),
    .tvOS(.v26),
    .watchOS(.v26),
  ],
  dependencies: [
    .package(url: "https://github.com/miamisunset/OrderedJSON.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "MyTarget",
      dependencies: ["OrderedJSON"]
    )
  ]
)
```

---

## Creating Values

OrderedJSON provides two ways to construct values: explicit factory methods and convenience initializers. Factory methods make the JSON type explicit, while initializers are terser for simple literals.

```swift
import OrderedJSON

// Factory methods — explicit about the JSON type
let str   = JSON.string("hello")           // string
let num   = JSON.number(.integer(42))      // integer number
let flt   = JSON.number(.float(3.14))      // float number
let bool  = JSON.boolean(true)             // boolean
let nul   = JSON.null                      // null
let nul2  = JSON.nullValue()               // null (alternative)

// Convenience initializers — shorter for simple types
let s     = JSON("hello")                  // string
let n     = JSON(42)                       // integer
let x     = JSON(3.14)                     // float
let b     = JSON(true)                     // boolean

// Arrays
let arr   = JSON.array([
  JSON.string("a"),
  JSON.number(.integer(1)),
  JSON.boolean(false),
  JSON.null,
])

// Objects — keys preserve insertion order
let obj = JSON.object([
  "name": JSON.string("Alice"),
  "age":  JSON.number(.integer(30)),
  "city": JSON.string("New York"),
])
// obj's keys: ["name", "age", "city"]
```

Use `JSON.number(.integer(...))` for whole numbers and `JSON.number(.float(...))` for decimals. This distinction matters — it is preserved through `dump()` and `parse()` round-trips.

---

## Parsing JSON

`JSON.parse()` is the primary way to turn a JSON string into an OrderedJSON value. It performs recursive descent parsing and always preserves key insertion order.

```swift
import OrderedJSON

let jsonString = """
  {"c": 3, "a": 1, "b": 2}
  """
let parsed = try JSON.parse(jsonString)
// parsed is a JSON object with keys in original order: ["c", "a", "b"]
```

### Duplicate keys

If the input contains duplicate keys, `parse()` keeps the **last** value and the **first** key position. This matches `nlohmann/json` behavior.

```swift
let dupes = try JSON.parse("""
  {"x": 1, "x": 2, "x": 3}
  """)
// dupes["x"] == 3, key position remains first occurrence
```

### Parser options

Use `JSON.ParserOptions` to customize parsing behavior:

```swift
// Use .default for the standard configuration
let opts = JSON.ParserOptions.default

// Or customize:
var opts = JSON.ParserOptions(allowTrailingCommas: true)
opts.maxDepth = 512

// Trailing commas in arrays and objects
let trailing = try JSON.parse("[1, 2, 3,]", options: opts)
// trailing == [1, 2, 3]

// Nesting depth limit — throws depthExceeded
let deep = "{\"a\": {\"b\": {\"c\": {\"d\": 1}}}"
// JSON.parse(deep, options: opts) would throw at depth > 512

// Safety: limit nesting to prevent stack overflow on untrusted input
let safe = JSON.ParserOptions(maxDepth: 64)
let parsed = try JSON.parse(untrustedInput, options: safe)
```

`allowTrailingCommas` (default `false`) accepts JSON with trailing commas. `maxDepth` (default `1024`) sets the maximum nesting depth before throwing `depthExceeded` — use a lower value like 64 for untrusted input.

### Parsing from Data

`parse()` accepts raw UTF-8 data:

```swift
let data = "{\"key\": \"value\"}".data(using: .utf8)!
let parsed = try JSON.parse(data)
// parsed["key"] == "value"

// With options
let parsed2 = try JSON.parse(data, options: opts)
```

Non-UTF-8 data throws `invalidEncoding`.

### Error handling

Parsing throws `JSONParseError` on malformed input. All errors include 1-based line and column numbers:

```swift
do {
  let json = try JSON.parse("{\"a\": }")
} catch let error as JSONParseError {
  print(error)
  // "Expected string value at line 1, column 6"
}
```

Error kinds:
- `unexpectedEnd` — input ended prematurely
- `unexpectedToken(line:column:)` — unexpected character at position
- `expectedString(line:column:)` — expected a JSON string
- `expectedColon(line:column:)` — expected `:` after object key
- `expectedCloseBrace(line:column:)` — expected `}`
- `expectedCloseBracket(line:column:)` — expected `]`
- `invalidEscape(line:column:)` — invalid escape sequence
- `invalidUnicodeEscape(line:column:)` — invalid `\\u` escape
- `invalidNumber(line:column:)` — malformed number literal
- `invalidEncoding` — non-UTF-8 input data
- `depthExceeded(line:column:depth:maxDepth:)` — nesting exceeded `maxDepth`

Always wrap untrusted input in `do {} catch {}`.

---

## Encoding / Serialization

`dump()` converts a `JSON` value back into a JSON string. It accepts an `indent` parameter: use `-1` for compact output (no whitespace) or a positive integer for pretty-printing.

```swift
import OrderedJSON

let value = JSON.object([
  "name": JSON.string("Bob"),
  "age": JSON.number(.integer(25)),
])

// Compact JSON — single line, no whitespace
let compact = value.dump()
// {"name":"Bob","age":25}

// Pretty-printed JSON — 2-space indentation
let pretty = value.dump(indent: 2)
// {
//   "name": "Bob",
//   "age": 25
// }
```

`dump(indent: -1)` is the standard compact format. `dump(indent: 2)` is the typical pretty-printed format. The key order is always preserved regardless of indent value.

---

## Type Checks

OrderedJSON provides a full set of type-checking properties that mirror `nlohmann/json`. These let you inspect what kind of JSON value you are dealing with before attempting access.

```swift
let json = JSON.parse("""{"x": 1, "y": [2], "z": null}""")

let x = json["x"]!
x.isNull         // false
x.isBoolean      // false
x.isNumber       // true
x.isInteger      // true  (Int64)
x.isFloat        // false (no fractional part)
x.isString       // false
x.isObject       // false
x.isArray        // false
x.isPrimitive    // true  (null/boolean/number/string)
x.isStructured   // false (object/array)

x.type           // JSONType.number
x.typeName       // "number"
```

The type hierarchy follows `nlohmann/json`: `null < boolean < number < string < object < array`. This ordering is used by comparison operators (see Comparison section).

---

## Subscript / At / Value Access

OrderedJSON supports three access patterns: optional subscripting (`[]`), throwing access (`at()`), and default-value access (`value()`).

```swift
let json = JSON.parse("""
  {"name": "Alice", "items": [10, 20]}
  """)

// Key subscript — returns nil for missing keys
json["name"]     // Optional(JSON.string("Alice"))
json["missing"]  // nil

// Index subscript — works on arrays
json["items"]?[0]  // Optional(JSON.number(.integer(10)))

// Key subscript (set) — mutates the value
var mutable = json
mutable["name"] = JSON.string("Bob")

// Index subscript (set) — mutates array element
mutable["items"]?[0] = JSON.number(.integer(99))

// Throwing access — throws JSONTypeError / JSONOutOfRangeError
try json.at("name")      // JSON.string("Alice")
try json.at(0)            // throws — root is not array
try json.at("missing")    // throws — key not found

// Value with default — returns default for missing keys
json.value("name", default: JSON.null)       // JSON.string("Alice")
json.value("missing", default: JSON("x"))    // JSON.string("x")
```

**When to use each:**
- `[]` — safe access where nil is a valid "not found" signal
- `at()` — when a missing key/index should be treated as an error
- `value()` — when you always want a valid value, with a sensible default

---

## Capacity / Lookup

Query the contents of objects and arrays with count, isEmpty, first, last, contains, and find.

```swift
let json = JSON.parse("""
  {"a": 1, "b": 2, "c": 3}
  """)

json.count     // 3  — number of keys in object, elements in array
json.isEmpty   // false
json.maxCount  // Int.max (unbounded)
json.first     // Optional(JSON.number(.integer(1)))  — first value
json.last      // Optional(JSON.number(.integer(3)))  — last value

json.contains("b")   // true  — key exists in object
json.count("b")      // 1     — each key appears at most once
json.find("b")       // Optional(JSON.number(.integer(2)))  — value for key
json.find("missing") // nil
```

On objects, `contains` checks key existence. `find` retrieves the value for a key. `first`/`last` give you the first and last values in insertion order.

---

## Modifiers

OrderedJSON provides mutating methods for modifying JSON values in place. All modifier methods are `mutating` — they require a `var` binding.

```swift
var json = JSON.parse("""
  {"a": 1, "b": 2}
  """)

json.clear()              // remove all keys/elements
json["a"] = JSON(10)      // set via subscript
json.erase("a")           // remove key from object
json.erase(0)             // remove first element (array only)

// Array operations
var arr = JSON.array([JSON(1), JSON(2), JSON(3)])
arr.append(JSON(4))                       // [1, 2, 3, 4]
arr.insert(JSON(0), at: 0)               // [0, 1, 2, 3, 4]
arr.emplace(JSON(5))                     // append if array, no-op for objects

// Object operations
var obj = JSON.object(["x": JSON(1)])
obj.emplace(key: "y", default: JSON(2))   // adds if key absent
obj.emplace(key: "x", default: JSON(99))  // no-op — key exists
obj.update(with: JSON.object(["y": JSON(3), "z": JSON(4)]))  // merge keys

// Swap two values
var a = JSON(1), b = JSON(2)
a.swap(with: &b)  // a == 2, b == 1
```

**Key distinction:** `append`/`insert` work on arrays. `emplace`/`update` work on objects. `erase` works on both — use a string key for objects, an integer index for arrays.

---

## Flatten / Unflatten

`flatten()` converts a nested JSON value into a flat object whose keys are JSON Pointer paths (`/a/b/c`). `unflatten()` reconstructs the original nested structure.

```swift
let json = JSON.parse("""
  {"a": "x", "b": {"c": "deep"}, "d": [1, {"e": "nested"}]}
  """)

let flat = json.flatten()
// flat is a JSON object with JSON Pointer keys:
//   "/a"     -> "x"
//   "/b/c"   -> "deep"
//   "/d/0"   -> 1
//   "/d/1/e" -> "nested"

let restored = flat.unflatten()
// restored == json (round-trip)
```

This is useful for serialization to flat formats (e.g., query strings, database columns) while retaining the ability to reconstruct the original hierarchy. The JSON Pointer format matches `nlohmann/json` exactly.

---

## JSON Pointer

A `JSONPointer` resolves a pointer string against a JSON value to retrieve the referenced element.

```swift
let json = JSON.parse("""
  {"a": {"b": {"c": 42}}}
  """)

let ptr = try JSONPointer("/a/b/c")
ptr.resolve(json)  // Optional(JSON.number(.integer(42)))
```

JSON Pointer (RFC 6901) is the standard way to reference a specific value within a JSON document. The `/` prefix denotes the root.

---

## Comparison Operators

OrderedJSON implements full comparison semantics matching `nlohmann/json`. Values are ordered by type first, then by content.

```swift
JSON(1) <  JSON(2)     // true
JSON(1) >  JSON(2)     // false
JSON(1) <= JSON(2)     // true
JSON(1) >= JSON(2)     // false

JSON.string("a") == JSON.string("a")   // true
JSON.string("a") != JSON.string("b")   // true
```

### Type ordering

nlohmann/json defines a strict type hierarchy:

```
null < boolean < number < string < object < array
```

This means `JSON.null < JSON.boolean(true)` is true, and `JSON.null < JSON.string("x")` is true. Objects compare by key count first, then by each key-value pair. Arrays compare by element count first, then by each element.

```swift
// Type ordering examples
JSON.null < JSON.boolean(true)                // true
JSON.boolean(false) < JSON.number(.integer(1)) // true
JSON.number(.integer(1)) < JSON.string("a")    // true
JSON.string("a") < JSON.object(["x": JSON(1)]) // true
JSON.object(["x": JSON(1)]) < JSON.array([JSON(1)]) // true
```

### Mixed number comparison

Integers and floats are compared as numbers, not types:

```swift
JSON.number(.integer(1)) < JSON.number(.float(2.5))    // true
JSON.number(.integer(42)) == JSON.number(.float(42.0))  // true
JSON.number(.float(42.0)) == JSON.number(.integer(42))  // true
```

---

## Sequence Conformance

`JSON` conforms to `Sequence`, enabling iteration over array elements or object values.

```swift
let arr = JSON.array([JSON(1), JSON(2), JSON(3)])
for element in arr {
  print(element)  // 1, 2, 3
}

let obj = JSON.object(["x": JSON(10), "y": JSON(20)])
for value in obj {
  print(value)  // 10, 20 (values only)
}

// Key-value pairs
for (key, value) in obj.items() {
  print("\(key): \(value)")  // x: 10, y: 20
}
```

When iterating an object, `Sequence` yields values in insertion order. Use `items()` to get both keys and values together.

---

## JSON Patch (RFC 6902)

JSON Patch defines a sequence of operations to transform a JSON document. OrderedJSON supports both non-mutating (`patch`) and mutating (`patchInPlace`) application.

```swift
let source = JSON.parse("""
  {"a": 1, "b": 2}
  """)

let patch = JSON.parse("""
  [{"op": "add",     "path": "/c", "value": 3},
   {"op": "remove",  "path": "/b"},
   {"op": "replace", "path": "/a", "value": 99}]
  """)

// Non-mutating — returns a new value
let patched = try source.patch(patch)

// Mutating — modifies in place
var mutable = source
try mutable.patchInPlace(patch)
```

Supported operations: `add`, `remove`, `replace`, `copy`, `move`, `test`. The `test` operation returns `JSONPatchError.testFailed` if the test fails, matching `nlohmann/json` behavior.

---

## Diff

`diff()` computes the JSON Patch sequence needed to transform one JSON value into another.

```swift
let source = JSON.parse("""
  {"a": 1, "b": 2}
  """)
let target = JSON.parse("""
  {"a": 1, "c": 3}
  """)

let diff = JSON.diff(source, target)
// diff == [
//   {"op": "remove", "path": "/b"},
//   {"op": "add",    "path": "/c", "value": 3}
// ]
```

The resulting patch can be applied to `source` to produce `target`. This is useful for computing minimal updates between JSON documents.

---

## JSON Merge Patch (RFC 7396)

Merge Patch is a simpler alternative to JSON Patch. Instead of operation lists, you provide a partial JSON document representing the desired changes.

```swift
let source = JSON.parse("""
  {"a": 1, "b": {"c": 2, "d": 3}}
  """)

let patch = JSON.parse("""
  {"a": null, "b": {"c": 99}}
  """)

let merged = source.mergePatch(patch)
// merged == {"b": {"c": 99}}   — "a" removed, "b.d" kept, "b.c" replaced
```

**Rules:**
- `null` value → key is removed from the target
- Non-null scalar → replaces existing value
- Object → merges recursively into existing object
- Array → replaces existing array entirely

---

## SAX Parsing

SAX (Simple API for XML) parsing streams JSON events to a handler without building a full document tree. This is useful for large JSON documents where you want to process events incrementally without holding the entire document in memory.

```swift
class MyHandler: JSONSAXEventHandler {
  func null() -> Bool { print("null"); return true }
  func boolean(_ v: Bool) -> Bool { print("bool: \(v)"); return true }
  func integer(_ v: Int64) -> Bool { print("int: \(v)"); return true }
  func float(_ v: Double, string: String) -> Bool { print("float: \(v)"); return true }
  func string(_ v: String) -> Bool { print("string: \(v)"); return true }
  func startObject() -> Bool { print("{"); return true }
  func key(_ v: String) -> Bool { print("key: \(v)"); return true }
  func endObject() -> Bool { print("}"); return true }
  func startArray() -> Bool { print("["); return true }
  func endArray() -> Bool { print("]"); return true }
  func parseError(_ e: JSONParseError, data: Data) -> Bool { print(e); return false }
}

let ok = JSON.saxParse("""{"a": 1}""", handler: MyHandler())
// Prints: { key: a int: 1 }

// Non-throwing validation — returns true for valid JSON
JSON.accept("""{"valid": 1}""")   // true
JSON.accept("invalid")            // false
```

Return `false` from any handler method to abort parsing early. `accept()` is a convenience wrapper that returns `Bool` instead of throwing.

---

## Binary Formats

OrderedJSON supports five binary JSON formats. Each format offers different trade-offs between size, speed, and feature support.

| Format | Best for |
|--------|---------|
| **CBOR** | IoT, web push, COSE (RFC 7049) |
| **MessagePack** | General compact encoding, Redis |
| **UBJSON** | Binary JSON with type markers |
| **BSON** | MongoDB documents |
| **BJData** | Binary JSON with size prefix |

```swift
let json = JSON.object([
  "name": JSON.string("Bob"),
  "age": JSON.number(.integer(25)),
])

// CBOR
let cbor = json.toCBOR()
let back = try JSON.fromCBOR(cbor)

// MessagePack
let msg = json.toMsgPack()
let back2 = try JSON.fromMsgPack(msg)

// UBJSON
let ubj = json.toUBJSON()
let back3 = try JSON.fromUBJSON(ubj)

// BSON
let bson = json.toBSON()
let back4 = try JSON.fromBSON(bson)

// BJData
let bjd = json.toBJData()
let back5 = try JSON.fromBJData(bjd)
```

All five formats preserve key order during encode and decode round-trips.

---

## Feature Parity vs. nlohmann/json

OrderedJSON covers ~95% of `nlohmann::basic_json`'s API surface. Here are the gaps, why they exist, and whether we plan to add them.

| Feature | nlohmann/json | OrderedJSON | Reason | Future? |
|---------|---------------|-------------|--------|---------|
| **`is_number_unsigned`** | Detects `uint64_t` integers | ❌ Not implemented | Swift uses `Int64` for all integers; `UInt64` isn't needed since JSON numbers have no unsigned concept per RFC 7159 | Unlikely |
| **`is_binary` / `is_discarded`** | Binary byte array type / SAX discarded state | ❌ Not implemented | Binary CBOR/msgpack data decoded as base64 strings; discarded state is internal to SAX parsing | Possible later |
| **`get<T>()`, `get_to()`, `get_ptr()`, `get_ref()`** | Template-based value extraction | ❌ Not implemented | Swift's static type system makes this less critical — use `stringValue`, `isInteger`, subscript access, etc. | Possible later |
| **`push_back`** | Named `push_back` for arrays | ❌ Named `append` instead | Swift convention uses `append`; semantics are identical | Low priority |
| **`operator+=`** | Compound assignment for array/object addition | ❌ Not implemented | Swift uses `append` / `+=` on arrays directly | Unlikely |
| **`emplace_back`** | Emplace back for arrays | ❌ Covered by `emplace` | `emplace` for arrays is identical to `append` | Low priority |
| **`begin` / `end` / `cbegin` / `cend` / `rbegin` / `rend`** | Explicit iterator API | ❌ Not implemented | Swift `Sequence`/`Collection` conformance provides equivalent iteration with `for-in` loops | Possible later |
| **`front` / `back`** | First/last element access | ❌ Named `first` / `last` | Same semantics, Swift-familiar naming | Low priority |
| **`meta()`** | Returns library version info | ❌ Not implemented | C++-specific; Swift packages track version via `Package.swift` | Unlikely |
| **`get_allocator()`** | Allocator access | ❌ Not implemented | C++-specific concept; irrelevant in Swift's ARC model | Unlikely |
| **`operator<<` / `operator>>`** | Stream I/O operators | ❌ Not implemented | Swift uses `dump()` / `parse()` instead of stream operators | Unlikely |
| **`operator""_json`** | String literal for JSON | ❌ Not implemented | Swift doesn't support custom string literals; use `JSON.parse("...")` instead | Unlikely |
| **`to_string`** | ADL-friendly string conversion | ❌ Not implemented | Swift has `CustomStringConvertible` / `dump()` | Low priority |

### Summary

All major feature categories from `nlohmann/json` are implemented:

- ✅ Factory methods, type checks, subscript/at/value access
- ✅ Modifiers (clear, erase, append, insert, emplace, update, swap)
- ✅ Comparison operators (==, !=, <, <=, >, >=)
- ✅ Sequence conformance (for-in, items())
- ✅ Parsing (parse, accept) and serialization (dump)
- ✅ SAX parsing (saxParse)
- ✅ Flatten/unflatten, JSON Pointer (resolve, set)
- ✅ JSON Patch (patch, patchInPlace, diff) and Merge Patch (mergePatch)
- ✅ All five binary formats (CBOR, MessagePack, UBJSON, BSON, BJData)
- ✅ Hashable, Sendable, and full documentation

The missing features are either **Swift-inappropriate** (C++ stream operators, allocators, string literals, unsigned integer distinction) or **naming differences** (`append` vs `push_back`, `first`/`last` vs `front`/`back`). None affect the library's ability to serve as a complete ordered JSON implementation for Swift.

---

## Codable Support

OrderedJSON provides full `Codable` interop with Foundation, plus dedicated `OrderedJSONEncoder` and `OrderedJSONDecoder` that preserve key order through encoding and decoding.

### JSON: Codable Conformance

`JSON` itself conforms to `Encodable` and `Decodable`, so you can use it with Foundation's `JSONEncoder` and `JSONDecoder`:

```swift
let json = JSON.object([
  "name": .string("Alice"),
  "age": .number(.integer(30)),
])

// Encode JSON with Foundation's JSONEncoder
let data = try JSONEncoder().encode(json)

// Decode back with Foundation's JSONDecoder
let decoded = try JSONDecoder().decode(JSON.self, from: data)
// decoded == json (Foundation may reorder keys)
```

> **Note:** Foundation's `JSONDecoder` sorts keys alphabetically by default, so key order from the original `JSON` value may not be preserved. Use `OrderedJSONDecoder` for order-preserving decoding.

### OrderedJSONEncoder

`OrderedJSONEncoder` encodes `Codable` types directly into `JSON` values, preserving the order of keys as declared in the struct (or as encoded by a custom `encode(to:)` implementation).

```swift
struct Person: Codable {
  let name: String
  let age: Int
}

let encoder = OrderedJSONEncoder()
let json = try encoder.encode(Person(name: "Alice", age: 30))
// json is a JSON object with keys in declaration order: ["name", "age"]

// Or encode directly to a compact JSON string
let string = try encoder.encodeToString(Person(name: "Bob", age: 25))
// "{\"name\":\"Bob\",\"age\":25}"
```

Key features:

- **Key order preserved**: Keys appear in the order they were declared in the `Codable` type or written by `encode(to:)`.
- **Nested containers**: Nested objects/arrays via `nestedContainer(keyedBy:forKey:)` and `nestedUnkeyedContainer(forKey:)` work correctly — child mutations propagate to parent entries.
- **Super encoders**: `superEncoder()` and `superEncoder(forKey:)` write results back under the key `"super"` (matching Foundation convention).
- **Full integer/unsigned width support**: `Int8`, `Int16`, `Int32`, `Int64`, `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` — all encode without loss. `UInt64` values exceeding `Int64.max` throw `EncodingError.invalidValue`.
- **Set `userInfo` before calling**: Mutations after `encode()` do not propagate to nested containers.

### OrderedJSONDecoder

`OrderedJSONDecoder` decodes `Codable` types from `JSON`, `Data`, or JSON strings, preserving key insertion order. For `JSON` targets, keys are reported in the original parsed order. For struct types, the decoder's `allKeys` array preserves insertion order.

```swift
struct Person: Decodable {
  let name: String
  let age: Int
}

let decoder = OrderedJSONDecoder()

// Decode from a JSON value
let json = try JSON.parse(#"{"name": "Alice", "age": 30}"#)
let person1 = try decoder.decode(Person.self, from: json)

// Decode from raw data
let data = Data(#"{"name": "Bob", "age": 25}"#.utf8)
let person2 = try decoder.decode(Person.self, from: data)

// Decode from a JSON string
let person3 = try decoder.decode(Person.self, from: "{\"name\": \"Charlie\", \"age\": 35}")

// Decode JSON itself — keys preserved from input
let ordered = try decoder.decode(JSON.self, from: #"{"z": 1, "a": 2, "m": 3}"#)
// ordered.keys == ["z", "a", "m"] (insertion order)
```

Key features:

- **Key order preserved**: `JSON` objects decoded via `OrderedJSONDecoder` retain their parsed insertion order.
- **`decodeIfPresent`**: Optional fields work correctly — absent keys return `nil`, explicit `null` returns `nil`, present values decode normally.
- **Full integer/unsigned width support**: `Int8`, `Int16`, `Int32`, `Int64`, `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` — all decode with bounds-checked conversion. Values outside the target type's range throw `DecodingError.typeMismatch`.
- **Coding path propagation**: Every container threads the coding path, so decoding errors include meaningful paths (e.g., `["address", "zip"]`).
- **Set `userInfo` before calling**: Mutations after `decode()` do not propagate to nested containers.

### Convenience: JSON.encode(_:)

Encode any `Codable` type directly into a `JSON` value — no need to manually instantiate `OrderedJSONEncoder`:

```swift
struct Person: Codable {
  let name: String
  let age: Int
}

let json = try JSON.encode(Person(name: "Alice", age: 30))
// json["name"] == "Alice", json["age"] == 30
// Keys are in declaration order: ["name", "age"]
```

Works with any `Encodable` type — arrays, strings, and nested structures:

```swift
// Arrays
let arr = try JSON.encode([1, 2, 3])     // [1, 2, 3]

// Strings
let str = try JSON.encode("hello")       // "hello"
```

This lives in `Sources/OrderedJSON/Codable/JSON+Encode.swift` and wraps `OrderedJSONEncoder`.

### Convenience: JSON.decode(_:from:)

Decode any `Codable` type from a `JSON` value, or combine parsing and decoding in a single call from strings/data:

```swift
struct Person: Codable {
  let name: String
  let age: Int
}

// From an existing JSON value (no re-parsing)
let json = JSON.object(["name": .string("Alice"), "age": .number(.integer(30))])
let p1 = try JSON.decode(Person.self, from: json)

// From a JSON string
let p2 = try JSON.decode(Person.self, from: "{\"name\": \"Bob\", \"age\": 25}")

// From raw data
let data = Data(#"{"name": "Charlie", "age": 35}"#.utf8)
let p3 = try JSON.decode(Person.self, from: data)

// With parser options
let opts = JSON.ParserOptions(allowTrailingCommas: true)
let p4 = try JSON.decode(Person.self, from: "{\"name\": \"Dave\", \"age\": 45,}", options: opts)
```

These live in `Sources/OrderedJSON/Codable/JSON+Decode.swift` and depend on `OrderedJSONDecoder`.

### JSONWithExtras<T>

Capture unknown JSON keys as extras while decoding known fields into a strongly-typed struct — similar to `#[serde(flatten)]` in serde.

```swift
struct Person: Codable {
  let name: String
  let age: Int
}

let data = Data(#"""
  {"name": "Alice", "age": 30, "color": "blue", "city": "NYC"}
  """#.utf8)

let wrapped = try OrderedJSONDecoder().decode(
  JSONWithExtras<Person>.self, from: data)

// Known fields
wrapped.value.name  // "Alice"
wrapped.value.age   // 30

// Unknown keys captured as extras
wrapped.extras["color"]  // .string("blue")
wrapped.extras["city"]   // .string("NYC")
```

`JSONWithExtras` works by:
1. Decoding all keys as raw `JSON` values
2. Decoding `T` while tracking which keys it accesses via `decode(...)` and `decodeNil(forKey:)`
3. Treating unaccessed keys as extras

**Known limitations:**
- `contains(_:)` does **not** mark keys as accessed — use `decodeIfPresent` for optional fields
- `T` must encode/decode as a keyed object; single-value and unkeyed containers are not supported
- Extras must be a JSON object when encoding; non-object extras throw `EncodingError.invalidValue`

### Throwing Typed Accessors

`JSON` provides throwing accessors for strong typing without optional unwrapping:

```swift
let json = try JSON.parse(#"{"name": "Alice", "count": 42, "rate": 3.14, "active": true}"#)

// String
let name = try json["name"]?.requireString()  // "Alice"

// Boolean
let active = try json["active"]?.requireBool()  // true

// Integers — accepts both .integer and .float (when float is a clean integer)
let count = try json["count"]?.requireInt64()  // 42
let count32 = try json["count"]?.requireInt32()  // 42
let countU = try json["count"]?.requireUInt()  // 42

// Floats — accepts both .float and .integer (widening)
let rate = try json["rate"]?.requireDouble()  // 3.14
let rateF = try json["rate"]?.requireFloat()  // 3.14 (lossless)

// Bounds-checked integer widths
let small = try json["count"]?.requireInt8()   // 42
let large = try json["count"]?.requireUInt64()  // 42

// All throw JSONError.typeError on type mismatch with descriptive messages
```

Available accessors:

| Method | Accepts | Returns | Throws if |
|--------|---------|---------|-----------|
| `requireString()` | `.string` | `String` | Not a string |
| `requireBool()` | `.boolean` | `Bool` | Not a boolean |
| `requireInt64()` | `.integer` or `.float` (clean integer) | `Int64` | Not a number or fractional float |
| `requireInt()` | `.integer` or `.float` (clean integer) | `Int` | Not a number, or out of `Int` range |
| `requireInt8()` | `.integer` or `.float` (clean integer) | `Int8` | Not a number, or out of `Int8` range |
| `requireInt16()` | `.integer` or `.float` (clean integer) | `Int16` | Not a number, or out of `Int16` range |
| `requireInt32()` | `.integer` or `.float` (clean integer) | `Int32` | Not a number, or out of `Int32` range |
| `requireDouble()` | `.float` or `.integer` (widening) | `Double` | Not a number |
| `requireFloat()` | `.float` or `.integer` (widening) | `Float` | Not a number, or not losslessly representable |
| `requireUInt()` | `.integer` or `.float` (clean integer) | `UInt` | Not a number, or negative / out of `UInt` range |
| `requireUInt8()` | `.integer` or `.float` (clean integer) | `UInt8` | Not a number, or negative / out of `UInt8` range |
| `requireUInt16()` | `.integer` or `.float` (clean integer) | `UInt16` | Not a number, or negative / out of `UInt16` range |
| `requireUInt32()` | `.integer` or `.float` (clean integer) | `UInt32` | Not a number, or negative / out of `UInt32` range |
| `requireUInt64()` | `.integer` or `.float` (clean integer) | `UInt64` | Not a number, or negative |

> **Note:** `requireFloat()` uses lossless conversion (`Float(exactly:)`). Values like `0.1` that are not exactly representable as `Float` throw `JSONError.typeError`. For Foundation-compatible lossy narrowing, use `requireDouble()` and cast manually.

### Round-Trip Example

Full round-trip through `OrderedJSONEncoder` → serialization → parsing → `OrderedJSONDecoder`:

```swift
struct Person: Codable {
  let name: String
  let age: Int
  let address: String?
}

let original = Person(name: "Alice", age: 30, address: nil)

// Encode
let encoder = OrderedJSONEncoder()
let json = try encoder.encode(original)

// Serialize to string
let jsonString = json.dump(indent: -1)
// {"name":"Alice","age":30,"address":null}

// Parse back
let parsed = try JSON.parse(jsonString)

// Decode
let decoder = OrderedJSONDecoder()
let roundTripped = try decoder.decode(Person.self, from: parsed)
// roundTripped == original
```

---

## Best Practices

- **Empty objects**: Use `JSON.object([:])` or `JSON.object(OrderedDictionary())`.
- **Numeric types**: Use `.integer(Int64)` for whole numbers and `.float(Double)` for decimals to preserve type information through encoding/decoding.
- **Error handling**: Wrap parsing from untrusted sources in `do {} catch {}`.
- **Thread safety**: `JSON` is `Hashable` and `Sendable`, safe to use in collections and across concurrency domains.
- **Order preservation**: Use `JSON.parse()` for order-preserving parsing and `dump(-1)` for compact serialization.
- **Flatten round-trip**: `flatten()` followed by `unflatten()` returns the original value.
- **Choose access pattern**: Use `[]` for optional access, `at()` for throwing access, `value()` for default-value access.
