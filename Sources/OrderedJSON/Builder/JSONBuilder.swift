import OrderedCollections

extension JSON {

  // MARK: - Object Builder

  /// A fluent builder for constructing JSON objects with ordered key-value pairs.
  ///
  /// Use `set(_:value:)` to add key-value pairs, then call `build()` to produce the
  /// final `JSON` value. All `set` methods return `Self` for method chaining.
  ///
  /// ```swift
  /// let json = JSON.ObjectBuilder()
  ///   .set("name", "Alice")
  ///   .set("age", 30)
  ///   .set("active", true)
  ///   .set("pi", 3.14)
  ///   .build()
  /// // → {"name":"Alice","age":30,"active":true,"pi":3.14}
  /// ```
  ///
  /// Nested objects and arrays are supported via the builder's `build()`:
  ///
  /// ```swift
  /// let nested = JSON.ObjectBuilder()
  ///   .set("name", "Alice")
  ///   .set("address", JSON.ObjectBuilder()
  ///     .set("city", "NYC")
  ///     .set("zip", "10001")
  ///     .build())
  ///   .set("tags", JSON.ArrayBuilder()
  ///     .add("admin")
  ///     .add("user")
  ///     .build())
  ///   .build()
  /// ```
  public final class ObjectBuilder {
    private var dict: OrderedDictionary<String, JSON> = [:]

    public init() {}

    /// Sets the value for `key` to a `JSON` value.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: JSON) -> Self {
      dict[key] = value
      return self
    }

    /// Sets the value for `key` to a JSON string.
    @discardableResult
    public func set(_ key: String, _ value: String) -> Self {
      dict[key] = .string(value)
      return self
    }

    /// Sets the value for `key` to a JSON boolean.
    @discardableResult
    public func set(_ key: String, _ value: Bool) -> Self {
      dict[key] = .boolean(value)
      return self
    }

    /// Sets the value for `key` to a JSON integer.
    @discardableResult
    public func set(_ key: String, _ value: Int) -> Self {
      dict[key] = .number(.integer(Int64(value)))
      return self
    }

    /// Sets the value for `key` to a JSON integer.
    @discardableResult
    public func set(_ key: String, _ value: Int64) -> Self {
      dict[key] = .number(.integer(value))
      return self
    }

    /// Sets the value for `key` to a JSON float.
    @discardableResult
    public func set(_ key: String, _ value: Double) -> Self {
      dict[key] = .number(.float(value))
      return self
    }

    /// Sets the value for `key` to a JSON float.
    @discardableResult
    public func set(_ key: String, _ value: Float) -> Self {
      dict[key] = .number(.float(Double(value)))
      return self
    }

    /// Sets the value for `key` to a JSON array.
    @discardableResult
    public func set(_ key: String, _ value: [JSON]) -> Self {
      dict[key] = .array(value)
      return self
    }

    /// Sets the value for `key` to a JSON object built from `value`.
    @discardableResult
    public func set(_ key: String, _ value: JSON.ObjectBuilder) -> Self {
      dict[key] = value.build()
      return self
    }

    /// Removes the value for `key` from the builder.
    @discardableResult
    public func remove(_ key: String) -> Self {
      dict.removeValue(forKey: key)
      return self
    }

    /// Returns the current number of key-value pairs in the builder.
    public var count: Int { dict.count }

    /// Builds and returns the final JSON object value.
    public func build() -> JSON {
      return .object(dict)
    }

    /// Builds the JSON object and returns the serialized JSON string.
    public func buildString(indent: Int = -1) -> String {
      return build().dump(indent: indent)
    }
  }

  // MARK: - Array Builder

  /// A fluent builder for constructing JSON arrays with ordered elements.
  ///
  /// Use `add(_:)` to append elements, then call `build()` to produce the final `JSON`
  /// value. All `add` methods return `Self` for method chaining.
  ///
  /// ```swift
  /// let json = JSON.ArrayBuilder()
  ///   .add("a")
  ///   .add(42)
  ///   .add(true)
  ///   .add(3.14)
  ///   .build()
  /// // → ["a",42,true,3.14]
  /// ```
  ///
  /// Nested objects and arrays:
  /// ```swift
  /// let nested = JSON.ArrayBuilder()
  ///   .add(JSON.ObjectBuilder()
  ///     .set("x", 1)
  ///     .build())
  ///   .add(JSON.ArrayBuilder()
  ///     .add("inner")
  ///     .build())
  ///   .build()
  /// ```
  public final class ArrayBuilder {
    private var elements: [JSON] = []

    public init() {}

    /// Appends a `JSON` value to the array.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: JSON) -> Self {
      elements.append(value)
      return self
    }

    /// Appends a JSON string.
    @discardableResult
    public func add(_ value: String) -> Self {
      elements.append(.string(value))
      return self
    }

    /// Appends a JSON boolean.
    @discardableResult
    public func add(_ value: Bool) -> Self {
      elements.append(.boolean(value))
      return self
    }

    /// Appends a JSON integer.
    @discardableResult
    public func add(_ value: Int) -> Self {
      elements.append(.number(.integer(Int64(value))))
      return self
    }

    /// Appends a JSON integer.
    @discardableResult
    public func add(_ value: Int64) -> Self {
      elements.append(.number(.integer(value)))
      return self
    }

    /// Appends a JSON float.
    @discardableResult
    public func add(_ value: Double) -> Self {
      elements.append(.number(.float(value)))
      return self
    }

    /// Appends a JSON float.
    @discardableResult
    public func add(_ value: Float) -> Self {
      elements.append(.number(.float(Double(value))))
      return self
    }

    /// Appends a JSON array.
    @discardableResult
    public func add(_ value: [JSON]) -> Self {
      elements.append(.array(value))
      return self
    }

    /// Appends a JSON object built from `value`.
    @discardableResult
    public func add(_ value: JSON.ObjectBuilder) -> Self {
      elements.append(value.build())
      return self
    }

    /// Appends a JSON array built from `value`.
    @discardableResult
    public func add(_ value: JSON.ArrayBuilder) -> Self {
      elements.append(value.build())
      return self
    }

    /// Returns the current number of elements in the builder.
    public var count: Int { elements.count }

    /// Builds and returns the final JSON array value.
    public func build() -> JSON {
      return .array(elements)
    }

    /// Builds the JSON array and returns the serialized JSON string.
    public func buildString(indent: Int = -1) -> String {
      return build().dump(indent: indent)
    }
  }
}
