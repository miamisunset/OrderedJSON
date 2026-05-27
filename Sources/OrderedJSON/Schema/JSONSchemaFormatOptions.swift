// MARK: - Format validation options

/// Options for controlling which string formats are validated.
///
/// By default, all formats are enabled. You can disable specific formats
/// that are not relevant for your application (e.g., `regex` for performance
/// or `json-pointer` if your schemas don't use them).
public struct JSONSchemaFormatOptions: Hashable, Sendable {
    /// Which formats are enabled for validation.
    public var enabledFormats: FormatSet
    /// Which formats are explicitly disabled (overrides `enabledFormats`).
    public var disabledFormats: FormatSet

    /// Creates a new format options struct with all formats enabled.
    public init() {
        enabledFormats = .all
        disabledFormats = FormatSet()
    }

    /// Returns `true` if the given format should be validated.
    public func isEnabled(_ format: JSONSchemaFormat) -> Bool {
        return enabledFormats.contains(format) && !disabledFormats.contains(format)
    }

    /// Disables validation for the given format.
    public mutating func disable(_ format: JSONSchemaFormat) {
        disabledFormats = disabledFormats.union(format)
    }

    /// Re-enables validation for the given format (removes from disabled set).
    public mutating func enable(_ format: JSONSchemaFormat) {
        disabledFormats = disabledFormats.subtracting(format)
    }

    /// A set of formats, stored compactly as a bitmask.
    public struct FormatSet: Hashable, Sendable {
        private var mask: UInt16

        fileprivate init(mask: UInt16) {
            self.mask = mask
        }

        /// All formats enabled.
        public static let all = FormatSet(mask: 0xFFFF)

        /// No formats enabled.
        public init() {
            mask = 0
        }

        /// Creates a set containing the given formats.
        public init(_ formats: [JSONSchemaFormat]) {
            var m: UInt16 = 0
            for f in formats {
                m |= 1 << f.bitIndex
            }
            mask = m
        }

        /// Returns `true` if the given format is in this set.
        public func contains(_ format: JSONSchemaFormat) -> Bool {
            return mask & (1 << format.bitIndex) != 0
        }

        /// Returns a new set that includes the given format.
        public func union(_ format: JSONSchemaFormat) -> FormatSet {
            return FormatSet(mask: mask | (1 << format.bitIndex))
        }

        /// Returns a new set that excludes the given format.
        public func subtracting(_ format: JSONSchemaFormat) -> FormatSet {
            return FormatSet(mask: mask & ~(1 << format.bitIndex))
        }
    }
}
