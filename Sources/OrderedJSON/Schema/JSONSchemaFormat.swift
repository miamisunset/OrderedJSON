import Foundation

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
  import Darwin
#elseif os(Linux)
  import Glibc
#endif

// MARK: - JSON Schema Format Types

/// Represents a string format keyword value in JSON Schema.
///
/// Each format uses Foundation's built-in parsing where possible
/// (ISO8601DateFormatter, UUID, URL, inet_pton, NSRegularExpression)
/// and falls back to regex patterns for formats Foundation doesn't
/// validate strictly (date, time, email, hostname, duration).
internal enum JSONSchemaFormat: String, CaseIterable, Sendable, Hashable {
  case dateTime = "date-time"
  case date = "date"
  case time = "time"
  case duration = "duration"
  case email = "email"
  case hostname = "hostname"
  case ipv4 = "ipv4"
  case ipv6 = "ipv6"
  case uuid = "uuid"
  case uri = "uri"
  case uriReference = "uri-reference"
  case jsonPointer = "json-pointer"
  case regex = "regex"

  /// Validates that a string value conforms to this format.
  /// - Parameter value: The string to validate.
  /// - Returns: `true` if the value matches the format, `false` otherwise.
  func validate(_ value: String) -> Bool {
    switch self {
    case .dateTime: return Self.validateDateTime(value)
    case .date: return Self.validateDate(value)
    case .time: return Self.validateTime(value)
    case .duration: return Self.validateDuration(value)
    case .email: return Self.validateEmail(value)
    case .hostname: return Self.validateHostname(value)
    case .ipv4: return Self.validateIPv4(value)
    case .ipv6: return Self.validateIPv6(value)
    case .uuid: return Self.validateUUID(value)
    case .uri: return Self.validateURI(value)
    case .uriReference: return Self.validateURIReference(value)
    case .jsonPointer: return Self.validateJSONPointer(value)
    case .regex: return Self.validateRegexPattern(value)
    }
  }

  // MARK: - Format Validators

  /// RFC 3339 / ISO 8601 date-time using Foundation's ISO8601DateFormatter.
  /// Supports both `Z` timezone and `±HH:MM` offset forms, with and without
  /// fractional seconds. Uses two formatters: one without fractional seconds
  /// (for integer-second values) and one with (for sub-second values).
  private static func validateDateTime(_ value: String) -> Bool {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    if formatter.date(from: value) != nil { return true }
    let fractionalFormatter = ISO8601DateFormatter()
    fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractionalFormatter.date(from: value) != nil
  }

  /// RFC 3339 date (e.g. `2025-01-01`). Uses strict regex because
  /// Foundation's DateFormatter accepts invalid months (e.g. month 13).
  private static func validateDate(_ value: String) -> Bool {
    let pattern = #"^\d{4}-\d{2}-\d{2}$"#
    guard value.range(of: pattern, options: .regularExpression) != nil else { return false }
    // Validate month and day ranges
    let parts = value.split(separator: "-", omittingEmptySubsequences: false)
    guard parts.count == 3,
      let month = Int(parts[1]), month >= 1, month <= 12,
      let day = Int(parts[2]), day >= 1, day <= 31
    else { return false }
    return true
  }

  /// RFC 3339 time (e.g. `12:00:00Z`). Uses strict regex because
  /// Foundation's DateFormatter accepts invalid hours (e.g. hour 25).
  private static func validateTime(_ value: String) -> Bool {
    let pattern = #"^\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?$"#
    guard value.range(of: pattern, options: .regularExpression) != nil else { return false }
    // Strip timezone suffix and fractional seconds to get the base time
    let base: String
    if let dotRange = value.firstIndex(of: ".") {
      base = String(value[value.startIndex..<dotRange])
    } else if let zRange = value.firstIndex(of: "Z") {
      base = String(value[value.startIndex..<zRange])
    } else if let plusRange = value.firstIndex(of: "+") {
      base = String(value[value.startIndex..<plusRange])
    } else if let minusRange = value.firstIndex(of: "-") {
      base = String(value[value.startIndex..<minusRange])
    } else {
      base = value
    }
    let components = base.split(separator: ":", omittingEmptySubsequences: false)
    guard components.count == 3,
      let hour = Int(components[0]), hour >= 0, hour <= 23,
      let minute = Int(components[1]), minute >= 0, minute <= 59,
      let second = Int(components[2]), second >= 0, second <= 59
    else { return false }
    return true
  }

  /// ISO 8601 duration (e.g. `PT1H30M`). Custom parsing since Foundation's
  /// DateComponentsFormatter only formats durations, does not parse them.
  private static func validateDuration(_ value: String) -> Bool {
    guard value.hasPrefix("P") else { return false }
    let rest = String(value.dropFirst())
    guard !rest.isEmpty else { return false }

    // Split on T to separate date and time portions
    let parts = rest.split(separator: "T", maxSplits: 1, omittingEmptySubsequences: false)
    let datePart = String(parts[0])

    // Date part must have at least one duration designator
    let dateHasYear = datePart.contains("Y") || datePart.contains("y")
    let dateHasMonth = datePart.contains("M")  // ambiguous — could be minutes in time part
    let dateHasDay = datePart.contains("D") || datePart.contains("d")
    let dateHasWeek = datePart.contains("W") || datePart.contains("w")

    if parts.count == 1 {
      // No time portion — must have at least one date component
      return dateHasYear || dateHasMonth || dateHasDay || dateHasWeek
    }

    guard parts.count == 2 else { return false }
    let timePart = String(parts[1])
    guard !timePart.isEmpty else { return false }

    // Time part must have at least one time designator
    let timeHasHour = timePart.contains("H") || timePart.contains("h")
    let timeHasMinute = timePart.contains("M") || timePart.contains("m")
    let timeHasSecond = timePart.contains("S") || timePart.contains("s")

    return timeHasHour || timeHasMinute || timeHasSecond
  }

  /// Basic email format validation (RFC 5322-ish pattern).
  /// Foundation has no built-in email parser.
  private static func validateEmail(_ value: String) -> Bool {
    let pattern = #"^[^\s@]+@[^\s@]+\.[^\s@]+$"#
    return value.range(of: pattern, options: .regularExpression) != nil
  }

  /// RFC 1034 hostname validation via regex.
  /// Foundation's URL host parsing is inconsistent for edge cases.
  private static func validateHostname(_ value: String) -> Bool {
    let pattern =
      #"^([a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?$"#
    return value.range(of: pattern, options: .regularExpression) != nil
  }

  /// IPv4 address using inet_pton (standard POSIX API).
  private static func validateIPv4(_ value: String) -> Bool {
    var addr = sockaddr_in()
    return value.withCString { ptr in
      inet_pton(AF_INET, ptr, &addr.sin_addr) == 1
    }
  }

  /// IPv6 address using inet_pton (standard POSIX API).
  private static func validateIPv6(_ value: String) -> Bool {
    var addr = sockaddr_in6()
    return value.withCString { ptr in
      inet_pton(AF_INET6, ptr, &addr.sin6_addr) == 1
    }
  }

  /// UUID format using Foundation's UUID parser.
  private static func validateUUID(_ value: String) -> Bool {
    return UUID(uuidString: value) != nil
  }

  /// RFC 3986 URI — must have scheme and host.
  private static func validateURI(_ value: String) -> Bool {
    guard let url = URL(string: value) else { return false }
    return url.scheme != nil && url.host != nil
  }

  /// URI or relative reference — accepts any valid URL (scheme or relative).
  private static func validateURIReference(_ value: String) -> Bool {
    return URL(string: value) != nil
  }

  /// RFC 6901 JSON Pointer (unescaped form).
  private static func validateJSONPointer(_ value: String) -> Bool {
    // A JSON Pointer is either "" (root) or starts with "/"
    return value.isEmpty || value.hasPrefix("/")
  }

  /// Valid regex pattern — checks that it compiles with Foundation.
  private static func validateRegexPattern(_ value: String) -> Bool {
    return (try? NSRegularExpression(pattern: value)) != nil
  }
}
