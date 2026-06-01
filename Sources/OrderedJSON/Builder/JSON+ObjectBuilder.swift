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
  ///   .tags(JSON.ArrayBuilder()
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
  /// - Optional overloads: `setIfPresent(_:_:)` and `setNull(_:)` use Optional
  ///   parameters. Because Swift cannot resolve overloads for `nil` literals,
  ///   callers must disambiguate with `as Type?` or a typed `let` binding:
  ///   `setIfPresent("key", nil as String?)` or `let v: String?; setIfPresent("key", v)`.
  public final class ObjectBuilder: @unchecked Sendable {
    private var dict: OrderedDictionary<String, JSON> = [:]

    public init() {}

    /// Sets the value for `key` to a `JSON` value.
    /// - Note: The two parameters are unlabeled for fluent reading at the call
    ///   site: `.set("key", value)`. The first parameter is always the key, the
    ///   second is always the value.
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
      if let v = value {
        dict[key] = v <= UInt(Int64.max) ? .number(.integer(Int64(v))) : .number(.float(Double(v)))
      }
      return self
    }

    /// Sets the value for `key` to `value` (`UInt64`) if non-nil; otherwise does nothing.
    /// Values exceeding `Int64.max` are stored as float with possible precision loss.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func setIfPresent(_ key: String, _ value: UInt64?) -> Self {
      if let v = value {
        dict[key] =
          v <= UInt64(Int64.max) ? .number(.integer(Int64(v))) : .number(.float(Double(v)))
      }
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
    public var count: Int {
      dict.count
    }

    /// Builds and returns the final JSON object value.
    /// May be called multiple times; each call returns a snapshot of the current state.
    public func build() -> JSON {
      return .object(dict)
    }

    /// Builds the JSON object and returns the serialized JSON string.
    /// - Parameter indent: Indentation style. Use `.compact` for single-line
    ///   output (default), `.spaces(n)` for n-space indentation, or `.tab`.
    public func buildString(indent: JSON.Indent = .compact) -> String {
      return build().dump(indent: indent)
    }
  }
}
