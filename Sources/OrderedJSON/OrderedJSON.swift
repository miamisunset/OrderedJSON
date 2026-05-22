import OrderedCollections

/// A JSON number that preserves whether the original value was an integer or a float.
package enum JSONNumber: Hashable, Sendable, Codable {
  case integer(Int64)
  case float(Double)

  package func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .integer(let value): try container.encode(value)
    case .float(let value): try container.encode(value)
    }
  }

  package init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if let intValue = try? container.decode(Int64.self) {
      self = .integer(intValue)
    } else {
      self = .float(try container.decode(Double.self))
    }
  }
}

/// An ordered dictionary typealias used for JSON object representations.
package typealias OrderedJSONObject = OrderedDictionary<String, JSONValue>

/// A JSON value that preserves key order for objects.
package enum JSONValue: Hashable, Sendable, Codable {
  case object(OrderedJSONObject)
  case array([JSONValue])
  case string(String)
  case number(JSONNumber)
  case boolean(Bool)
  case null

  package func flatten() -> [(key: String, value: JSONValue)] {
    flattenInternal(prefix: "")
  }

  private func flattenInternal(prefix: String) -> [(key: String, value: JSONValue)] {
    switch self {
    case .null, .boolean, .number, .string:
      return [(prefix, self)]
    case .array(let elements):
      var result: [(String, JSONValue)] = []
      for (index, element) in elements.enumerated() {
        let key = prefix.isEmpty ? "[\(index)]" : "\(prefix)[\(index)]"
        result.append(contentsOf: element.flattenInternal(prefix: key))
      }
      return result
    case .object(let dict):
      var result: [(String, JSONValue)] = []
      for (key, value) in dict {
        let fullKey = prefix.isEmpty ? key : "\(prefix).\(key)"
        result.append(contentsOf: value.flattenInternal(prefix: fullKey))
      }
      return result
    }
  }

  package func encode(to encoder: any Encoder) throws {
    switch self {
    case .object(let dict):
      // Encode as alternating key-value pairs in an unkeyed container
      // to preserve key ordering (JSON objects don't guarantee order).
      var container = encoder.unkeyedContainer()
      for (key, value) in dict {
        try container.encode(key)
        try container.encode(value)
      }
    case .array(let array):
      var container = encoder.singleValueContainer()
      try container.encode(array)
    case .string(let string):
      var container = encoder.singleValueContainer()
      try container.encode(string)
    case .number(let number):
      var container = encoder.singleValueContainer()
      try container.encode(number)
    case .boolean(let bool):
      var container = encoder.singleValueContainer()
      try container.encode(bool)
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    }
  }

  package init(from decoder: any Decoder) throws {
    // Try keyed container (standard JSON object format).
    if let keyedContainer = try? decoder.container(keyedBy: JSONCodingKey.self) {
      var object = OrderedJSONObject()
      for key in keyedContainer.allKeys {
        object[key.stringValue] = try keyedContainer.decode(JSONValue.self, forKey: key)
      }
      self = .object(object)
      return
    }

    // Try unkeyed container — could be an object (alternating key-value
    // pairs from our custom encoding) or an array (sequential elements).
    if var container = try? decoder.unkeyedContainer() {
      var elements: [JSONValue] = []
      while !container.isAtEnd {
        elements.append(try container.decode(JSONValue.self))
      }
      // Determine if this is an object (alternating key-value pairs):
      // even count, and every even-indexed element is a string.
      if elements.count % 2 == 0, !elements.isEmpty {
        var isObject = true
        for i in stride(from: 0, to: elements.count, by: 2) {
          if case .string = elements[i] { continue }
          isObject = false
          break
        }
        if isObject {
          var object = OrderedJSONObject()
          for i in stride(from: 0, to: elements.count, by: 2) {
            guard case .string(let key) = elements[i] else { break }
            object[key] = elements[i + 1]
          }
          self = .object(object)
          return
        }
      }
      self = .array(elements)
      return
    }

    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
      return
    }
    if let string = try? container.decode(String.self) {
      self = .string(string)
      return
    }
    if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
      return
    }
    if let number = try? container.decode(JSONNumber.self) {
      self = .number(number)
      return
    }

    throw DecodingError.typeMismatch(
      JSONValue.self,
      DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription: "JSON value could not be decoded"
      )
    )
  }
}

package struct JSONCodingKey: CodingKey {
  package var stringValue: String
  package init?(stringValue: String) { self.stringValue = stringValue }
  package var intValue: Int? { nil }
  package init?(intValue: Int) { nil }
}
