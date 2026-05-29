# OrderedJSON — Swift-Native Ordered JSON

A Swift library that preserves JSON key order with a rich method-based API, inspired by `nlohmann::basic_json` (`JSON for Modern C++`) but designed to be Swift-idiomatic. Includes order-preserving parsing, type checks, subscript access, modifiers, flatten/unflatten, JSON Patch/Merge Patch/Diff, SAX parsing, JSON Schema validation and inference, binary format support (CBOR, MessagePack, UBJSON, BSON, BJData), and full `Codable` interop with key-order preservation.

---

## Table of Contents

<details>
<summary>Click to expand</summary>

- [Why OrderedJSON?](#why-orderedjson)
- [Architecture Overview](#architecture-overview)
- [Quick Start](#quick-start)
- [Performance](#performance)
  - [Parsing](#parsing)
  - [Encoding / Serialization](#encoding-serialization)
  - [Binary Formats](#binary-formats)
  - [Codable](#codable)
  - [Comparison vs. Foundation](#comparison-vs-foundation)
- [Installation](#installation)
- [Creating Values](#creating-values)
- [JSONBuilder](#jsonbuilder)
  - [ObjectBuilder](#objectbuilder)
  - [ArrayBuilder](#arraybuilder)
  - [When to use builders](#when-to-use-builders)
- [Parsing JSON](#parsing-json)
  - [Duplicate keys](#duplicate-keys)
  - [Parser options](#parser-options)
  - [Parsing from Data](#parsing-from-data)
  - [Error handling](#error-handling)
- [Encoding / Serialization](#encoding-serialization)
- [Type Checks](#type-checks)
- [Subscript / At / Value Access](#subscript-at-value-access)
- [Capacity / Lookup](#capacity-lookup)
- [Modifiers](#modifiers)
- [Flatten / Unflatten](#flatten-unflatten)
- [JSON Pointer](#json-pointer)
- [Comparison Operators](#comparison-operators)
  - [Type ordering](#type-ordering)
  - [Mixed number comparison](#mixed-number-comparison)
- [Sequence Conformance](#sequence-conformance)
- [JSON Patch (RFC 6902)](#json-patch-rfc-6902)
- [Diff](#diff)
- [JSON Merge Patch (RFC 7396)](#json-merge-patch-rfc-7396)
- [SAX Parsing](#sax-parsing)
- [Binary Formats](#binary-formats)
- [JSON Schema](#json-schema)
  - [Creating a Schema](#creating-a-schema)
  - [Validation](#validation)
  - [Drafts](#drafts)
  - [Format Options](#format-options)
  - [Output Modes](#output-modes)
  - [Schema Inference](#schema-inference)
- [Swift Idioms](#swift-idioms)
  - [@dynamicMemberLookup](#dynamicmemberlookup)
  - [ExpressibleBy*Literal](#expressiblebyliteral)
  - [Sendable & StrictConcurrency](#sendable--strictconcurrency)
- [Feature Parity vs. nlohmann/json](#feature-parity-vs-nlohmann-json)
  - [Summary](#summary)
- [Codable Support](#codable-support)
  - [JSON: Codable Conformance](#json-codable-conformance)
  - [OrderedJSONEncoder](#orderedjsonencoder)
  - [OrderedJSONDecoder](#orderedjsondecoder)
  - [Foundation Type Support](#foundation-type-support)
  - [Convenience: JSON.encode(_:)](#convenience-json-encode-_)
  - [Convenience: JSON.decode(_:from:)](#convenience-json-decode-_-from)
  - [JSONWithUnknownKeys<T>](#jsonwithunknownkeys-t)
  - [Throwing Typed Accessors](#throwing-typed-accessors)
  - [Round-Trip Example](#round-trip-example)
- [Best Practices](#best-practices)

</details>

---

## Why OrderedJSON?

Standard JSON dictionaries have no defined key order — Swift's `Dictionary` and most JSON libraries treat key order as an implementation detail. But many applications depend on insertion order:

- **API signatures** — signed requests, hash chains, deterministic serialization
- **Serialization formats** — pretty-printed output that matches the input
- **Configuration files** — human-readable, predictable ordering
- **Protocol buffers** — field-number ordering preserved through JSON interchange
- **UI rendering** — server-sent key order maps to UI layout order

OrderedJSON behaves like `nlohmann::ordered_json` — keys always retain the order they were inserted or parsed in. Every `dump()` call produces the same key order as the input. Unlike Foundation's `JSONSerialization` (which sorts keys alphabetically), OrderedJSON guarantees deterministic, insertion-order output.

---

## Architecture Overview

OrderedJSON is organized as a single `JSON` struct wrapping an internal `Storage` enum:

```
┌──────────────────────────────────────────────────┐
│                    JSON struct                    │
│  @dynamicMemberLookup, Hashable, Sendable        │
│                                                   │
│  ┌────────────────────────────────────────────┐   │
│  │               Storage enum                │   │
│  │  .null │ .boolean │ .number │ .string     │   │
│  │  .object(OrderedDictionary) │ .array      │   │
│  └────────────────────────────────────────────┘   │
│                                                   │
│  ┌────── Access ──────┐  ┌──── Modifiers ─────┐  │
│  │ subscript [key]     │  │ clear, remove      │  │

│  │ value(forKey:default:) │  │ setDefault, update │  │

│  │ parse(String)  │   │ cbor()      │   │ parse(handler:)││

│  │ parse(Data)    │   │ msgPack()   │   │ accept         ││

│  │ dump(indent:)  │   │ ubjson()    │   └────────────────┘│

│  └───────────────┘   │ bson()      │                    │

│                      │ bjdata()    │                    │
│                      └─────────────┘              │
│                                                   │
│  ┌── Flatten ──┐  ┌── Patch ───┐  ┌── Schema ──┐│
│  │ flatten()   │  │ patch()    │  │ schema()   ││
│  │ unflatten() │  │ diff()     │  │ validate() ││
│  └─────────────┘  │mergePatch()│  │ isValid()  ││
│                    └────────────┘  │validating()││
│                                    └─────────────┘│
│                                                   │
│  ┌── Codable ────────────────────────────────────┐│
│  │ OrderedJSONEncoder / OrderedJSONDecoder       ││
│  │ JSON.encode(_:) / JSON.decode(_:from:)       ││
│  │ JSONWithUnknownKeys<T>                             ││
│  └───────────────────────────────────────────────┘│
└──────────────────────────────────────────────────┘
```

Source files are organized by concern in `Sources/OrderedJSON/{Core,Parsing,Access,Modifiers,Flatten,Patch,SAX,Binary,Operators,Builder,Codable,Schema}/`.

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
let output = value.dump() // compact JSON string
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

- **Compact output**: Minimal overhead — mostly string escaping and concatenation.
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
let nul2  = JSON.null                       // null (alternative)

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

## JSONBuilder

For complex nested structures, `JSON.ObjectBuilder` and `JSON.ArrayBuilder` provide a fluent, chainable API. Each `set`/`add` method returns `self`, so you can chain calls without nested factory-method boilerplate.

### ObjectBuilder

Build ordered JSON objects by chaining `.set(key, value)` calls, then `.build()`:

```swift
let person = JSON.ObjectBuilder()
  .set("name", "Alice")
  .set("age", 30)
  .set("active", true)
  .set("pi", 3.14)
  .build()
// → {"name":"Alice","age":30,"active":true,"pi":3.14}
```

`.set` accepts `String`, `Bool`, `Int`, `Int64`, `Double`, `Float`, `[JSON]`, `JSON.ObjectBuilder`, `JSON.ArrayBuilder`, and raw `JSON` values. Nested objects and arrays use the builder's `.build()` directly:

```swift
let nested = JSON.ObjectBuilder()
  .set("name", "Alice")
  .set("address", JSON.ObjectBuilder()
    .set("city", "NYC")
    .set("zip", "10001")
    .build())
  .set("tags", JSON.ArrayBuilder()
    .add("admin")
    .add("user")
    .build())
  .build()
```

Additional methods:
- `.remove(key)` — removes a key from the builder
- `.merge(_ other: ObjectBuilder)` — merges all key-value pairs from another builder (existing keys are overwritten)
- `.count` — returns the current number of key-value pairs
- `.buildString(indent:)` — builds and serializes directly to a JSON string

### ArrayBuilder

Build ordered JSON arrays by chaining `.add(value)` calls, then `.build()`:

```swift
let items = JSON.ArrayBuilder()
  .add("a")
  .add(42)
  .add(true)
  .add(3.14)
  .build()
// → ["a",42,true,3.14]
```

`.add` accepts the same set of types as `.set`. Nested structures work naturally:

```swift
let mixed = JSON.ArrayBuilder()
  .add("outer")
  .add(JSON.ObjectBuilder()
    .set("x", 1)
    .build())
  .add(JSON.ArrayBuilder()
    .add("inner")
    .add(99)
    .build())
  .build()
```

Additional methods:
- `.count` — returns the current number of elements
- `.append(contentsOf other: ArrayBuilder)` — appends all elements from another builder
- `.append(contentsOf other: [JSON])` — appends elements from a JSON array
- `.buildString(indent:)` — builds and serializes directly to a JSON string

### When to use builders

- **Builder** — prefer for complex, deeply nested structures with mixed types. The chaining style eliminates nested `JSON.object(...)` / `JSON.array(...)` boilerplate.
- **Factory methods / inits** — prefer for simple literals or when constructing inline inside an existing builder call.

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

**Large integer overflow:** Integers larger than `Int64.max` (`9223372036854775807`) or smaller than `Int64.min` (`-9223372036854775808`) do **not** throw — they are stored as `.float(Double)` values, matching `nlohmann/json` behavior. Values very near the overflow boundary may lose precision when stored as `Double`.

**Overflow-to-infinity:** Numbers that overflow the `Double` range (e.g., `1e400`) throw `invalidNumber` instead of producing `inf` — which would serialize as `null` (silent data loss).

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

`dump()` produces compact JSON (no whitespace). `dump(indent: 2)` produces pretty-printed JSON. The key order is always preserved regardless of indent value.

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

x.type           // JSON.JSONType.number
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
try json.at(key: "name")      // JSON.string("Alice")
try json.at(index: 0)         // throws — root is not array
try json.at(key: "missing")   // throws — key not found

// Value with default — returns default for missing keys or indices
json.value(forKey: "name", default: JSON.null)       // JSON.string("Alice")
json.value(forKey: "missing", default: JSON("x"))    // JSON.string("x")

// Array value with default
let arr = JSON.array([.string("a"), .number(.integer(1))])
arr.value(at: 0, default: JSON.null)      // JSON.string("a")
arr.value(at: 99, default: JSON("x"))     // JSON.string("x") — out of bounds
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

json.first     // Optional(JSON.number(.integer(1)))  — first value
json.last      // Optional(JSON.number(.integer(3)))  — last value

json.contains(key: "b")   // true  — key exists in object
json.find(key: "b")       // Optional(JSON.number(.integer(2)))  — value for key
json.find(key: "missing") // nil
```

On objects, `contains` checks key existence. For arrays, `contains(element)` checks element presence using `==`. `find` retrieves the value for a key. `first`/`last` give you the first and last values in insertion order.

```swift
let arr = JSON.array([
  .string("a"),
  .number(.integer(1)),
  .boolean(true)
])
arr.contains(element: .string("a"))     // true — element exists
arr.contains(element: .string("z"))     // false — element missing
```

---

## Modifiers

OrderedJSON provides mutating methods for modifying JSON values in place. All modifier methods are `mutating` — they require a `var` binding.

```swift
var json = JSON.parse("""
  {"a": 1, "b": 2}
  """)

json.clear()              // remove all keys/elements
json["a"] = JSON(10)      // set via subscript
json.remove(key: "a")           // remove key from object
json.remove(at: 0)             // remove first element (array only)

// Array operations
var arr = JSON.array([JSON(1), JSON(2), JSON(3)])
arr.append(JSON(4))                       // [1, 2, 3, 4]
arr.insert(JSON(0), at: 0)               // [0, 1, 2, 3, 4]
arr.append(JSON(5))                     // append if array, no-op for objects

// Object operations
var obj = JSON.object(["x": JSON(1)])
obj.setDefault(key: "y", JSON(2))   // adds if key absent
obj.setDefault(key: "x", JSON(99))  // no-op — key exists
obj.update(with: JSON.object(["y": JSON(3), "z": JSON(4)]))  // merge keys

// Recursive merge — nested objects are merged, not replaced
var config = JSON.object([
  "app": JSON.object(["theme": JSON.string("dark"), "lang": JSON.string("en")])
])
let patch = JSON.object([
  "app": JSON.object(["lang": JSON.string("fr")])  // only override lang
])
config.update(with: patch, mergingNested: true)
// config["app"]["theme"] == "dark"  (preserved)
// config["app"]["lang"] == "fr"    (updated)
// Without mergeObjects: app would be replaced entirely, losing "theme"

// Swap two values
var a = JSON(1), b = JSON(2)
a.swap(with: &b)  // a == 2, b == 1
```

**Key distinction:** `append`/`insert` work on arrays. `setDefault`/`update` work on objects. `remove` works on both — use a string key for objects, an integer index for arrays.

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

let restored = try flat.unflatten()
// restored == json (round-trip)
```

This is useful for serialization to flat formats (e.g., query strings, database columns) while retaining the ability to reconstruct the original hierarchy. The JSON Pointer format matches `nlohmann/json` exactly.

**Empty containers:** Empty objects and arrays are flattened to `null` values (matching nlohmann/json behavior). After round-trip, empty containers become `null` — they cannot be restored to their original type.

**Input validation:** `unflatten()` validates that the input is a JSON object with primitive values only. It throws `FlattenError.notObject` for non-object input or `FlattenError.notPrimitive(key)` when a value is not a primitive type.

**RFC 6901 escaping:** Keys containing `~` (tilde) or `/` (slash) are properly escaped during `flatten()` — `~` becomes `~0`, `/` becomes `~1`. During `unflatten()`, segments are unescaped in RFC-specified order (`~1`→`/` first, then `~0`→`~`), ensuring correct round-trip for keys with special characters.

---

## JSON Pointer

A `JSONPointer` resolves a pointer string against a JSON value to retrieve the referenced element. The implementation follows RFC 6901 with full support for the standard features and error types.

```swift
let json = JSON.parse("""
  {"a": {"b": {"c": 42}}}
  """)

let ptr = try JSONPointer("/a/b/c")
ptr.resolve(json)  // Optional(JSON.number(.integer(42)))
```

JSON Pointer (RFC 6901) is the standard way to reference a specific value within a JSON document. The `/` prefix denotes the root.

### JSONPointerError

JSON Pointer operations throw `JSONPointerError` with three cases:

- `.invalidSyntax(String)` — pointer string is malformed (e.g., doesn't start with `/`)
- `.missingValue(String)` — pointer references a nonexistent value
- `.leadingZero(String)` — array index has a leading zero (not allowed per RFC 6901 ABNF)

All cases conform to `CustomStringConvertible`, `Hashable`, and `Sendable`.

### Initialization

```swift
// Standard pointer — must start with /
let ptr1 = try JSONPointer("/foo/bar")

// Root pointer (empty string)
let root = try JSONPointer("")
root.segments  // [] (empty)

// URI fragment — strips # prefix and percent-decodes
let ptr2 = try JSONPointer(fragment: "#/c%25d")
ptr2.segments  // ["c%d"]

// Leading zeros in array indices throw
// JSONPointerError.leadingZero
let ptr3 = try JSONPointer("/01")       // throws
let ptr4 = try JSONPointer("/0")        // OK — single digit "0" is valid

// Invalid syntax throws JSONPointerError.invalidSyntax
let ptr5 = try JSONPointer("foo")       // throws — no leading /
let ptr6 = try JSONPointer(fragment: "/foo")  // throws — no #
```

### Resolution

```swift
let json = JSON.parse("""
  {"a": {"b": [1, 2, 3]}}
  """)

let ptr = try JSONPointer("/a/b/2")
ptr.resolve(json)  // Optional(JSON.number(.integer(3)))

// Missing key/index returns nil
let missing = try JSONPointer("/x")
misssing.resolve(json)  // nil

// "-" token — RFC 6901 array append marker
// resolve returns nil (nonexistent element after last array element)
let dash = try JSONPointer("/-/")
dash.resolve(json)  // nil

// Throwing resolution — throws JSONPointerError.missingValue
let value = try ptr.resolveOrThrow(json)
// value == JSON.number(.integer(3))
```

### Setting values

`set(into:value:)` mutates a JSON value at the pointer path, creating intermediate objects/arrays as needed:

```swift
var json = JSON.object(["a": JSON.number(.integer(1))])

let ptr = try JSONPointer("/b/c")
ptr.set(value: JSON.string("deep"), into: &json)
// json == {"a": 1, "b": {"c": "deep"}}

// Root pointer replaces the entire value
let root = try JSONPointer("")
root.set(value: JSON.number(.integer(42)), into: &json)
// json == 42

// "-" token appends to an array
var arr = JSON.array([JSON.string("a")])
let append = try JSONPointer("/-")
append.set(value: JSON.string("b"), into: &arr)
// arr == ["a", "b"]

// If the target is not an array, "-" creates one
var obj = JSON.object([:])
let force = try JSONPointer("/-")
force.set(value: JSON.string("first"), into: &obj)
// obj == ["first"] (was an object, now an array)
```

### Description (canonical pointer string)

The `description` property returns the canonical JSON Pointer string per RFC 6901 §5, with proper `~0`/`~1` escaping:

```swift
let ptr = try JSONPointer("/a~1b/m~0n")
ptr.description   // "/a~1b/m~0n" — segments are escaped canonically

let root = try JSONPointer("")
root.description   // "" — root pointer has no description

// Round-trip: description → JSONPointer produces equivalent segments
let roundtrip = try JSONPointer(ptr.description)
roundtrip.segments == ptr.segments  // true
```

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
// Type ordering examples (same-type comparisons only)
JSON.null < JSON.boolean(true)                // true (null < any non-null)
JSON.boolean(false) < JSON.boolean(true)       // true
JSON.number(.integer(1)) < JSON.number(.integer(2))  // true
JSON.string("a") < JSON.string("b")            // true
JSON.object(["x": JSON(1)]) < JSON.object(["x": JSON(1), "y": JSON(2)]) // true (by count)
JSON.array([JSON(1)]) < JSON.array([JSON(1), JSON(2)]) // true (by count)
```

### Mixed number comparison

The `<` and `>` operators compare integers and floats as numbers. However, `==` treats `.integer` and `.float` as distinct enum cases — `42` as integer and `42.0` as float are **not** equal:

```swift
JSON.number(.integer(1)) < JSON.number(.float(2.5))    // true
JSON.number(.integer(42)) == JSON.number(.float(42.0))  // false (different enum cases)
JSON.number(.float(42.0)) == JSON.number(.integer(42))  // false
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

// Key-value pairs via keyValuePairs()
for (key, value) in obj.keyValuePairs() {
  print("\(key): \(value)")  // x: 10, y: 20
}
```

When iterating an object, `Sequence` yields values in insertion order. Use `keyValuePairs()` to get both keys and values together.

---

## JSON Patch (RFC 6902)

JSON Patch defines a sequence of operations to transform a JSON document. OrderedJSON supports both non-mutating (`applying`) and mutating (`patch`) application.

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
let patched = try source.applying(patch)

// Mutating — modifies in place
var mutable = source
try mutable.patch(patch)
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

let ok = JSON.parse("""{"a": 1}""", handler: MyHandler())
// Prints: { key: a int: 1 }

// Non-throwing validation — returns true for valid JSON
JSON.accept("""{"valid": 1}""")   // true
JSON.accept("invalid")            // false
```

Return `false` from any handler method to abort parsing early. `accept()` is a convenience wrapper that returns `Bool` instead of throwing — it validates a JSON string without constructing a `JSON` value.

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
let cbor = json.cbor()
let back = try JSON(cbor: cbor)

// MessagePack
let msg = json.msgPack()
let back2 = try JSON(msgPack: msg)

// UBJSON
let ubj = json.ubjson()
let back3 = try JSON(ubjson: ubj)

// BSON
let bson = json.bson()
let back4 = try JSON(bson: bson)

// BJData
let bjd = json.bjdata()
let back5 = try JSON(bjdata: bjd)
```

All five formats preserve key order during encode and decode round-trips.

---

## JSON Schema

OrderedJSON provides full JSON Schema validation and inference. Create a compiled schema from a schema JSON document, then validate documents against it. Supports Draft 7 and Draft 2020-12.

### Creating a Schema

```swift
let schemaJSON = JSON.parse("""
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
```

You can also specify the draft explicitly:

```swift
let schema = try JSONSchema(schema: schemaJSON, draft: .draft7)
```

The `.auto` draft (default) detects the draft from the `$schema` keyword, falling back to `.draft202012` if absent.

### Validation

Three validation methods:

```swift
// Throw on first error — returns true on success
let valid = try schema.validate(document)

// Collect all errors — returns VerboseResult (never throws)
let result = schema.validating(document)

// Simple boolean check — never throws
if schema.isValid(document) {
  print("Document is valid")
}
```

`VerboseResult` wraps `JSONSchemaResult` with optional hierarchical errors:

```swift
let result = schema.validating(document)
print(result.valid)   // true or false

// Access flat errors
for error in result.errors {
  print("[\(error.keyword)] \(error.message)")
  print("  instance: \(error.instancePath)")
  print("  schema:   \(error.schemaPath)")
}

// Throw if invalid
try result.throwOnError()
```

`JSONSchemaError` includes:

```swift
let error: JSONSchemaError
error.instancePath    // "/name" — JSON Pointer to the failing value
error.schemaPath      // "/properties/name/type" — JSON Pointer to the failing keyword
error.keyword         // "type" — the keyword that failed
error.message         // "expected string, got number"
error.failedValue     // Optional(JSON) — the value that failed validation
error.parentSchema    // Optional(JSON) — the parent schema node
```

### Drafts

```swift
JSONSchema.Draft.draft7         // JSON Schema Draft 7 (2018) — OpenAPI 3.0
JSONSchema.Draft.draft202012    // JSON Schema Draft 2020-12 (2022) — current standard
JSONSchema.Draft.auto           // Auto-detect from $schema keyword
```

### Format Options

Control which string formats are validated:

```swift
var formatOptions = JSONSchemaFormatOptions()
// All formats enabled by default

formatOptions.disable(.email)
formatOptions.enable(.email)

formatOptions.isEnabled(.dateTime)  // true/false
```

Supported formats: `dateTime`, `date`, `time`, `duration`, `email`, `hostname`, `ipv4`, `ipv6`, `uuid`, `uri`, `uriReference`, `jsonPointer`, `regex`.

### Output Modes

```swift
JSONSchema.OutputMode.basic     // Flat list of errors (default)
JSONSchema.OutputMode.verbose   // Hierarchical errors with nested sub-errors
```

In verbose mode, `VerboseError` captures nested validation failures:

```swift
struct VerboseError: Hashable, Sendable {
  let error: JSONSchemaError
  let children: [VerboseError]   // Sub-errors from allOf/anyOf/oneOf/if-then-else
}
```

### Schema Inference

Generate a JSON Schema that describes an existing JSON instance:

```swift
let instance = JSON.parse("""
  {"name": "Alice", "age": 30, "tags": ["admin", "user"]}
  """)

// Generate raw schema JSON
let generatedSchema = JSONSchemaGeneration.generate(from: instance)

// Or get a compiled schema directly
let schema = try instance.schema()
// Uses draft 2020-12 by default, returns JSONSchema ready for validation

// With custom options
let schema = try instance.schema(
  draft: .draft202012,
  formatOptions: JSONSchemaFormatOptions(),
  outputMode: .verbose
)
```

Inference rules:
- `null` → `{"type": "null"}`
- `boolean` → `{"type": "boolean"}`
- `integer` → `{"type": "integer"}`
- `float` → `{"type": "number"}`
- `string` → `{"type": "string"}`
- `array` (homogeneous) → `{"type": "array", "items": <schema>}`
- `array` (heterogeneous) → `{"type": "array", "prefixItems": [...]}`
- `object` → `{"type": "object", "properties": {...}, "required": [...], "additionalProperties": false}`

---

## Swift Idioms

OrderedJSON embraces Swift language features to make JSON manipulation feel natural.

### @dynamicMemberLookup

Access object keys via dot-notation instead of bracket subscripts:

```swift
let json = try JSON.parse(#"{"user": {"name": "Alice", "age": 30}}"#)

// Dot-notation access
json.user.name   // JSON.string("Alice") — equivalent to json["user"]["name"]
json.user.age    // JSON.number(.integer(30))

// Missing keys return .null (not nil)
json.missingKey  // JSON.null

// Setting via dot-notation
var mutable = json
mutable.user.name = JSON.string("Bob")
```

This works for any depth of nesting — `json.a.b.c.d` resolves the same as `json["a"]["b"]["c"]["d"]`.

### ExpressibleBy*Literal

> **Note:** `ExpressibleByArrayLiteral`, `ExpressibleByDictionaryLiteral`, and `ExpressibleByStringLiteral` conformances are intentionally **not** implemented. Swift's literal syntax for dictionaries and arrays cannot be overloaded to produce `JSON` values without losing type safety (e.g., `["key": "value"]` is ambiguous — it could be a Swift dictionary or a JSON object). Use the explicit factory methods (`JSON.object([:])`, `JSON.array([...])`) or convenience initializers instead.

### Sendable & StrictConcurrency

`JSON` is a `Hashable` and `Sendable` value type — it is safe to pass across concurrency domains and use with `@Sendable` closures:

```swift
// Thread-safe by design — JSON is a struct, all stored properties are Sendable
let json = try JSON.parse("{\"key\": \"value\"}")

// Safe to use in Task isolation boundaries
Task {
  let value = json["key"]
  // value is Sendable
}
```

The library is built with Swift 6 language mode (`StrictConcurrency`) enabled. All public APIs are explicitly `Sendable`-annotated where needed.

---

## Feature Parity vs. nlohmann/json

OrderedJSON covers ~95% of `nlohmann::basic_json`'s API surface. Here are the gaps, why they exist, and whether we plan to add them.

| Feature | nlohmann/json | OrderedJSON | Reason | Future? |
|---------|---------------|-------------|--------|---------|
| **`is_number_unsigned`** | Detects `uint64_t` integers | ❌ Not implemented | Swift uses `Int64` for all integers; `UInt64` isn't needed since JSON numbers have no unsigned concept per RFC 7159 | Unlikely |
| **`is_binary` / `is_discarded`** | Binary byte array type / SAX discarded state | ❌ Not implemented | Binary CBOR/msgpack data decoded as base64 strings; discarded state is internal to SAX parsing | Possible later |
| **`get<T>()`, `get_to()`, `get_ptr()`, `get_ref()`** | Template-based value extraction | ❌ Removed — use `require*()` methods directly | Generic dispatch adds no safety over individual methods; `requireString()`, `requireInt64()`, etc. are clearer | — |
| **`push_back`** | Named `push_back` for arrays | ❌ Named `append` instead | Swift convention uses `append`; semantics are identical | Low priority |
| **`operator+=`** | Compound assignment for array/object addition | ❌ Not implemented | Swift uses `append` / `+=` on arrays directly | Unlikely |
| **`emplace_back`** | Emplace back for arrays | ❌ Covered by `append` | `append` for arrays covers this | Low priority |
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
- ✅ Modifiers (clear, remove, append, insert, setDefault, update, swap)
- ✅ Comparison operators (==, !=, <, <=, >, >=)
- ✅ Sequence conformance (for-in, keyValuePairs())
- ✅ Parsing (parse, accept) and serialization (dump)
- ✅ SAX parsing (parse(handler:))
- ✅ Flatten/unflatten, JSON Pointer (resolve, set)
- ✅ JSON Patch (applying, patch, diff) and Merge Patch (mergePatch)
- ✅ All five binary formats (CBOR, MessagePack, UBJSON, BSON, BJData)
- ✅ JSON Schema validation and inference
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
let string = try encoder.encodeAsString(Person(name: "Bob", age: 25))
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

### Foundation Type Support

`OrderedJSONEncoder` and `OrderedJSONDecoder` provide built-in support for Foundation types — `Date`, `URL`, `UUID`, `Decimal`, and `Data` — with configurable strategies that mirror Foundation's `JSONEncoder`/`JSONDecoder`.

#### Date Strategies

Control how dates are encoded/decoded:

```swift
struct Event: Codable {
  let timestamp: Date
}

let event = Event(timestamp: Date(timeIntervalSince1970: 1_234_567_890))

// Seconds since 1970
var encoder = OrderedJSONEncoder()
encoder.dateEncodingStrategy = .secondsSince1970
let json = try encoder.encode(event)   // {"timestamp": 1234567890.0}

var decoder = OrderedJSONDecoder()
decoder.dateDecodingStrategy = .secondsSince1970
let back = try decoder.decode(Event.self, from: json)

// ISO 8601 strings
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
  // Return any JSON value
  return .object(["epoch": .number(.integer(Int64(date.timeIntervalSince1970)))])
}
decoder.dateDecodingStrategy = .custom { json, decoder in
  return Date(timeIntervalSince1970: try json["epoch"].requireDouble())
}
```

Available strategies:
- `DateEncodingStrategy`: `.deferredToDate`, `.secondsSince1970`, `.millisecondsSince1970`, `.iso8601`, `.formatted(DateFormatter)`, `.custom((Date, Encoder) throws -> JSON)`
- `DateDecodingStrategy`: `.deferredToDate`, `.secondsSince1970`, `.millisecondsSince1970`, `.iso8601`, `.formatted(DateFormatter)`, `.custom((JSON, Decoder) throws -> Date)`

> The `.iso8601` strategy uses `ISO8601DateFormatter` with `.withInternetDateTime | .withFractionalSeconds` options.
> Dates always include fractional seconds (e.g. `2025-01-15T08:30:45.123Z`).

#### Data Strategies

```swift
let raw = Data([0xDE, 0xAD, 0xBE, 0xEF])

var encoder = OrderedJSONEncoder()
encoder.dataEncodingStrategy = .base64
let json = try encoder.encode(Container(data: raw))  // {"data": "3q2+7w=="}

var decoder = OrderedJSONDecoder()
decoder.dataDecodingStrategy = .base64
let back = try decoder.decode(Container.self, from: json)  // Data([0xDE, 0xAD, 0xBE, 0xEF])
```

Available strategies (default: `.base64`):
- `DataEncodingStrategy`: `.deferredToData`, `.base64`, `.custom((Data, Encoder) throws -> JSON)`
- `DataDecodingStrategy`: `.deferredToData`, `.base64`, `.custom((JSON, Decoder) throws -> Data)`

#### URL, UUID, Decimal

These types encode/decode automatically without needing strategy configuration:

```swift
struct Document: Codable {
  let url: URL
  let id: UUID
  let price: Decimal
}

let doc = Document(
  url: URL(string: "https://example.com")!,
  id: UUID(),
  price: Decimal(string: "19.99")!)

let encoder = OrderedJSONEncoder()
let json = try encoder.encode(doc)
// URL → absolute string, UUID → uuid string, Decimal → JSON string (preserves precision)

let decoder = OrderedJSONDecoder()
let back = try decoder.decode(Document.self, from: json)
```

> **Decimal strategies**: By default `Decimal` encodes as a JSON string (preserving full precision).
> Use `encoder.decimalEncodingStrategy = .asNumber` / `decoder.decimalDecodingStrategy = .asNumber`
> to match Foundation's `JSONEncoder` behavior (JSON number).

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

### JSONWithUnknownKeys<T>

Capture unknown JSON keys while decoding known fields into a strongly-typed struct — similar to `#[serde(flatten)]` in serde.

```swift
struct Person: Codable {
  let name: String
  let age: Int
}

let data = Data(#"""
  {"name": "Alice", "age": 30, "color": "blue", "city": "NYC"}
  """#.utf8)

let wrapped = try OrderedJSONDecoder().decode(
  JSONWithUnknownKeys<Person>.self, from: data)

// Known fields
wrapped.value.name  // "Alice"
wrapped.value.age   // 30

// Unknown keys captured
wrapped.unknownKeys["color"]  // .string("blue")
wrapped.unknownKeys["city"]   // .string("NYC")
```

`JSONWithUnknownKeys` works by:
1. Decoding all keys as raw `JSON` values
2. Decoding `T` while tracking which keys it accesses via `decode(...)` and `decodeNil(forKey:)`
3. Treating unaccessed keys as unknown keys

**Known limitations:**
- All key access methods (`decode(...)`, `decodeNil(forKey:)`, and `contains(_:)`) mark keys as "accessed". This prevents `decodeIfPresent` probes from leaking into unknown keys. Use `decodeIfPresent` for optional fields rather than `contains` + `decodeNil`.
- `T` must encode/decode as a keyed object; single-value and unkeyed containers are not supported
- Unknown keys must be a JSON object when encoding; non-object values throw `EncodingError.invalidValue`

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

### Generic get<T>()

> **Removed.** Use individual `require*()` methods directly. See [Throwing Accessors](#throwing-accessors) above.

### Optional Value Accessors

For non-throwing optional access, `JSON` provides computed properties that return `nil` on type mismatch:

```swift
let json = JSON.parse(#"{"name": "Alice", "count": 42, "pi": 3.14, "ok": true}"#)

json["name"]?.stringValue   // "Alice" — String?
json["count"]?.intValue     // 42 — Int64?
json["pi"]?.doubleValue      // 3.14 — Double?
json["ok"]?.boolValue       // true — Bool?
json["count"]?.numberValue  // .integer(42) — JSONNumber?

// For floats that are clean integers, intValue works:
json["count"]?.intValue     // 42 (Int64)

// For integers widened to Double:
json["count"]?.doubleValue   // 42.0 (Double)
```

| Property | Accepts | Returns | Returns nil if |
|----------|---------|---------|----------------|
| `stringValue` | `.string` | `String?` | Not a string |
| `intValue` | `.integer` or `.float` (clean integer) | `Int64?` | Not a number, or fractional float |
| `doubleValue` | `.float` or `.integer` (widening) | `Double?` | Not a number |
| `boolValue` | `.boolean` | `Bool?` | Not a boolean |
| `numberValue` | `.integer` or `.float` | `JSONNumber?` | Not a number |

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
let jsonString = json.dump()
// {"name":"Alice","age":30}

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
- **Flatten round-trip**: `flatten()` followed by `unflatten()` returns the original value. Empty containers become `null` after round-trip — avoid flattening if you need to preserve empty arrays/objects.
- **Choose access pattern**: Use `[]` for optional access, `at()` for throwing access, `value()` for default-value access.
- **Builder vs factory**: Use builders for complex deeply nested structures; use factory methods/inits for simple literals.
- **Schema validation**: Use `isValid()` for simple boolean checks, `validating()` to collect all errors, `validate()` to throw on first error.
- **Concurrency**: `JSON` is a value type — pass it freely across actors and tasks without locks.
