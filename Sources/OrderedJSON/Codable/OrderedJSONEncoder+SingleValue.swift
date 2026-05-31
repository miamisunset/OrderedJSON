import Foundation

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
    guard !value.isNaN && !value.isInfinite else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "\(value) is not representable as a JSON number"
        )
      )
    }
    impl.json = .number(.float(value))
    impl.syncKeyed()
  }

  mutating func encode(_ value: Float) throws {
    guard !value.isNaN && !value.isInfinite else {
      throw EncodingError.invalidValue(
        value,
        EncodingError.Context(
          codingPath: codingPath,
          debugDescription: "\(value) is not representable as a JSON number"
        )
      )
    }
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
