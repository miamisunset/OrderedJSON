import Foundation
import OrderedCollections

/// A JSON decoder that produces `JSON` values with preserved key order.
///
/// - Important: Set `userInfo` before calling `decode`;
///   mutations after the call do not propagate to nested containers.
public struct OrderedJSONDecoder {
  /// The user info dictionary for the decoder, propagated to all nested decoders.
  public var userInfo: [CodingUserInfoKey: Any]

  /// The strategy to use for decoding `Date` values.
  public var dateDecodingStrategy: DateDecodingStrategy = .deferredToDate

  /// The strategy to use for decoding `Data` values.
  public var dataDecodingStrategy: DataDecodingStrategy = .base64

  /// The strategy to use for decoding `Decimal` values.
  public var decimalDecodingStrategy: DecimalDecodingStrategy = .asString

  /// Creates a new decoder with default options.
  public init() {
    userInfo = [:]
  }

  public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
    let json = try JSON.parse(data)
    return try decode(type, from: json)
  }

  public func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
    let json = try JSON.parse(string)
    return try decode(type, from: json)
  }

  public func decode<T: Decodable>(_: T.Type, from json: JSON) throws -> T {
    let impl = _JSONDecodeImpl(
      json: json,
      userInfo: userInfo,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try T(from: impl)
  }
}

// MARK: - Decoding strategies

/// Strategy for decoding `Date` values.
public enum DateDecodingStrategy {
  /// Decode the `Date` using its `Decodable` implementation (default).
  case deferredToDate
  /// Decode as a Double representing seconds since 1970-01-01.
  case secondsSince1970
  /// Decode as a Double representing milliseconds since 1970-01-01.
  case millisecondsSince1970
  /// Decode as an ISO-8601 string using `ISO8601DateFormatter`.
  case iso8601
  /// Decode using a `DateFormatter`.
  case formatted(DateFormatter)
  /// Decode using a custom closure.
  case custom((JSON, Decoder) throws -> Date)
}

/// Strategy for decoding `Data` values.
public enum DataDecodingStrategy {
  /// Decode the `Data` using its `Decodable` implementation.
  case deferredToData
  /// Decode as a Base64-encoded string (default).
  case base64
  /// Decode using a custom closure.
  case custom((JSON, Decoder) throws -> Data)
}

/// Strategy for decoding `Decimal` values.
public enum DecimalDecodingStrategy {
  /// Decode the `Decimal` from a JSON string (default, preserves precision).
  case asString
  /// Decode the `Decimal` from a JSON number.
  case asNumber
}

// MARK: - Internal decoder implementation

/// The concrete `Decoder` implementation. Wraps a `JSON` value and propagates
/// decoding strategies and user info to all nested containers.
final class _JSONDecodeImpl: Decoder {
  let json: JSON
  let codingPath: [CodingKey]
  var userInfo: [CodingUserInfoKey: Any] {
    _userInfo
  }

  private let _userInfo: [CodingUserInfoKey: Any]

  /// Strategies propagated from `OrderedJSONDecoder`.
  let dateDecodingStrategy: DateDecodingStrategy
  let dataDecodingStrategy: DataDecodingStrategy
  let decimalDecodingStrategy: DecimalDecodingStrategy

  /// Creates a decoder impl for the given JSON value.
  /// - Parameters:
  ///   - json: The JSON value to decode from.
  ///   - userInfo: User info dictionary propagated to nested decoders.
  ///   - codingPath: The coding path for the current decoding context.
  ///   - dateDecodingStrategy: Strategy for decoding `Date` values.
  ///   - dataDecodingStrategy: Strategy for decoding `Data` values.
  ///   - decimalDecodingStrategy: Strategy for decoding `Decimal` values.
  init(
    json: JSON,
    userInfo: [CodingUserInfoKey: Any] = [:],
    codingPath: [CodingKey] = [],
    dateDecodingStrategy: DateDecodingStrategy = .deferredToDate,
    dataDecodingStrategy: DataDecodingStrategy = .base64,
    decimalDecodingStrategy: DecimalDecodingStrategy = .asString
  ) {
    self.json = json
    _userInfo = userInfo
    self.codingPath = codingPath
    self.dateDecodingStrategy = dateDecodingStrategy
    self.dataDecodingStrategy = dataDecodingStrategy
    self.decimalDecodingStrategy = decimalDecodingStrategy
  }

  func container<Key: CodingKey>(keyedBy _: Key.Type) throws -> KeyedDecodingContainer<Key> {
    guard case .object(let dict) = json.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a JSON object"
        )
      )
    }
    return KeyedDecodingContainer(
      _JSONKeyedDecodingContainer<Key>(
        dictionary: dict, impl: self, pathPrefix: codingPath
      )
    )
  }

  func unkeyedContainer() throws -> UnkeyedDecodingContainer {
    guard case .array(let elements) = json.storage else {
      throw DecodingError.typeMismatch(
        JSON.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a JSON array"
        )
      )
    }
    return _JSONUnkeyedDecodingContainer(
      elements: elements, impl: self, pathPrefix: codingPath
    )
  }

  func singleValueContainer() throws -> SingleValueDecodingContainer {
    _JSONSingleValueDecodingContainer(json: json, impl: self, pathPrefix: codingPath)
  }
}

// MARK: - Foundation type decoding helpers

/// Wraps a JSONError thrown by a require*() call into DecodingError.dataCorrupted.
package func wrapJSONError<T>(
  _ expression: () throws -> T, codingPath: [CodingKey],
  debugDescription: String? = nil
) throws -> T {
  do {
    return try expression()
  } catch let error as JSONError {
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription: debugDescription ?? String(describing: error)
      )
    )
  }
}

package func decodeDate(
  from json: JSON, with strategy: DateDecodingStrategy, codingPath: [CodingKey],
  dateDecodingStrategy: DateDecodingStrategy,
  dataDecodingStrategy: DataDecodingStrategy,
  decimalDecodingStrategy: DecimalDecodingStrategy
) throws -> Date {
  switch strategy {
  case .deferredToDate:
    // Fall through to Date's own Decodable implementation
    let impl = _JSONDecodeImpl(
      json: json, codingPath: codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try Date(from: impl)
  case .secondsSince1970:
    return try Date(
      timeIntervalSince1970: wrapJSONError({ try json.requireDouble() }, codingPath: codingPath))
  case .millisecondsSince1970:
    return try Date(
      timeIntervalSince1970: wrapJSONError({ try json.requireDouble() }, codingPath: codingPath)
        / 1000.0)
  case .iso8601:
    let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: string) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Invalid ISO8601 date: \(string)"
        )
      )
    }
    return date
  case .formatted(let formatter):
    let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
    guard let date = formatter.date(from: string) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Invalid date format: \(string)"
        )
      )
    }
    return date
  case .custom(let closure):
    let impl = _JSONDecodeImpl(
      json: json, codingPath: codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try closure(json, impl)
  }
}

package func decodeData(
  from json: JSON, with strategy: DataDecodingStrategy, codingPath: [CodingKey],
  dateDecodingStrategy: DateDecodingStrategy,
  dataDecodingStrategy: DataDecodingStrategy,
  decimalDecodingStrategy: DecimalDecodingStrategy
) throws -> Data {
  switch strategy {
  case .deferredToData:
    // Fall through to Data's own Decodable implementation
    let impl = _JSONDecodeImpl(
      json: json, codingPath: codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try Data(from: impl)
  case .base64:
    let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
    guard let data = Data(base64Encoded: string) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Invalid base64 data"
        )
      )
    }
    return data
  case .custom(let closure):
    let impl = _JSONDecodeImpl(
      json: json, codingPath: codingPath,
      dateDecodingStrategy: dateDecodingStrategy,
      dataDecodingStrategy: dataDecodingStrategy,
      decimalDecodingStrategy: decimalDecodingStrategy
    )
    return try closure(json, impl)
  }
}

package func decodeDecimal(
  from json: JSON, with strategy: DecimalDecodingStrategy, codingPath: [CodingKey]
) throws -> Decimal {
  switch strategy {
  case .asString:
    let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
    guard let decimal = Decimal(string: string) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Invalid Decimal string: \(string)"
        )
      )
    }
    return decimal
  case .asNumber:
    switch json.storage {
    case .number(.integer(let i)):
      return Decimal(i)
    case .number(.float(let d)):
      return Decimal(Double(d))
    default:
      throw DecodingError.typeMismatch(
        Decimal.self,
        DecodingError.Context(
          codingPath: codingPath,
          debugDescription: "Expected a JSON number for Decimal decoding"
        )
      )
    }
  }
}

package func decodeURL(
  from json: JSON, codingPath: [CodingKey]
) throws -> URL {
  let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
  guard let url = URL(string: string) else {
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription: "Invalid URL string: \(string)"
      )
    )
  }
  return url
}

package func decodeUUID(
  from json: JSON, codingPath: [CodingKey]
) throws -> UUID {
  let string = try wrapJSONError({ try json.requireString() }, codingPath: codingPath)
  guard let uuid = UUID(uuidString: string) else {
    throw DecodingError.dataCorrupted(
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription: "Invalid UUID string: \(string)"
      )
    )
  }
  return uuid
}

// MARK: - JSONError → DecodingError wrapping

/// Wraps a JSONError thrown by a require*() call into DecodingError.typeMismatch
/// with a coding path that includes the current key.
package func decodeJSON<T>(_ expression: () throws -> T, codingPath: [CodingKey]) throws -> T {
  do {
    return try expression()
  } catch let error as JSONError {
    throw DecodingError.typeMismatch(
      T.self,
      DecodingError.Context(
        codingPath: codingPath,
        debugDescription: String(describing: error)
      )
    )
  }
}
