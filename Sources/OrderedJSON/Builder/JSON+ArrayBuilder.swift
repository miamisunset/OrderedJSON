import OrderedCollections

extension JSON {
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
  /// - Optional overloads: `addIfPresent(_:)` and `addNull()` use Optional
  ///   parameters. Because Swift cannot resolve overloads for `nil` literals,
  ///   callers must disambiguate with `as Type?` or a typed `let` binding:
  ///   `addIfPresent(nil as String?)` or `let v: String?; addIfPresent(v)`.
  public final class ArrayBuilder: @unchecked Sendable {
    private var elements: [JSON] = []

    public init() {}

    /// Appends a `JSON` value to the array.
    /// - Note: The parameter is unlabeled for fluent reading at the call site:
    ///   `.add(value)`.
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
      if let v = value {
        elements.append(
          v <= UInt(Int64.max) ? .number(.integer(Int64(v))) : .number(.float(Double(v)))
        )
      }
      return self
    }

    /// Appends `value` if non-nil; otherwise does nothing.
    /// Values exceeding `Int64.max` are stored as float with possible precision loss.
    /// - Returns: `self` for chaining.
    @discardableResult
    public func addIfPresent(_ value: UInt64?) -> Self {
      if let v = value {
        elements.append(
          v <= UInt64(Int64.max) ? .number(.integer(Int64(v))) : .number(.float(Double(v)))
        )
      }
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
    public var count: Int {
      elements.count
    }

    /// Builds and returns the final JSON array value.
    /// May be called multiple times; each call returns a snapshot of the current state.
    public func build() -> JSON {
      return .array(elements)
    }

    /// Builds the JSON array and returns the serialized JSON string.
    /// - Parameter indent: Number of spaces per indent level. `nil` means compact (no indent).
    public func buildString(indent: Int? = nil) -> String {
      return build().dump(indent: indent)
    }
  }
}
