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

## Standard JSON Encoding

Use `encodeStandard()` to serialize back to standard JSON:

```swift
import OrderedJSON
import Foundation

let value = JSONValue.object([
  "name": .string("Bob"),
  "age": .number(.integer(25)),
])

// Encode as standard JSON: {"name":"Bob","age":25}
let standardData = try value.encodeStandard()
```

## Extra Fields Capture (serde `#[serde(flatten)]` equivalent)

`OrderedJSON` provides helpers to capture unknown JSON fields into an `OrderedJSONObject`, similar to Rust's `#[serde(flatten)]` on a `HashMap<String, Value>`.

### Step-by-Step Pattern

1. Define a struct with known fields and an `extra` field of type `OrderedJSONObject`
2. In `init(from jsonData: Data)`: parse the full JSON as `JSONValue`, split known keys from extras
3. In `encode()`: merge known fields and extras and call `encodeStandard()`

```swift
import OrderedJSON
import Foundation

struct User {
  let name: String
  let email: String
  let extra: OrderedJSONObject

  init(from jsonData: Data) throws {
    let fullValue = try JSONValue.parse(String(data: jsonData, encoding: .utf8)!)
    guard case .object(let dict) = fullValue else {
      throw JSONError.expectedObject
    }
    let knownKeys: Set<String> = ["name", "email"]
    let (known, extra) = splitExtraFields(from: dict, knownKeys: knownKeys)
    let knownData = try JSONValue.object(known).encodeStandard()
    let base = try JSONDecoder().decode(UserBase.self, from: knownData)
    name = base.name
    email = base.email
    self.extra = extra
  }

  func encode() throws -> Data {
    var merged: OrderedJSONObject = [
      "name": .string(name),
      "email": .string(email),
    ]
    for (key, value) in extra {
      merged[key] = value
    }
    return try JSONValue.object(merged).encodeStandard()
  }
}

// Helper base struct for known fields
private struct UserBase: Decodable {
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
let user = try User(from: data)
// user.name        == "Alice"
// user.email       == "a@b.com"
// user.extra.keys  == ["age", "city"]
// user.extra["age"]  == .number(.integer(30))
```

### Helper Functions

Two utilities support this pattern:

- **`encodeStandard()`** — encodes as standard JSON (keyed objects)
- **`splitExtraFields(from:knownKeys:)`** — splits an `OrderedJSONObject` into known and extra key groups

```swift
let value = JSONValue.object([
  "name": .string("Bob"),
  "age": .number(.integer(25)),
])
let data = try value.encodeStandard()
// data -> {"name":"Bob","age":25}

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
- **Error handling**: Wrap parsing from untrusted sources in `do {} catch {}`.
- **Thread safety**: `JSONValue` is `Hashable` and `Sendable`, making it safe to use in collections and across concurrency domains.
- **Order preservation**: Use `JSONValue.parse()` for order-preserving parsing and `encodeStandard()` for serialization.
