// MARK: - Format validation options

/// Options for controlling which string formats are validated.
///
/// By default, all formats are enabled. You can disable specific formats
/// that are not relevant for your application (e.g., `regex` for performance
/// or `json-pointer` if your schemas don't use them).
internal struct JSONSchemaFormatOptions: Hashable, Sendable {
  /// Which formats are enabled for validation.
  var enabledFormats: FormatSet
  /// Which formats are explicitly disabled (overrides `enabledFormats`).
  var disabledFormats: FormatSet

  /// Creates a new format options struct with all formats enabled.
  init() {
    self.enabledFormats = .all
    self.disabledFormats = FormatSet()
  }

  /// Returns `true` if the given format should be validated.
  func isEnabled(_ format: JSONSchemaFormat) -> Bool {
    return enabledFormats.contains(format) && !disabledFormats.contains(format)
  }

  /// A set of formats, stored compactly as a bitmask.
  struct FormatSet: Hashable, Sendable {
    private var mask: UInt16

    fileprivate init(mask: UInt16) {
      self.mask = mask
    }

    /// All formats enabled.
    static let all = FormatSet(mask: 0xFFFF)

    /// No formats enabled.
    init() { self.mask = 0 }

    /// Creates a set containing the given formats.
    init(_ formats: [JSONSchemaFormat]) {
      var m: UInt16 = 0
      for f in formats {
        m |= 1 << f.bitIndex
      }
      self.mask = m
    }

    /// Returns `true` if the given format is in this set.
    func contains(_ format: JSONSchemaFormat) -> Bool {
      return mask & (1 << format.bitIndex) != 0
    }

    /// Returns a new set that includes the given format.
    func union(_ format: JSONSchemaFormat) -> FormatSet {
      return FormatSet(mask: mask | (1 << format.bitIndex))
    }

    /// Returns a new set that excludes the given format.
    func subtracting(_ format: JSONSchemaFormat) -> FormatSet {
      return FormatSet(mask: mask & ~(1 << format.bitIndex))
    }
  }
}

extension JSONSchemaFormat {
  /// Bit index used for `FormatSet` bitmask.
  var bitIndex: UInt16 {
    switch self {
    case .dateTime: return 0
    case .date: return 1
    case .time: return 2
    case .duration: return 3
    case .email: return 4
    case .hostname: return 5
    case .ipv4: return 6
    case .ipv6: return 7
    case .uuid: return 8
    case .uri: return 9
    case .uriReference: return 10
    case .jsonPointer: return 11
    case .regex: return 12
    }
  }
}
