import OrderedCollections

extension JSON {
  /// Encodes a `Decodable`-conforming type into a `JSON` value.
  ///
  /// Uses `OrderedJSONEncoder` internally, preserving key declaration order.
  ///
  /// - Parameter value: The value to encode.
  /// - Returns: A `JSON` value representing the encoded data.
  /// - Throws: `EncodingError` if the value cannot be encoded.
  ///
  /// ## Example
  ///
  /// ```swift
  /// struct Person: Codable {
  ///   let name: String
  ///   let age: Int
  /// }
  ///
  /// let person = Person(name: "Alice", age: 30)
  /// let json = try JSON.encode(person)
  /// // json["name"] == "Alice"
  /// // json["age"] == 30
  /// ```
  public static func encode<T: Encodable>(_ value: T) throws -> JSON {
    let encoder = OrderedJSONEncoder()
    return try encoder.encode(value)
  }
}
