import OrderedCollections

extension JSON {
  // MARK: - Throwing typed accessors

  /// Returns the string value, or throws `JSONError.typeError` if not a string.
  func requireString() throws -> String {
    guard case .string(let s) = storage else {
      throw JSONError.typeError(expected: "string", actual: typeName)
    }
    return s
  }

  /// Returns the boolean value, or throws `JSONError.typeError` if not a boolean.
  func requireBool() throws -> Bool {
    guard case .boolean(let b) = storage else {
      throw JSONError.typeError(expected: "boolean", actual: typeName)
    }
    return b
  }

  /// Returns the integer value as `Int64`, or throws `JSONError.typeError` if not an integer.
  func requireInt64() throws -> Int64 {
    guard case .number(.integer(let i)) = storage else {
      throw JSONError.typeError(expected: "integer", actual: typeName)
    }
    return i
  }

  /// Returns the integer value as `Int`, or throws `JSONError.typeError` if not an integer.
  func requireInt() throws -> Int {
    let i = try requireInt64()
    return Int(i)
  }

  /// Returns the float value as `Double`, or throws `JSONError.typeError` if not a float.
  func requireDouble() throws -> Double {
    guard case .number(.float(let d)) = storage else {
      throw JSONError.typeError(expected: "float", actual: typeName)
    }
    return d
  }

  /// Returns the float value as `Float`, or throws `JSONError.typeError` if not a float.
  func requireFloat() throws -> Float {
    let d = try requireDouble()
    return Float(d)
  }
}
