import OrderedCollections

extension JSON: Encodable {
  /// Encodes this JSON value into the given encoder.
  ///
  /// - Objects: encoded as a keyed container with key order preserved from the
  ///   underlying `OrderedDictionary`.
  /// - Arrays: encoded as an unkeyed container in element order.
  /// - Scalars: encoded as a single value container.
  public func encode(to encoder: Encoder) throws {
    switch storage {
    case .object(let dict):
      var container = encoder.container(keyedBy: JSONCodingKey.self)
      for (key, value) in dict {
        try container.encode(value, forKey: JSONCodingKey(stringValue: key))
      }
    case .array(let elements):
      var container = encoder.unkeyedContainer()
      for element in elements {
        try container.encode(element)
      }
    case .string(let s):
      var container = encoder.singleValueContainer()
      try container.encode(s)
    case .number(let num):
      var container = encoder.singleValueContainer()
      switch num {
      case .integer(let i): try container.encode(i)
      case .float(let d): try container.encode(d)
      }
    case .boolean(let b):
      var container = encoder.singleValueContainer()
      try container.encode(b)
    case .null:
      var container = encoder.singleValueContainer()
      try container.encodeNil()
    }
  }
}

extension JSON: Decodable {
  /// Decodes a JSON value from the given decoder.
  ///
  /// Attempts to decode in this order:
  /// 1. Keyed container (JSON object)
  /// 2. Unkeyed container (JSON array)
  /// 3. Single value container (string, number, boolean, null)
  ///
  /// When decoding objects, key order is preserved by iterating the
  /// container's keys in their natural order. For `OrderedJSONDecoder`,
  /// keys are returned in insertion order. For Foundation's `JSONDecoder`,
  /// keys are sorted alphabetically by default — use `OrderedJSONDecoder`
  /// for order-preserving decoding.
  public init(from decoder: Decoder) throws {
    if let container = try? decoder.container(keyedBy: JSONCodingKey.self) {
      var dict = OrderedDictionary<String, JSON>()
      if container.allKeys.count > 0 {
        // Use allKeys to iterate in the container's reported order.
        // OrderedJSONDecoder returns keys in insertion order.
        for key in container.allKeys {
          let value = try container.decode(JSON.self, forKey: key)
          dict[key.stringValue] = value
        }
      }
      self = .object(dict)
    } else if var container = try? decoder.unkeyedContainer() {
      var elements: [JSON] = []
      if let count = container.count {
        elements.reserveCapacity(count)
      }
      while !container.isAtEnd {
        let element = try container.decode(JSON.self)
        elements.append(element)
      }
      self = .array(elements)
    } else {
      let container = try decoder.singleValueContainer()
      if container.decodeNil() {
        self = .null
      } else if let s = try? container.decode(String.self) {
        self = .string(s)
      } else if let i = try? container.decode(Int64.self) {
        self = .number(.integer(i))
      } else if let d = try? container.decode(Double.self) {
        // Normalize clean integer doubles (e.g., 1.0 → 1)
        if d == d.rounded(.towardZero) && d >= Double(Int64.min) && d <= Double(Int64.max) {
          self = .number(.integer(Int64(d)))
        } else {
          self = .number(.float(d))
        }
      } else if let b = try? container.decode(Bool.self) {
        self = .boolean(b)
      } else {
        throw DecodingError.dataCorrupted(
          DecodingError.Context(
            codingPath: decoder.codingPath,
            debugDescription:
              "Unsupported JSON value type: expected string, number, boolean, or null"))
      }
    }
  }
}
