import OrderedCollections

extension JSON {
    // MARK: - Throwing typed accessors

    /// Returns the string value, or throws `JSONError.typeError` if not a string.
    package func requireString() throws -> String {
        guard case let .string(s) = storage else {
            throw JSONError.typeError(expected: "string", actual: typeName)
        }
        return s
    }

    /// Returns the boolean value, or throws `JSONError.typeError` if not a boolean.
    package func requireBool() throws -> Bool {
        guard case let .boolean(b) = storage else {
            throw JSONError.typeError(expected: "boolean", actual: typeName)
        }
        return b
    }

    /// Returns the integer value as `Int64`, or throws `JSONError.typeError`.
    ///
    /// Accepts both `.integer` and `.float` (when the float is a clean integer).
    package func requireInt64() throws -> Int64 {
        switch storage {
        case let .number(.integer(i)):
            return i
        case let .number(.float(d)):
            guard let i = Int64(exactly: d) else {
                throw JSONError.typeError(expected: "integer", actual: typeName)
            }
            return i
        default:
            throw JSONError.typeError(expected: "integer", actual: typeName)
        }
    }

    /// Returns the integer value as `Int`, or throws `JSONError.typeError`.
    package func requireInt() throws -> Int {
        let i = try requireInt64()
        guard Int.max >= i && Int.min <= i else {
            throw JSONError.typeError(expected: "int", actual: typeName)
        }
        return Int(i)
    }

    /// Returns the integer value as `Int8`, or throws `JSONError.typeError` if out of range.
    package func requireInt8() throws -> Int8 {
        let i = try requireInt64()
        guard let result = Int8(exactly: i) else {
            throw JSONError.typeError(expected: "int8", actual: typeName)
        }
        return result
    }

    /// Returns the integer value as `Int16`, or throws `JSONError.typeError` if out of range.
    package func requireInt16() throws -> Int16 {
        let i = try requireInt64()
        guard let result = Int16(exactly: i) else {
            throw JSONError.typeError(expected: "int16", actual: typeName)
        }
        return result
    }

    /// Returns the integer value as `Int32`, or throws `JSONError.typeError` if out of range.
    package func requireInt32() throws -> Int32 {
        let i = try requireInt64()
        guard let result = Int32(exactly: i) else {
            throw JSONError.typeError(expected: "int32", actual: typeName)
        }
        return result
    }

    /// Returns the numeric value as `UInt`, or throws `JSONError.typeError`.
    package func requireUInt() throws -> UInt {
        let i = try requireInt64()
        guard let result = UInt(exactly: i) else {
            throw JSONError.typeError(expected: "uint", actual: typeName)
        }
        return result
    }

    /// Returns the numeric value as `UInt8`, or throws `JSONError.typeError`.
    package func requireUInt8() throws -> UInt8 {
        let i = try requireInt64()
        guard let result = UInt8(exactly: i) else {
            throw JSONError.typeError(expected: "uint8", actual: typeName)
        }
        return result
    }

    /// Returns the numeric value as `UInt16`, or throws `JSONError.typeError`.
    package func requireUInt16() throws -> UInt16 {
        let i = try requireInt64()
        guard let result = UInt16(exactly: i) else {
            throw JSONError.typeError(expected: "uint16", actual: typeName)
        }
        return result
    }

    /// Returns the numeric value as `UInt32`, or throws `JSONError.typeError`.
    package func requireUInt32() throws -> UInt32 {
        let i = try requireInt64()
        guard let result = UInt32(exactly: i) else {
            throw JSONError.typeError(expected: "uint32", actual: typeName)
        }
        return result
    }

    /// Returns the numeric value as `UInt64`, or throws `JSONError.typeError`.
    package func requireUInt64() throws -> UInt64 {
        let i = try requireInt64()
        guard let result = UInt64(exactly: i) else {
            throw JSONError.typeError(expected: "uint64", actual: typeName)
        }
        return result
    }

    /// Returns the float value as `Double`, or throws `JSONError.typeError`.
    ///
    /// Accepts both `.float` and `.integer` (widening the integer to Double).
    package func requireDouble() throws -> Double {
        switch storage {
        case let .number(.float(d)):
            return d
        case let .number(.integer(i)):
            return Double(i)
        default:
            throw JSONError.typeError(expected: "float", actual: typeName)
        }
    }

    /// Returns the float value as `Float`, or throws `JSONError.typeError`.
    ///
    /// Accepts both `.float` and `.integer` (widening). Uses lossless
    /// conversion via `Float(exactly:)` — rejects values that are not
    /// exactly representable as `Float` (e.g., `0.1`). For Foundation-compatible
    /// lossy narrowing, use `requireDouble()` and cast manually.
    /// Rejects `.infinity` and subnormal values.
    package func requireFloat() throws -> Float {
        let d = try requireDouble()
        guard let result = Float(exactly: d), result.isFinite else {
            throw JSONError.typeError(expected: "float", actual: typeName)
        }
        return result
    }

    // MARK: - Generic get<T>()

    /// Type-safe value extraction by requesting a specific Swift type.
    ///
    /// Dispatches to the appropriate `require*()` method based on `T`:
    /// - `String` → `requireString()`
    /// - `Bool` → `requireBool()`
    /// - `Int64`, `Int`, `Int8`, `Int16`, `Int32` → corresponding `requireInt*()`,
    ///   all delegating to bounds-checked `Int64` extraction
    /// - `UInt`, `UInt8`, `UInt16`, `UInt32`, `UInt64` → `requireUInt*()`
    /// - `Double` → `requireDouble()`
    /// - `Float` → `requireFloat()`
    ///
    /// - Parameter type: The desired Swift type.
    /// - Returns: The value converted to `T`.
    /// - Throws: `JSONError.typeError` on type mismatch.
    public func get<T>(_: T.Type) throws -> T {
        // Safe: each branch is guarded by `T.self == X.self` above, so the
        // `as! T` force-cast is guaranteed to succeed.
        if T.self == String.self {
            return try requireString() as! T
        }
        if T.self == Bool.self {
            return try requireBool() as! T
        }
        if T.self == Double.self {
            return try requireDouble() as! T
        }
        if T.self == Float.self {
            return try requireFloat() as! T
        }
        if T.self == Int64.self {
            return try requireInt64() as! T
        }
        if T.self == Int.self {
            return try requireInt() as! T
        }
        if T.self == Int32.self {
            return try requireInt32() as! T
        }
        if T.self == Int16.self {
            return try requireInt16() as! T
        }
        if T.self == Int8.self {
            return try requireInt8() as! T
        }
        if T.self == UInt.self {
            return try requireUInt() as! T
        }
        if T.self == UInt8.self {
            return try requireUInt8() as! T
        }
        if T.self == UInt16.self {
            return try requireUInt16() as! T
        }
        if T.self == UInt32.self {
            return try requireUInt32() as! T
        }
        if T.self == UInt64.self {
            return try requireUInt64() as! T
        }
        throw JSONError.typeError(expected: "\(T.self)", actual: typeName)
    }
}
