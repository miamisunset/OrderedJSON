import OrderedCollections

// MARK: - JSON Encodable

extension JSON: Encodable {
  /// Encodes this JSON value into the given encoder.
  ///
  /// Objects use keyed containers with key order preserved.
  /// Arrays use unkeyed containers in element order.
  /// Scalars use single-value containers.
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

// MARK: - JSON Decodable

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
  /// keys are returned in insertion order.
  public init(from decoder: Decoder) throws {
    // Track the first shape-specific error for better fallback diagnostics.
    var lastKeyedError: DecodingError?
    var lastArrayError: DecodingError?

    // First try keyed container (JSON object)
    do {
      let container = try decoder.container(keyedBy: JSONCodingKey.self)
      var dict = OrderedDictionary<String, JSON>()
      if container.allKeys.count > 0 {
        for key in container.allKeys {
          let value = try container.decode(JSON.self, forKey: key)
          dict[key.stringValue] = value
        }
      }
      self = .object(dict)
      return
    } catch let keyedError as DecodingError {
      lastKeyedError = keyedError
    } catch {
      throw error
    }

    // Then try unkeyed container (JSON array)
    do {
      var container = try decoder.unkeyedContainer()
      var elements: [JSON] = []
      if let count = container.count {
        elements.reserveCapacity(count)
      }
      while !container.isAtEnd {
        let element = try container.decode(JSON.self)
        elements.append(element)
      }
      self = .array(elements)
      return
    } catch let arrayError as DecodingError {
      lastArrayError = arrayError
    } catch {
      throw error
    }

    // Fall back to single-value container (string, number, boolean, null)
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let s = try? container.decode(String.self) {
      self = .string(s)
    } else if let i = try? container.decode(Int64.self) {
      self = .number(.integer(i))
    } else if let d = try? container.decode(Double.self) {
      // Normalize clean integer doubles (e.g., 1.0 → 1)
      // Use Int64(exactly:) to avoid overflow: Double(Int64.max) rounds up
      // beyond Int64.max due to floating-point precision.
      if let i = Int64(exactly: d), d == d.rounded(.towardZero) {
        self = .number(.integer(i))
      } else {
        self = .number(.float(d))
      }
    } else if let b = try? container.decode(Bool.self) {
      self = .boolean(b)
    } else {
      let ctx = DecodingError.Context(
        codingPath: decoder.codingPath,
        debugDescription:
          "Unsupported JSON value type: expected string, number, boolean, or null",
        underlyingError: lastKeyedError ?? lastArrayError)
      throw DecodingError.dataCorrupted(ctx)
    }
  }
}
