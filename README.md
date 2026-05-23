# OrderedJSON

A Swift library that preserves JSON key order (deeply nested) with a `flatten` feature similar to `serde_json::Value::flatten()`.

## Quick Start

```swift
import OrderedJSON

// Parse JSON with key order preserved
let json = """
  {"z": 1, "a": 2, "m": 3}
  """
let value = try JSONValue.parse(json)

// Keys are in the original order: ["z", "a", "m"]
guard case .object(let dict) = value else { return }
print(dict.keys) // ["z", "a", "m"]

// Flatten nested JSON into dotted paths
let flat = value.flatten()
for (key, value) in flat {
  print("\(key) => \(value)")
}
// Output:
// z => 1
// a => 2
// m => 3
```

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
    .package(url: "https://github.com/your-username/OrderedJSON.git", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "MyTarget",
      dependencies: ["OrderedJSON"]
    )
  ]
)
```

## Creating Values

`JSONValue` is an enum with cases for each JSON type:

```swift
import OrderedJSON

// Primitives
let stringVal = JSONValue.string("hello")
let numberVal = JSONValue.number(.integer(42))
let floatVal  = JSONValue.number(.float(3.14))
let boolVal   = JSONValue.boolean(true)
let nullVal   = JSONValue.null

// Arrays
let arrayVal = JSONValue.array([
  .string("a"),
  .number(.integer(1)),
  .boolean(false),
  .null,
])

// Objects — keys preserve insertion order
let objectVal = JSONValue.object([
  "name": .string("Alice"),
  "age":  .number(.integer(30)),
  "city": .string("New York"),
])
// objectVal's keys: ["name", "age", "city"]
```

## Parsing JSON from a String

Use `JSONValue.parse()` for order-preserving parsing from a raw string:

```swift
import OrderedJSON

let jsonString = """
  {"c": 3, "a": 1, "b": 2}
  """
let parsed = try JSONValue.parse(jsonString)
guard case .object(let dict) = parsed else { return }
print(dict.keys) // ["c", "a", "b"] — original order preserved
```

## Flatten (Dotted-Path Notation)

The `flatten()` method converts deeply nested JSON into flat key-value pairs using dot-separated paths for objects and `[index]` notation for arrays:

```swift
import OrderedJSON

let value = JSONValue.object([
  "a": .string("x"),
  "b": .object([
    "c": .string("deep")
  ]),
  "d": .array([
    .number(.integer(1)),
    .object([
      "e": .string("nested")
    ]),
  ]),
])

let flat = value.flatten()
// Returns:
// (key: "a",      value: "x")
// (key: "b.c",    value: "deep")
// (key: "d[0]",   value: 1)
// (key: "d[1].e", value: "nested")
```

### Flatten Scalars

Scalar values (strings, numbers, booleans, null) produce a single entry with an empty key:

```swift
import OrderedJSON

let scalar = JSONValue.string("hello")
let result = scalar.flatten()
// result[0].key   == ""
// result[0].value == JSONValue.string("hello")
```

### Flatten Arrays

Array elements use `[index]` notation:

```swift
import OrderedJSON

let array = JSONValue.array([
  .string("a"),
  .number(.integer(2)),
  .boolean(true),
])
let flat = array.flatten()
// flat[0].key == "[0]"
// flat[1].key == "[1]"
// flat[2].key == "[2]"
```

### Flatten Empty Objects

Empty objects produce an empty result:

```swift
import OrderedJSON

let empty = JSONValue.object([:])
let result = empty.flatten()
// result.isEmpty == true
```

## Encoding & Decoding (Codable)

`JSONValue` conforms to `Codable` and works with `JSONEncoder` / `JSONDecoder`:

```swift
import OrderedJSON
import Foundation

let encoder = JSONEncoder()
let decoder = JSONDecoder()

// Encode a value
let original = JSONValue.object([
  "z": .number(.integer(1)),
  "a": .number(.integer(2)),
  "m": .number(.integer(3)),
])
let data = try encoder.encode(original)

// Decode back — key order is preserved
let decoded = try decoder.decode(JSONValue.self, from: data)
guard case .object(let dict) = decoded else { return }
// dict.keys == ["z", "a", "m"]
```

### Numeric Type Preservation

Integers and floats round-trip correctly:

```swift
import OrderedJSON
import Foundation

let jsonString = """
  {
      "int": 42,
      "float": 3.14
  }
  """
let data = Data(jsonString.utf8)
let decoder = JSONDecoder()
let value = try decoder.decode(JSONValue.self, from: data)

guard case .object(let dict) = value else { return }
// dict["int"]   == .number(.integer(42))
// dict["float"] == .number(.float(3.14))
```

### Encoding Null, Booleans, Strings, Numbers

```swift
import OrderedJSON
import Foundation

let encoder = JSONEncoder()
let decoder = JSONDecoder()

// Null
let nullData = try encoder.encode(JSONValue.null)
let decodedNull = try decoder.decode(JSONValue.self, from: nullData)
// decodedNull == JSONValue.null

// String
let stringData = try encoder.encode(JSONValue.string("hello"))
let decodedString = try decoder.decode(JSONValue.self, from: stringData)
// decodedString == JSONValue.string("hello")

// Number
let numberData = try encoder.encode(JSONValue.number(.integer(42)))
let decodedNumber = try decoder.decode(JSONValue.self, from: numberData)
// decodedNumber == JSONValue.number(.integer(42))

// Boolean
let boolData = try encoder.encode(JSONValue.boolean(true))
let decodedBool = try decoder.decode(JSONValue.self, from: boolData)
// decodedBool == JSONValue.boolean(true)
```

## How Key Order Preservation Works

`JSONValue` encodes objects as alternating key-value pairs rather than standard JSON objects. This is necessary because most JSON parsers discard key ordering when decoding keyed containers.

- **Encoding**: Objects become alternating `[key, value]` pairs in an unkeyed container
- **Decoding**: Supports both standard JSON objects (keyed containers) and alternating pairs
- **Result**: Keys retain insertion order through encode-decode round-trips

```swift
import OrderedJSON
import Foundation

let encoder = JSONEncoder()
let decoder = JSONDecoder()

let original = JSONValue.object([
  "z": .number(.integer(1)),
  "a": .number(.integer(2)),
  "m": .number(.integer(3)),
])

let data = try encoder.encode(original)
let decoded = try decoder.decode(JSONValue.self, from: data)

guard case .object(let dict) = decoded else { return }
let keys = Array(dict.keys)
// keys == ["z", "a", "m"]  — order is preserved
```

## Standard JSON Encoding & Decoding

Sometimes you need to encode/decode as plain JSON objects (not alternating pairs). Use `encodeStandard()` and `decode(as:)`:

```swift
import OrderedJSON
import Foundation

let value = JSONValue.object([
  "name": .string("Bob"),
  "age": .number(.integer(25)),
])

// Encode as standard JSON: {"name":"Bob","age":25}
let standardData = try value.encodeStandard()

// Decode a single value as a typed Codable type
guard case .object(let dict) = value else { return }
let name: String = try dict["name"]!.decode(as: String.self)
// name == "Bob"
```

## Extra Fields Capture (serde `#[serde(flatten)]` equivalent)

`OrderedJSON` provides helpers to capture unknown JSON fields into an `OrderedJSONObject`, similar to Rust's `#[serde(flatten)]` on a `HashMap<String, Value>`.

### Step-by-Step Pattern

1. Define a struct with known `CodingKeys` and an `extra` field of type `OrderedJSONObject`
2. In `init(from:)`: decode the full JSON as `JSONValue`, split known keys from extras
3. In `encode(to:)`: encode known fields and extras as alternating pairs

```swift
import OrderedJSON
import Foundation

struct User: Codable {
  let name: String
  let email: String
  let extra: OrderedJSONObject

  enum CodingKeys: String, CodingKey, CaseIterable {
    case name, email
  }

  init(from decoder: any Decoder) throws {
    let fullValue = try JSONValue(from: decoder)
    guard case .object(let dict) = fullValue else {
      throw DecodingError.typeMismatch(...)
    }
    let knownKeyStrings = Set(CodingKeys.allCases.map { $0.stringValue })
    let (known, extra) = splitExtraFields(from: dict, knownKeys: knownKeyStrings)
    let knownData = try JSONValue.object(known).encodeStandard()
    let base = try JSONDecoder().decode(UserBase.self, from: knownData)
    name = base.name
    email = base.email
    self.extra = extra
  }

  func encode(to encoder: any Encoder) throws {
    var unkeyed = encoder.unkeyedContainer()
    try unkeyed.encode(CodingKeys.name.stringValue)
    try unkeyed.encode(name)
    try unkeyed.encode(CodingKeys.email.stringValue)
    try unkeyed.encode(email)
    for (key, value) in extra {
      try unkeyed.encode(key)
      try unkeyed.encode(value)
    }
  }
}

// Helper base struct for known fields
private struct UserBase: Codable {
  let name: String
  let email: String
}
```

### Decoding with Extra Fields

When decoding `{"name": "Alice", "email": "a@b.com", "age": 30, "city": "NYC"}`:

```swift
let jsonString = """
  {"name": "Alice", "email": "a@b.com", "age": 30, "city": "NYC"}
  """
let data = Data(jsonString.utf8)
let decoder = JSONDecoder()
let user = try decoder.decode(User.self, from: data)
// user.name        == "Alice"
// user.email       == "a@b.com"
// user.extra.keys  == ["age", "city"]
// user.extra["age"]  == .number(.integer(30))
```

### Helper Functions

Three utilities support this pattern:

- **`encodeStandard()`** — encodes as standard JSON (keyed objects) for compatibility with `JSONDecoder`
- **`decode<T: Codable>(as:)`** — decodes a single `JSONValue` as any `Codable` type
- **`splitExtraFields(from:knownKeys:)`** — splits an `OrderedJSONObject` into known and extra key groups

```swift
let value = JSONValue.object([
  "name": .string("Bob"),
  "age": .number(.integer(25)),
])
let data = try value.encodeStandard()
// data -> {"name":"Bob","age":25}

guard case .object(let dict) = value else { return }
let name: String = try dict["name"]!.decode(as: String.self)
// name == "Bob"

let (known, extra) = splitExtraFields(from: dict, knownKeys: ["name"])
// known == ["name": "Bob"]
// extra == ["age": 25]
```

## Round-Trip: Parse → Modify → Encode (Exact Order)

The most common use case: parse JSON, update values, and encode back to standard JSON with the same key order:

```swift
import OrderedJSON

let input = """
  {"z": 1, "a": 2, "m": 3}
  """
let value = try JSONValue.parse(input)

// Modify values (key order is preserved in the dictionary)
guard case .object(var dict) = value else { return }
dict["a"] = .number(.integer(99))
let modified = JSONValue.object(dict)

// Encode back to standard JSON — same key order, updated values
let output = String(data: try modified.encodeStandard(), encoding: .utf8)!
// output == {"z":1,"a":99,"m":3}
```

**How it works:**
- `JSONValue.parse()` parses with order preservation using a recursive descent parser
- `OrderedDictionary` retains insertion order through modifications
- `encodeStandard()` serializes as standard JSON objects (not alternating pairs), preserving key order
- The result is a JSON string with identical key ordering as the input, but with updated values

## Best Practices

- **Empty objects**: Use `JSONValue.object([:])` rather than `JSONValue.object(OrderedJSONObject())`.
- **Numeric types**: Use `.integer(Int64)` for whole numbers and `.float(Double)` for decimals to preserve type information through encoding/decoding.
- **Flatten iteration**: The `flatten()` result is an array of tuples; iterate with `for (key, value) in result`.
- **Error handling**: Wrap decoding from untrusted sources in `do {} catch {}` as usual with Foundation's `JSONDecoder`.
- **Thread safety**: `JSONValue` is `Hashable` and `Sendable`, making it safe to use in collections and across concurrency domains.
- **Order preservation for standard JSON**: To preserve key order when decoding standard JSON, set `decoder.userInfo[.jsonData]` to the raw `Data` before calling `decode(JSONValue.self, from:)`. This triggers the order-preserving parser.
