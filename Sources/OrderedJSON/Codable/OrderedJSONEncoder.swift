import OrderedCollections

/// A JSON encoder that produces `JSON` values with preserved key order.
public struct OrderedJSONEncoder {
  public var userInfo: [CodingUserInfoKey: Any]

  public init() {
    self.userInfo = [:]
  }

  public func encode<T: Encodable>(_ value: T) throws -> JSON {
    let impl = _JSONEncodeImpl(userInfo: userInfo)
    try value.encode(to: impl)
    return impl.json
  }

  public func encodeToString<T: Encodable>(_ value: T) throws -> String {
    let json = try encode(value)
    return json.dump(indent: -1)
  }
}

// MARK: - Internal encoder implementation

/// Reference-type wrapper for an ordered dictionary — allows shared mutation.
final class _ObjectReference {
  var dict: OrderedDictionary<String, JSON> = [:]
  init() {}
}

/// Reference-type wrapper for an array — allows shared mutation.
final class _ArrayReference {
  var elements: [JSON] = []
  var count: Int { elements.count }
  init() {}
}

/// The concrete `Encoder` implementation.
final class _JSONEncodeImpl: Encoder {
  let codingPath: [CodingKey] = []
  var userInfo: [CodingUserInfoKey: Any]

  /// The final encoded JSON value, set after encoding completes.
  var json: JSON = .null

  /// If encoding a keyed container, the object reference.
  var objectRef: _ObjectReference?

  /// If encoding an unkeyed container, the array reference.
  var arrayRef: _ArrayReference?

  init(userInfo: [CodingUserInfoKey: Any] = [:]) {
    self.userInfo = userInfo
  }

  func container<Key: CodingKey>(keyedBy keyType: Key.Type) -> KeyedEncodingContainer<Key> {
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

  /// Updates `json` from the current keyed container state.
  func syncKeyed() {
    if let ref = objectRef { json = .object(ref.dict) }
  }

  /// Updates `json` from the current unkeyed container state.
  func syncUnkeyed() {
    if let ref = arrayRef { json = .array(ref.elements) }
  }
}

// MARK: - Keyed encoding container

final class _JSONKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
  let codingPath: [CodingKey] = []
  let impl: _JSONEncodeImpl
  let ref: _ObjectReference

  init(impl: _JSONEncodeImpl, ref: _ObjectReference) {
    self.impl = impl
    self.ref = ref
  }

  func encode(_ value: JSON, forKey key: Key) throws {
    ref.dict[key.stringValue] = value
    impl.syncKeyed()
  }
  func encode<T: Encodable>(_ value: T, forKey key: Key) throws {
    let child = _JSONEncodeImpl(userInfo: impl.userInfo)
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

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type,
    forKey key: Key
  ) -> KeyedEncodingContainer<NestedKey> {
    let childRef = _ObjectReference()
    ref.dict[key.stringValue] = .object(childRef.dict)
    impl.syncKeyed()
    let childImpl = _JSONEncodeImpl(userInfo: impl.userInfo)
    childImpl.objectRef = childRef
    let child = _JSONKeyedEncodingContainer<NestedKey>(
      impl: childImpl, ref: childRef)
    return KeyedEncodingContainer(child)
  }

  func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
    let childRef = _ArrayReference()
    ref.dict[key.stringValue] = .array(childRef.elements)
    impl.syncKeyed()
    let childImpl = _JSONEncodeImpl(userInfo: impl.userInfo)
    childImpl.arrayRef = childRef
    return _JSONUnkeyedEncodingContainer(impl: childImpl, ref: childRef)
  }

  func superEncoder(forKey key: Key) -> Encoder {
    _JSONEncodeImpl(userInfo: impl.userInfo)
  }

  func superEncoder() -> Encoder {
    _JSONEncodeImpl(userInfo: impl.userInfo)
  }
}

// MARK: - Unkeyed encoding container

final class _JSONUnkeyedEncodingContainer: UnkeyedEncodingContainer {
  let codingPath: [CodingKey] = []
  let impl: _JSONEncodeImpl
  let ref: _ArrayReference

  var count: Int { ref.count }

  init(impl: _JSONEncodeImpl, ref: _ArrayReference) {
    self.impl = impl
    self.ref = ref
  }

  func encode<T: Encodable>(_ value: T) throws {
    let child = _JSONEncodeImpl(userInfo: impl.userInfo)
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

  func nestedContainer<NestedKey: CodingKey>(
    keyedBy keyType: NestedKey.Type
  ) -> KeyedEncodingContainer<NestedKey> {
    let childRef = _ObjectReference()
    ref.elements.append(.object(childRef.dict))
    impl.syncUnkeyed()
    let childImpl = _JSONEncodeImpl(userInfo: impl.userInfo)
    childImpl.objectRef = childRef
    return KeyedEncodingContainer(
      _JSONKeyedEncodingContainer<NestedKey>(impl: childImpl, ref: childRef))
  }

  func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
    let childRef = _ArrayReference()
    ref.elements.append(.array(childRef.elements))
    impl.syncUnkeyed()
    let childImpl = _JSONEncodeImpl(userInfo: impl.userInfo)
    childImpl.arrayRef = childRef
    return _JSONUnkeyedEncodingContainer(impl: childImpl, ref: childRef)
  }

  func superEncoder() -> Encoder {
    _JSONEncodeImpl(userInfo: impl.userInfo)
  }
}

// MARK: - Single-value encoding container

struct _JSONSingleValueEncodingContainer: SingleValueEncodingContainer {
  let codingPath: [CodingKey] = []
  let impl: _JSONEncodeImpl

  init(impl: _JSONEncodeImpl) {
    self.impl = impl
  }

  mutating func encodeNil() throws { impl.json = .null }
  mutating func encode(_ value: String) throws { impl.json = .string(value) }
  mutating func encode(_ value: Bool) throws { impl.json = .boolean(value) }
  mutating func encode(_ value: Int64) throws { impl.json = .number(.integer(value)) }
  mutating func encode(_ value: Int) throws { impl.json = .number(.integer(Int64(value))) }
  mutating func encode(_ value: Double) throws { impl.json = .number(.float(value)) }
  mutating func encode(_ value: Float) throws { impl.json = .number(.float(Double(value))) }

  mutating func encode<T: Encodable>(_ value: T) throws {
    let child = _JSONEncodeImpl(userInfo: impl.userInfo)
    try value.encode(to: child)
    impl.json = child.json
  }
}
