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
  ///
  /// - Invariant: `build()` may be called multiple times; each call returns a
  ///   snapshot of the current state.
  /// - Thread safety: Classes enable fluent chaining without copy-on-write overhead
  ///   on every chained call. This builder is designed for single-threaded use;
  ///   it is not safe to share across concurrency boundaries. Marked
  ///   `@unchecked Sendable` to allow storage in `Sendable` types.
  public final class ObjectBuilder: @unchecked Sendable {
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
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: String) -> Self {
      dict[key] = .string(value)
      return self
    }

    /// Sets the value for `key` to a JSON boolean.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: Bool) -> Self {
      dict[key] = .boolean(value)
      return self
    }

    /// Sets the value for `key` to a JSON integer (`Int`).
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: Int) -> Self {
      dict[key] = .number(.integer(Int64(value)))
      return self
    }

    /// Sets the value for `key` to a JSON integer (`Int64`).
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: Int64) -> Self {
      dict[key] = .number(.integer(value))
      return self
    }

    /// Sets the value for `key` to a JSON integer (`UInt`).
    /// Values exceeding `Int64.max` are stored as float with possible precision loss.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: UInt) -> Self {
      if value <= UInt(Int64.max) {
        dict[key] = .number(.integer(Int64(value)))
      } else {
        dict[key] = .number(.float(Double(value)))
      }
      return self
    }

    /// Sets the value for `key` to a JSON integer (`UInt64`).
    /// Values exceeding `Int64.max` are stored as float with possible precision loss.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: UInt64) -> Self {
      if value <= UInt64(Int64.max) {
        dict[key] = .number(.integer(Int64(value)))
      } else {
        dict[key] = .number(.float(Double(value)))
      }
      return self
    }

    /// Sets the value for `key` to a JSON float (`Double`).
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: Double) -> Self {
      dict[key] = .number(.float(value))
      return self
    }

    /// Sets the value for `key` to a JSON float (`Float`).
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: Float) -> Self {
      dict[key] = .number(.float(Double(value)))
      return self
    }

    /// Sets the value for `key` to a JSON array.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: [JSON]) -> Self {
      dict[key] = .array(value)
      return self
    }

    /// Sets the value for `key` to a JSON object built from `builder`.
    /// The builder is consumed immediately — no need to call `.build()` separately.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: JSON.ObjectBuilder) -> Self {
      dict[key] = value.build()
      return self
    }

    /// Sets the value for `key` to a JSON array built from `builder`.
    /// The builder is consumed immediately — no need to call `.build()` separately.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func set(_ key: String, _ value: JSON.ArrayBuilder) -> Self {
      dict[key] = value.build()
      return self
    }

    /// Sets the value for `key` to JSON null.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setNull(_ key: String) -> Self {
      dict[key] = .null
      return self
    }

    /// Sets the value for `key` to `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: String?) -> Self {
      if let v = value { dict[key] = .string(v) }
      return self
    }

    /// Sets the value for `key` to `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: Bool?) -> Self {
      if let v = value { dict[key] = .boolean(v) }
      return self
    }

    /// Sets the value for `key` to `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: Int?) -> Self {
      if let v = value { dict[key] = .number(.integer(Int64(v))) }
      return self
    }

    /// Sets the value for `key` to `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: Int64?) -> Self {
      if let v = value { dict[key] = .number(.integer(v)) }
      return self
    }

    /// Sets the value for `key` to `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: Double?) -> Self {
      if let v = value { dict[key] = .number(.float(v)) }
      return self
    }

    /// Sets the value for `key` to `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: Float?) -> Self {
      if let v = value { dict[key] = .number(.float(Double(v))) }
      return self
    }

    /// Sets the value for `key` to `value` (`UInt`) if non-nil; otherwise does nothing.
    /// Values exceeding `Int64.max` are stored as float with possible precision loss.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: UInt?) -> Self {
      if let v = value { dict[key] = v <= UInt(Int64.max) ? .number(.integer(Int64(v))) : .number(.float(Double(v))) }
      return self
    }

    /// Sets the value for `key` to `value` (`UInt64`) if non-nil; otherwise does nothing.
    /// Values exceeding `Int64.max` are stored as float with possible precision loss.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: UInt64?) -> Self {
      if let v = value { dict[key] = v <= UInt64(Int64.max) ? .number(.integer(Int64(v))) : .number(.float(Double(v))) }
      return self
    }

    /// Sets the value for `key` to `value` (`JSON`) if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: JSON?) -> Self {
      if let v = value { dict[key] = v }
      return self
    }

    /// Sets the value for `key` to `value` (`[JSON]`) if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: [JSON]?) -> Self {
      if let v = value { dict[key] = .array(v) }
      return self
    }

    /// Sets the value for `key` to a JSON object built from `builder` if non-nil; otherwise does nothing.
    /// The builder is consumed immediately — no need to call `.build()` separately.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: JSON.ObjectBuilder?) -> Self {
      if let v = value { dict[key] = v.build() }
      return self
    }

    /// Sets the value for `key` to a JSON array built from `builder` if non-nil; otherwise does nothing.
    /// The builder is consumed immediately — no need to call `.build()` separately.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: JSON.ArrayBuilder?) -> Self {
      if let v = value { dict[key] = v.build() }
      return self
    }

    /// Removes the value for `key` from the builder.
    /// If `key` does not exist, this is a no-op.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func remove(_ key: String) -> Self {
      dict.removeValue(forKey: key)
      return self
    }

    /// Merges all key-value pairs from `other` into this builder.
    /// - Existing keys keep their original position in the key order.
    /// - New keys are appended at the end.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func merge(_ other: JSON.ObjectBuilder) -> Self {
      for (key, value) in other.dict {
        dict[key] = value
      }
      return self
    }

    /// Returns the current number of key-value pairs in the builder.
    public var count: Int { dict.count }

    /// Builds and returns the final JSON object value.
    /// May be called multiple times; each call returns a snapshot of the current state.
    public func build() -> JSON {
      return .object(dict)
    }

    /// Builds the JSON object and returns the serialized JSON string.
    /// - Parameter indent: Number of spaces per indent level. `nil` means compact (no indent).
    public func buildString(indent: Int? = nil) -> String {
      return build().dump(indent: indent ?? -1)
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
  ///
  /// - Invariant: `build()` may be called multiple times; each call returns a
  ///   snapshot of the current state.
  /// - Thread safety: Classes enable fluent chaining without copy-on-write overhead
  ///   on every chained call. This builder is designed for single-threaded use;
  ///   it is not safe to share across concurrency boundaries. Marked
  ///   `@unchecked Sendable` to allow storage in `Sendable` types.
  public final class ArrayBuilder: @unchecked Sendable {
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
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: String) -> Self {
      elements.append(.string(value))
      return self
    }

    /// Appends a JSON boolean.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: Bool) -> Self {
      elements.append(.boolean(value))
      return self
    }

    /// Appends a JSON integer (`Int`).
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: Int) -> Self {
      elements.append(.number(.integer(Int64(value))))
      return self
    }

    /// Appends a JSON integer (`Int64`).
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: Int64) -> Self {
      elements.append(.number(.integer(value)))
      return self
    }

    /// Appends a JSON integer (`UInt`).
    /// Values exceeding `Int64.max` are stored as float with possible precision loss.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: UInt) -> Self {
      if value <= UInt(Int64.max) {
        elements.append(.number(.integer(Int64(value))))
      } else {
        elements.append(.number(.float(Double(value))))
      }
      return self
    }

    /// Appends a JSON integer (`UInt64`).
    /// Values exceeding `Int64.max` are stored as float with possible precision loss.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: UInt64) -> Self {
      if value <= UInt64(Int64.max) {
        elements.append(.number(.integer(Int64(value))))
      } else {
        elements.append(.number(.float(Double(value))))
      }
      return self
    }

    /// Appends a JSON float (`Double`).
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: Double) -> Self {
      elements.append(.number(.float(value)))
      return self
    }

    /// Appends a JSON float (`Float`).
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: Float) -> Self {
      elements.append(.number(.float(Double(value))))
      return self
    }

    /// Appends a JSON array.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: [JSON]) -> Self {
      elements.append(.array(value))
      return self
    }

    /// Appends a JSON object built from `builder`.
    /// The builder is consumed immediately — no need to call `.build()` separately.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: JSON.ObjectBuilder) -> Self {
      elements.append(value.build())
      return self
    }

    /// Appends a JSON array built from `builder`.
    /// The builder is consumed immediately — no need to call `.build()` separately.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func add(_ value: JSON.ArrayBuilder) -> Self {
      elements.append(value.build())
      return self
    }

    /// Appends JSON null.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addNull() -> Self {
      elements.append(.null)
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: String?) -> Self {
      if let v = value { elements.append(.string(v)) }
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: Bool?) -> Self {
      if let v = value { elements.append(.boolean(v)) }
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: Int?) -> Self {
      if let v = value { elements.append(.number(.integer(Int64(v)))) }
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: Int64?) -> Self {
      if let v = value { elements.append(.number(.integer(v))) }
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// Values exceeding `Int64.max` are stored as float with possible precision loss.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: UInt?) -> Self {
      if let v = value { elements.append(v <= UInt(Int64.max) ? .number(.integer(Int64(v))) : .number(.float(Double(v)))) }
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// Values exceeding `Int64.max` are stored as float with possible precision loss.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: UInt64?) -> Self {
      if let v = value { elements.append(v <= UInt64(Int64.max) ? .number(.integer(Int64(v))) : .number(.float(Double(v)))) }
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: Double?) -> Self {
      if let v = value { elements.append(.number(.float(v))) }
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: Float?) -> Self {
      if let v = value { elements.append(.number(.float(Double(v)))) }
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: JSON?) -> Self {
      if let v = value { elements.append(v) }
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: [JSON]?) -> Self {
      if let v = value { elements.append(.array(v)) }
      return self
    }

    /// Appends a JSON object built from `builder` if non-nil; otherwise does nothing.
    /// The builder is consumed immediately — no need to call `.build()` separately.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: JSON.ObjectBuilder?) -> Self {
      if let v = value { elements.append(v.build()) }
      return self
    }

    /// Appends a JSON array built from `builder` if non-nil; otherwise does nothing.
    /// The builder is consumed immediately — no need to call `.build()` separately.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: JSON.ArrayBuilder?) -> Self {
      if let v = value { elements.append(v.build()) }
      return self
    }

    /// Appends all elements from `other` into this builder.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func append(contentsOf other: JSON.ArrayBuilder) -> Self {
      elements.append(contentsOf: other.elements)
      return self
    }

    /// Appends all elements from an array of `JSON` values.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func append(contentsOf other: [JSON]) -> Self {
      elements.append(contentsOf: other)
      return self
    }

    /// Returns the current number of elements in the builder.
    public var count: Int { elements.count }

    /// Builds and returns the final JSON array value.
    /// May be called multiple times; each call returns a snapshot of the current state.
    public func build() -> JSON {
      return .array(elements)
    }

    /// Builds the JSON array and returns the serialized JSON string.
    /// - Parameter indent: Number of spaces per indent level. `nil` means compact (no indent).
    public func buildString(indent: Int? = nil) -> String {
      return build().dump(indent: indent ?? -1)
    }
  }
}
