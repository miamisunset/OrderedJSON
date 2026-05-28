import Foundation
import OrderedCollections

/// A JSON encoder that produces `JSON` values with preserved key order.
///
/// - Important: Set `userInfo` before calling `encode`/`encodeAsString`;
///   mutations after the call do not propagate to nested containers.
public struct OrderedJSONEncoder {
  /// The user info dictionary for the encoder, propagated to all nested encoders.
  public var userInfo: [CodingUserInfoKey: Any]

  /// The strategy to use for encoding `Date` values.
  public var dateEncodingStrategy: DateEncodingStrategy = .deferredToDate

  /// The strategy to use for encoding `Data` values.
  public var dataEncodingStrategy: DataEncodingStrategy = .base64

  /// The strategy to use for encoding `Decimal` values.
  public var decimalEncodingStrategy: DecimalEncodingStrategy = .asString

  /// Creates a new encoder with default options.
  public init() {
    userInfo = [:]
  }

  public func encode<T: Encodable>(_ value: T) throws -> JSON {
    let impl = _JSONEncodeImpl(
      userInfo: userInfo,
      dateEncodingStrategy: dateEncodingStrategy,
      dataEncodingStrategy: dataEncodingStrategy,
      decimalEncodingStrategy: decimalEncodingStrategy
    )
    try value.encode(to: impl)
    return impl.json
  }

  public func encodeAsString<T: Encodable>(_ value: T) throws -> String {
    let json = try encode(value)
    return json.dump(indent: nil)
  }
}

// MARK: - Encoding strategies

/// Strategy for encoding `Date` values.
public enum DateEncodingStrategy {
  /// Encode the `Date` using its `Encodable` implementation (default).
  case deferredToDate
  /// Encode as a Double representing seconds since 1970-01-01.
  case secondsSince1970
  /// Encode as a Double representing milliseconds since 1970-01-01.
  case millisecondsSince1970
  /// Encode as an ISO-8601 string using `ISO8601DateFormatter`.
  case iso8601
  /// Encode using a `DateFormatter`.
  case formatted(DateFormatter)
  /// Encode using a custom closure that produces a `JSON` value.
  case custom((Date, Encoder) throws -> JSON)
}

/// Strategy for encoding `Data` values.
public enum DataEncodingStrategy {
  /// Encode the `Data` using its `Encodable` implementation.
  case deferredToData
  /// Encode as a Base64-encoded string (default).
  case base64
  /// Encode using a custom closure that produces a `JSON` value.
  case custom((Data, Encoder) throws -> JSON)
}

/// Strategy for encoding `Decimal` values.
public enum DecimalEncodingStrategy {
  /// Encode the `Decimal` as a JSON string (default, preserves precision).
  case asString
  /// Encode the `Decimal` as a JSON number (matching Foundation's `JSONEncoder` behavior).
  case asNumber
}

// MARK: - Internal encoder implementation

/// Reference wrapper for an ordered dictionary — allows shared mutation.
final class _ObjectReference {
  var dict: OrderedDictionary<String, JSON> = [:]
  init() {}
}

/// Reference wrapper for an array — allows shared mutation.
final class _ArrayReference {
  var elements: [JSON] = []
  var count: Int {
    elements.count
  }

  init() {}
}

/// The concrete `Encoder` implementation.
final class _JSONEncodeImpl: Encoder {
  var codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any]

  /// Strategies propagated from `OrderedJSONEncoder`.
  let dateEncodingStrategy: DateEncodingStrategy
  let dataEncodingStrategy: DataEncodingStrategy
  let decimalEncodingStrategy: DecimalEncodingStrategy

  /// The final encoded JSON value.
  var json: JSON = .null

  /// If encoding a keyed container, the object reference.
  var objectRef: _ObjectReference?

  /// If encoding an unkeyed container, the array reference.
  var arrayRef: _ArrayReference?

  // MARK: - Parent wiring for nested containers / superEncoder

  /// When set, updates the parent's keyed entry after each encode.
  var parentRef: _ObjectReference?
  var parentKey: String?

  /// When set, updates the parent's array entry at `parentArrayIndex`.
  var parentArrayRef: _ArrayReference?
  var parentArrayIndex: Int?

  /// Weak reference to parent impl, so the parent can resync after child updates.
  weak var parentImpl: _JSONEncodeImpl?

  init(
    userInfo: [CodingUserInfoKey: Any] = [:],
    dateEncodingStrategy: DateEncodingStrategy = .deferredToDate,
    dataEncodingStrategy: DataEncodingStrategy = .base64,
    decimalEncodingStrategy: DecimalEncodingStrategy = .asString
  ) {
    self.userInfo = userInfo
    self.dateEncodingStrategy = dateEncodingStrategy
    self.dataEncodingStrategy = dataEncodingStrategy
    self.decimalEncodingStrategy = decimalEncodingStrategy
  }

  func container<Key: CodingKey>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> {
    let ref = _ObjectReference()
    objectRef = ref
    return KeyedEncodingContainer(_JSONKeyedEncodingContainer<Key>(impl: self, ref: ref))
  }

  func unkeyedContainer() -> UnkeyedEncodingContainer {
    let ref = _ArrayReference()
    arrayRef = ref
    return _JSONUnkeyedEncodingContainer(impl: self, ref: ref)
  }

  func singleValueContainer() -> SingleValueEncodingContainer {
    _JSONSingleValueEncodingContainer(impl: self)
  }

  /// Syncs `json` from current keyed state, then propagates to parent.
  func syncKeyed() {
    if let ref = objectRef {
      json = .object(ref.dict)
    }
    if let parentRef, let parentKey {
      parentRef.dict[parentKey] = json
      parentImpl?.syncKeyed()
    }
    if let parentArrayRef, let idx = parentArrayIndex {
      if idx < parentArrayRef.elements.count {
        parentArrayRef.elements[idx] = json
      }
      parentImpl?.syncUnkeyed()
    }
  }

  /// Syncs `json` from current unkeyed state, then propagates to parent.
  func syncUnkeyed() {
    if let ref = arrayRef {
      json = .array(ref.elements)
    }
    if let parentRef, let parentKey {
      parentRef.dict[parentKey] = json
      parentImpl?.syncKeyed()
    }
    if let parentArrayRef, let idx = parentArrayIndex {
      if idx < parentArrayRef.elements.count {
        parentArrayRef.elements[idx] = json
      }
      parentImpl?.syncUnkeyed()
    }
  }
}

// MARK: - Foundation type encoding helpers

private func encodeDate(
  _ date: Date, with strategy: DateEncodingStrategy, codingPath: [CodingKey],
  dateEncodingStrategy: DateEncodingStrategy,
  dataEncodingStrategy: DataEncodingStrategy,
  decimalEncodingStrategy: DecimalEncodingStrategy
) throws -> JSON {
  switch strategy {
  case .deferredToDate:
    // Fall through to Date's own Encodable implementation
    let impl = _JSONEncodeImpl(
      dateEncodingStrategy: dateEncodingStrategy,
      dataEncodingStrategy: dataEncodingStrategy,
      decimalEncodingStrategy: decimalEncodingStrategy
    )
    impl.codingPath = codingPath
    try date.encode(to: impl)
    return impl.json
  case .secondsSince1970:
    return .number(.float(date.timeIntervalSince1970))
  case .millisecondsSince1970:
    return .number(.float(date.timeIntervalSince1970 * 1000.0))
  case .iso8601:
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return .string(formatter.string(from: date))
  case .formatted(let formatter):
    return .string(formatter.string(from: date))
  case .custom(let closure):
    let impl = _JSONEncodeImpl(
      dateEncodingStrategy: dateEncodingStrategy,
      dataEncodingStrategy: dataEncodingStrategy,
      decimalEncodingStrategy: decimalEncodingStrategy
    )
    impl.codingPath = codingPath
    return try closure(date, impl)
  }
}

private func encodeData(
  _ data: Data, with strategy: DataEncodingStrategy,
  dateEncodingStrategy: DateEncodingStrategy,
  dataEncodingStrategy: DataEncodingStrategy,
  decimalEncodingStrategy: DecimalEncodingStrategy
) throws -> JSON {
  switch strategy {
  case .deferredToData:
    // Fall through to Data's own Encodable implementation
    let impl = _JSONEncodeImpl(
      dateEncodingStrategy: dateEncodingStrategy,
      dataEncodingStrategy: dataEncodingStrategy,
      decimalEncodingStrategy: decimalEncodingStrategy
    )
    try data.encode(to: impl)
    return impl.json
  case .base64:
    return .string(data.base64EncodedString())
  case .custom(let closure):
    let impl = _JSONEncodeImpl(
      dateEncodingStrategy: dateEncodingStrategy,
      dataEncodingStrategy: dataEncodingStrategy,
      decimalEncodingStrategy: decimalEncodingStrategy
    )
    return try closure(data, impl)
  }
}

private func encodeDecimal(_ decimal: Decimal, with strategy: DecimalEncodingStrategy) throws
  -> JSON
{
  switch strategy {
  case .asString:
    return .string(decimal.description)
  case .asNumber:
    // Route through the underlying Decimal value directly without String → Double round-trip.
    // For integer-representable Decimals, emit .integer(Int64). For others, emit .float(Double).
    let double = Double(decimal.description) ?? 0
    // Guard against Double overflow to infinity (e.g., Decimal with huge exponent)
    // Infinity is not representable as a JSON number — throw instead of
    // silently producing a value that serializes to null.
    guard double.isFinite else {
      throw EncodingError.invalidValue(
        decimal,
        EncodingError.Context(
          codingPath: [],
          debugDescription:
            "Decimal value overflows Double range and cannot be represented as a JSON number"
        )
      )
    }
    if Decimal(string: "\(Int64(double))") == decimal && double == Double(Int64(double)) {
      return .number(.integer(Int64(double)))
    }
    return .number(.float(double))
  }
}

// MARK: - Keyed encoding container

final class _JSONKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
  let codingPath: [CodingKey]
  let impl: _JSONEncodeImpl
  let ref: _ObjectReference

  init(impl: _JSONEncodeImpl, ref: _ObjectReference, pathPrefix: [CodingKey] = []) {
    self.impl = impl
    self.ref = ref
    codingPath = pathPrefix
  }

  func encode(_ value: JSON, forKey key: Key) throws {
    ref.dict[key.stringValue] = value
    impl.syncKeyed()
  }

  func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
    // Foundation type special handling
    if let date = value as? Date {
      ref.dict[key.stringValue] = try encodeDate(
        date, with: impl.dateEncodingStrategy, codingPath: codingPath + [key],
        dateEncodingStrategy: impl.dateEncodingStrategy,
        dataEncodingStrategy: impl.dataEncodingStrategy,
        decimalEncodingStrategy: impl.decimalEncodingStrategy
      )
      impl.syncKeyed()
      return
    }
    if let data = value as? Data {
      ref.dict[key.stringValue] = try encodeData(
        data, with: impl.dataEncodingStrategy,
        dateEncodingStrategy: impl.dateEncodingStrategy,
        dataEncodingStrategy: impl.dataEncodingStrategy,
        decimalEncodingStrategy: impl.decimalEncodingStrategy
      )
      impl.syncKeyed()
      return
    }
    if let url = value as? URL {
      ref.dict[key.stringValue] = .string(url.absoluteString)
      impl.syncKeyed()
      return
    }
    if let uuid = value as? UUID {
      ref.dict[key.stringValue] = .string(uuid.uuidString)
      impl.syncKeyed()
      return
    }
    if let decimal = value as? Decimal {
      ref.dict[key.stringValue] = try encodeDecimal(decimal, with: impl.decimalEncodingStrategy)
      impl.syncKeyed()
      return
    }

    // Default path
    let child = _JSONEncodeImpl(
      userInfo: impl.userInfo,
      dateEncodingStrategy: impl.dateEncodingStrategy,
      dataEncodingStrategy: impl.dataEncodingStrategy,
      decimalEncodingStrategy: impl.decimalEncodingStrategy
    )
    child.codingPath = codingPath + [key]
    try value.encode(to: child)
    ref.dict[key.stringValue] = child.json
    impl.syncKeyed()
  }

  func encodeNil(forKey key: Key) throws {
    ref.dict[key.stringValue] = .null
    impl.syncKeyed()
  }

  func encode(_ value: String, forKey key: Key) throws {
    ref.dict[key.stringValue] = .string(value)
    impl.syncKeyed()
  }

  func encode(_ value: Bool, forKey key: Key) throws {
    ref.dict[key.stringValue] = .boolean(value)
    impl.syncKeyed()
  }

  func encode(_ value: Int64, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.integer(value))
    impl.syncKeyed()
  }

  func encode(_ value: Int, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.integer(Int64(value)))
    impl.syncKeyed()
  }

  func encode(_ value: Double, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.float(value))
    impl.syncKeyed()
  }

  func encode(_ value: Float, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.float(Double(value)))
    impl.syncKeyed()
  }

  // MARK: - Integer and unsigned widths

  func encode(_ value: Int8, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.integer(Int64(value)))
    impl.syncKeyed()
  }

  func encode(_ value: Int16, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.integer(Int64(value)))
    impl.syncKeyed()
  }

  func encode(_ value: Int32, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.integer(Int64(value)))
    impl.syncKeyed()
  }

  func encode(_ value: UInt, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.integer(Int64(value)))
    impl.syncKeyed()
  }

  func encode(_ value: UInt8, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.integer(Int64(value)))
    impl.syncKeyed()
  }

  func encode(_ value: UInt16, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.integer(Int64(value)))
    impl.syncKeyed()
  }

  func encode(_ value: UInt32, forKey key: Key) throws {
    ref.dict[key.stringValue] = .number(.integer(Int64(value)))
    impl.syncKeyed()
  }

  func encode(_ value: UInt64, forKey key: Key) throws {
    // UInt64 values > Int64.max would overflow — throw encoding error
    guard let i = Int64(exactly: value) else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: codingPath + [key],
          debugDescription: "UInt64 value \(value) overflows Int64"
        )
      )
    }
    ref.dict[key.stringValue] = .number(.integer(i))
    impl.syncKeyed()
  }

  // MARK: - Nested containers

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy _: NestedKey.Type,
    forKey key: Key
  ) -> KeyedEncodingContainer<NestedKey> {
    let childRef = _ObjectReference()
    let childImpl = _JSONEncodeImpl(
      userInfo: impl.userInfo,
      dateEncodingStrategy: impl.dateEncodingStrategy,
      dataEncodingStrategy: impl.dataEncodingStrategy,
      decimalEncodingStrategy: impl.decimalEncodingStrategy
    )
    childImpl.codingPath = codingPath + [key]
    childImpl.objectRef = childRef
    childImpl.parentRef = ref
    childImpl.parentKey = key.stringValue
    childImpl.parentImpl = impl
    ref.dict[key.stringValue] = .object(childRef.dict)
    impl.syncKeyed()
    return KeyedEncodingContainer(
      _JSONKeyedEncodingContainer<NestedKey>(
        impl: childImpl, ref: childRef, pathPrefix: codingPath + [key]
      )
    )
  }

  func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    let childRef = _ArrayReference()
    let childImpl = _JSONEncodeImpl(
      userInfo: impl.userInfo,
      dateEncodingStrategy: impl.dateEncodingStrategy,
      dataEncodingStrategy: impl.dataEncodingStrategy,
      decimalEncodingStrategy: impl.decimalEncodingStrategy
    )
    childImpl.codingPath = codingPath + [key]
    childImpl.arrayRef = childRef
    childImpl.parentRef = ref
    childImpl.parentKey = key.stringValue
    childImpl.parentImpl = impl
    ref.dict[key.stringValue] = .array(childRef.elements)
    impl.syncKeyed()
    return _JSONUnkeyedEncodingContainer(
      impl: childImpl, ref: childRef, pathPrefix: codingPath + [key]
    )
  }

  // MARK: - Super encoders

  func superEncoder(forKey key: Key) -> Encoder {
    let childImpl = _JSONEncodeImpl(
      userInfo: impl.userInfo,
      dateEncodingStrategy: impl.dateEncodingStrategy,
      dataEncodingStrategy: impl.dataEncodingStrategy,
      decimalEncodingStrategy: impl.decimalEncodingStrategy
    )
    childImpl.codingPath = codingPath + [key]
    childImpl.parentRef = ref
    childImpl.parentKey = key.stringValue
    childImpl.parentImpl = impl
    ref.dict[key.stringValue] = .null
    impl.syncKeyed()
    return childImpl
  }

  func superEncoder() -> Encoder {
    // Per Foundation convention, whole-object super encodes under key "super".
    let childImpl = _JSONEncodeImpl(
      userInfo: impl.userInfo,
      dateEncodingStrategy: impl.dateEncodingStrategy,
      dataEncodingStrategy: impl.dataEncodingStrategy,
      decimalEncodingStrategy: impl.decimalEncodingStrategy
    )
    childImpl.parentRef = ref
    childImpl.parentKey = "super"
    childImpl.parentImpl = impl
    ref.dict["super"] = .null
    impl.syncKeyed()
    return childImpl
  }
}

// MARK: - Unkeyed encoding container

final class _JSONUnkeyedEncodingContainer: UnkeyedEncodingContainer {
  let codingPath: [CodingKey]
  let impl: _JSONEncodeImpl
  let ref: _ArrayReference

  var count: Int {
    ref.count
  }

  init(impl: _JSONEncodeImpl, ref: _ArrayReference, pathPrefix: [CodingKey] = []) {
    self.impl = impl
    self.ref = ref
    codingPath = pathPrefix
  }

  func encode<T: Encodable>(_ value: T) throws {
    // Foundation type special handling
    if let date = value as? Date {
      try ref.elements.append(
        encodeDate(
          date, with: impl.dateEncodingStrategy, codingPath: codingPath,
          dateEncodingStrategy: impl.dateEncodingStrategy,
          dataEncodingStrategy: impl.dataEncodingStrategy,
          decimalEncodingStrategy: impl.decimalEncodingStrategy
        )
      )
      impl.syncUnkeyed()
      return
    }
    if let data = value as? Data {
      try ref.elements.append(
        encodeData(
          data, with: impl.dataEncodingStrategy,
          dateEncodingStrategy: impl.dateEncodingStrategy,
          dataEncodingStrategy: impl.dataEncodingStrategy,
          decimalEncodingStrategy: impl.decimalEncodingStrategy
        )
      )
      impl.syncUnkeyed()
      return
    }
    if let url = value as? URL {
      ref.elements.append(.string(url.absoluteString))
      impl.syncUnkeyed()
      return
    }
    if let uuid = value as? UUID {
      ref.elements.append(.string(uuid.uuidString))
      impl.syncUnkeyed()
      return
    }
    if let decimal = value as? Decimal {
      try ref.elements.append(encodeDecimal(decimal, with: impl.decimalEncodingStrategy))
      impl.syncUnkeyed()
      return
    }

    // Default path
    let child = _JSONEncodeImpl(
      userInfo: impl.userInfo,
      dateEncodingStrategy: impl.dateEncodingStrategy,
      dataEncodingStrategy: impl.dataEncodingStrategy,
      decimalEncodingStrategy: impl.decimalEncodingStrategy
    )
    try value.encode(to: child)
    ref.elements.append(child.json)
    impl.syncUnkeyed()
  }

  func encodeNil() throws {
    ref.elements.append(.null)
    impl.syncUnkeyed()
  }

  func encode(_ value: String) throws {
    ref.elements.append(.string(value))
    impl.syncUnkeyed()
  }

  func encode(_ value: Bool) throws {
    ref.elements.append(.boolean(value))
    impl.syncUnkeyed()
  }

  func encode(_ value: Int64) throws {
    ref.elements.append(.number(.integer(value)))
    impl.syncUnkeyed()
  }

  func encode(_ value: Int) throws {
    ref.elements.append(.number(.integer(Int64(value))))
    impl.syncUnkeyed()
  }

  func encode(_ value: Double) throws {
    ref.elements.append(.number(.float(value)))
    impl.syncUnkeyed()
  }

  func encode(_ value: Float) throws {
    ref.elements.append(.number(.float(Double(value))))
    impl.syncUnkeyed()
  }

  // MARK: - Integer and unsigned widths

  func encode(_ value: Int8) throws {
    ref.elements.append(.number(.integer(Int64(value))))
    impl.syncUnkeyed()
  }

  func encode(_ value: Int16) throws {
    ref.elements.append(.number(.integer(Int64(value))))
    impl.syncUnkeyed()
  }

  func encode(_ value: Int32) throws {
    ref.elements.append(.number(.integer(Int64(value))))
    impl.syncUnkeyed()
  }

  func encode(_ value: UInt) throws {
    ref.elements.append(.number(.integer(Int64(value))))
    impl.syncUnkeyed()
  }

  func encode(_ value: UInt8) throws {
    ref.elements.append(.number(.integer(Int64(value))))
    impl.syncUnkeyed()
  }

  func encode(_ value: UInt16) throws {
    ref.elements.append(.number(.integer(Int64(value))))
    impl.syncUnkeyed()
  }

  func encode(_ value: UInt32) throws {
    ref.elements.append(.number(.integer(Int64(value))))
    impl.syncUnkeyed()
  }

  func encode(_ value: UInt64) throws {
    guard let i = Int64(exactly: value) else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "UInt64 value \(value) overflows Int64"
        )
      )
    }
    ref.elements.append(.number(.integer(i)))
    impl.syncUnkeyed()
  }

  // MARK: - Nested containers

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy _: NestedKey.Type
  ) -> KeyedEncodingContainer<NestedKey> {
    let childRef = _ObjectReference()
    let childImpl = _JSONEncodeImpl(
      userInfo: impl.userInfo,
      dateEncodingStrategy: impl.dateEncodingStrategy,
      dataEncodingStrategy: impl.dataEncodingStrategy,
      decimalEncodingStrategy: impl.decimalEncodingStrategy
    )
    childImpl.objectRef = childRef
    childImpl.parentArrayRef = ref
    childImpl.parentArrayIndex = ref.elements.count
    childImpl.parentImpl = impl
    ref.elements.append(.object(childRef.dict))
    impl.syncUnkeyed()
    return KeyedEncodingContainer(
      _JSONKeyedEncodingContainer<NestedKey>(
        impl: childImpl, ref: childRef, pathPrefix: codingPath
      )
    )
  }

  func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    let childRef = _ArrayReference()
    let childImpl = _JSONEncodeImpl(
      userInfo: impl.userInfo,
      dateEncodingStrategy: impl.dateEncodingStrategy,
      dataEncodingStrategy: impl.dataEncodingStrategy,
      decimalEncodingStrategy: impl.decimalEncodingStrategy
    )
    childImpl.arrayRef = childRef
    // Capture index *before* appending the placeholder, so the child
    // always writes to the correct slot even if more elements are appended
    // to the outer array after the child is created.
    childImpl.parentArrayIndex = ref.elements.count
    childImpl.parentArrayRef = ref
    childImpl.parentImpl = impl
    ref.elements.append(.array(childRef.elements))
    impl.syncUnkeyed()
    return _JSONUnkeyedEncodingContainer(
      impl: childImpl, ref: childRef, pathPrefix: codingPath
    )
  }

  // MARK: - Super encoders

  func superEncoder() -> Encoder {
    let childImpl = _JSONEncodeImpl(
      userInfo: impl.userInfo,
      dateEncodingStrategy: impl.dateEncodingStrategy,
      dataEncodingStrategy: impl.dataEncodingStrategy,
      decimalEncodingStrategy: impl.decimalEncodingStrategy
    )
    childImpl.parentArrayRef = ref
    childImpl.parentArrayIndex = ref.elements.count
    childImpl.parentImpl = impl
    ref.elements.append(.null)
    impl.syncUnkeyed()
    return childImpl
  }
}

// MARK: - Single-value encoding container

struct _JSONSingleValueEncodingContainer: SingleValueEncodingContainer {
  let codingPath: [CodingKey]
  let impl: _JSONEncodeImpl

  init(impl: _JSONEncodeImpl, pathPrefix: [CodingKey] = []) {
    self.impl = impl
    codingPath = pathPrefix
  }

  mutating func encodeNil() throws {
    impl.json = .null
    impl.syncKeyed()
  }

  mutating func encode(_ value: String) throws {
    impl.json = .string(value)
    impl.syncKeyed()
  }

  mutating func encode(_ value: Bool) throws {
    impl.json = .boolean(value)
    impl.syncKeyed()
  }

  mutating func encode(_ value: Int64) throws {
    impl.json = .number(.integer(value))
    impl.syncKeyed()
  }

  mutating func encode(_ value: Int) throws {
    impl.json = .number(.integer(Int64(value)))
    impl.syncKeyed()
  }

  mutating func encode(_ value: Double) throws {
    impl.json = .number(.float(value))
    impl.syncKeyed()
  }

  mutating func encode(_ value: Float) throws {
    impl.json = .number(.float(Double(value)))
    impl.syncKeyed()
  }

  mutating func encode<T: Encodable>(_ value: T) throws {
    // Foundation type special handling
    if let date = value as? Date {
      impl.json = try encodeDate(
        date, with: impl.dateEncodingStrategy, codingPath: codingPath,
        dateEncodingStrategy: impl.dateEncodingStrategy,
        dataEncodingStrategy: impl.dataEncodingStrategy,
        decimalEncodingStrategy: impl.decimalEncodingStrategy
      )
      impl.syncKeyed()
      return
    }
    if let data = value as? Data {
      impl.json = try encodeData(
        data, with: impl.dataEncodingStrategy,
        dateEncodingStrategy: impl.dateEncodingStrategy,
        dataEncodingStrategy: impl.dataEncodingStrategy,
        decimalEncodingStrategy: impl.decimalEncodingStrategy
      )
      impl.syncKeyed()
      return
    }
    if let url = value as? URL {
      impl.json = .string(url.absoluteString)
      impl.syncKeyed()
      return
    }
    if let uuid = value as? UUID {
      impl.json = .string(uuid.uuidString)
      impl.syncKeyed()
      return
    }
    if let decimal = value as? Decimal {
      impl.json = try encodeDecimal(decimal, with: impl.decimalEncodingStrategy)
      impl.syncKeyed()
      return
    }

    // Default path
    let child = _JSONEncodeImpl(
      userInfo: impl.userInfo,
      dateEncodingStrategy: impl.dateEncodingStrategy,
      dataEncodingStrategy: impl.dataEncodingStrategy,
      decimalEncodingStrategy: impl.decimalEncodingStrategy
    )
    try value.encode(to: child)
    impl.json = child.json
    impl.syncKeyed()
  }
}
