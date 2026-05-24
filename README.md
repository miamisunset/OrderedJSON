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
var opts = JSON.ParserOptions()
opts.allowTrailingCommas = true
opts.maxDepth = 512

// Trailing commas in arrays and objects
let trailing = try JSON.parse("[1, 2, 3,]", options: opts)
// trailing == [1, 2, 3]

// Nesting depth limit — throws depthExceeded
let deep = "{\"a\": {\"b\": {\"c\": {\"d\": 1}}}"
// JSON.parse(deep, options: opts) would throw at depth > 512
```

`allowTrailingCommas` (default `false`) accepts JSON with trailing commas. `maxDepth` (default `1024`) sets the maximum nesting depth before throwing `depthExceeded`.

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

## Best Practices

- **Empty objects**: Use `JSON.object([:])` or `JSON.object(OrderedDictionary())`.
- **Numeric types**: Use `.integer(Int64)` for whole numbers and `.float(Double)` for decimals to preserve type information through encoding/decoding.
- **Error handling**: Wrap parsing from untrusted sources in `do {} catch {}`.
- **Thread safety**: `JSON` is `Hashable` and `Sendable`, safe to use in collections and across concurrency domains.
- **Order preservation**: Use `JSON.parse()` for order-preserving parsing and `dump(-1)` for compact serialization.
- **Flatten round-trip**: `flatten()` followed by `unflatten()` returns the original value.
- **Choose access pattern**: Use `[]` for optional access, `at()` for throwing access, `value()` for default-value access.
