# OrderedJSON

A Swift library that preserves JSON key order (deeply nested) with a `flatten` feature similar to `serde_json::Value::flatten()`.

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

// Objects (keys preserve insertion order)
let objectVal = JSONValue.object([
  "name": .string("Alice"),
  "age":  .number(.integer(30)),
  "city": .string("New York"),
])
```

## Flatten

The `flatten()` method produces an array of `(key: String, value: JSONValue)` tuples with dot-separated paths:

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
// (key: "a",     value: "x")
// (key: "b.c",   value: "deep")
// (key: "d[0]",  value: 1)
// (key: "d[1].e", value: "nested")
```

### Flatten scalars

Scalars return a single entry with an empty key:

```swift
import OrderedJSON

let scalar = JSONValue.string("hello")
let result = scalar.flatten()
// result[0].key   == ""
// result[0].value == JSONValue.string("hello")
```

### Flatten arrays

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

### Flatten empty objects

Empty objects produce an empty result:

```swift
import OrderedJSON

let empty = JSONValue.object([:])
let result = empty.flatten()
// result.isEmpty == true
```

## Encoding & Decoding

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

### Numeric type preservation

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
let data = jsonString.data(using: .utf8)!
let decoder = JSONDecoder()
let value = try decoder.decode(JSONValue.self, from: data)

guard case .object(let dict) = value else { return }
// dict["int"]   == .number(.integer(42))
// dict["float"] == .number(.float(3.14))
```

### Encoding null, booleans, strings, numbers

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

## Key Order Preservation

`OrderedJSON` guarantees that keys in objects retain their insertion order through encode-decode round-trips. This is accomplished by encoding objects as alternating key-value pairs rather than standard JSON objects (which do not guarantee key order in most JSON libraries).

```swift
import OrderedJSON
import Foundation

let encoder = JSONEncoder()
let decoder = JSONDecoder()

// Keys are inserted in a specific order
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

## Best Practices

- Use `JSONValue.object([:])` for empty objects rather than `JSONValue.object(OrderedJSONObject())`.
- For numeric values, prefer `.integer(Int64)` for whole numbers and `.float(Double)` for decimals to preserve type.
- The `flatten()` result is an array of tuples; iterate over it with `for (key, value) in result`.
- When decoding JSON from untrusted sources, wrap in `do {} catch {}` as usual with Foundation's `JSONDecoder`.
- `JSONValue` is `Hashable` and `Sendable`, making it safe to use in collections and across concurrency domains.
