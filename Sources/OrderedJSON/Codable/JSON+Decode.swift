import Foundation
import OrderedCollections

extension JSON {
  // MARK: - Convenience decode methods

  /// Decodes a `Decodable` type from a `JSON` value.
  ///
  /// Uses `OrderedJSONDecoder` internally, preserving key order.
  ///
  /// - Parameters:
  ///   - type: The type to decode.
  ///   - json: A `JSON` value.
  /// - Returns: A decoded value of the requested type.
  /// - Throws: `DecodingError` if the value cannot be decoded.
  ///
  /// ## Example
  ///
  /// ```swift
  /// struct Person: Decodable {
  ///   let name: String
  ///   let age: Int
  /// }
  ///
  /// let json = JSON.object([
  ///   "name": .string("Alice"),
  ///   "age":  .number(.integer(30))
  /// ])
  /// let person = try JSON.decode(Person.self, from: json)
  /// ```
  public static func decode<T: Decodable>(
    _ type: T.Type,
    from json: JSON
  ) throws -> T {
    let decoder = OrderedJSONDecoder()
    return try decoder.decode(type, from: json)
  }

  /// Decodes a `Decodable` type from a JSON string.
  ///
  /// Combines parsing and decoding in one step:
  /// 1. Parses the string as JSON
  /// 2. Decodes the requested type using `OrderedJSONDecoder`
  ///
  /// - Parameters:
  ///   - type: The type to decode.
  ///   - string: A JSON string.
  ///   - options: Parser configuration.
  /// - Returns: A decoded value of the requested type.
  /// - Throws: `JSONParseError` for invalid JSON, or decoding errors.
  public static func decode<T: Decodable>(
    _ type: T.Type,
    from string: String,
    options: ParserOptions = .default
  ) throws -> T {
    let json = try JSON.parse(string, options: options)
    let decoder = OrderedJSONDecoder()
    return try decoder.decode(type, from: json)
  }

  /// Decodes a `Decodable` type from JSON data.
  ///
  /// Combines parsing and decoding in one step:
  /// 1. Parses the data as JSON
  /// 2. Decodes the requested type using `OrderedJSONDecoder`
  ///
  /// - Parameters:
  ///   - type: The type to decode.
  ///   - data: UTF-8 encoded JSON data.
  ///   - options: Parser configuration.
  /// - Returns: A decoded value of the requested type.
  /// - Throws: `JSONParseError` for invalid JSON, or decoding errors.
  public static func decode<T: Decodable>(
    _ type: T.Type,
    from data: Data,
    options: ParserOptions = .default
  ) throws -> T {
    let json = try JSON.parse(data, options: options)
    let decoder = OrderedJSONDecoder()
    return try decoder.decode(type, from: json)
  }
}
