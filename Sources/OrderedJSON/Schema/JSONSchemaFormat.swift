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
public enum JSONSchemaFormat: String, CaseIterable, Sendable, Hashable {
    case dateTime = "date-time"
    case date
    case time
    case duration
    case email
    case hostname
    case ipv4
    case ipv6
    case uuid
    case uri
    case uriReference = "uri-reference"
    case jsonPointer = "json-pointer"
    case regex

    /// Bit index used for `JSONSchemaFormatOptions.FormatSet` bitmask.
    public var bitIndex: UInt16 {
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

    /// Validates that a string value conforms to this format.
    /// - Parameter value: The string to validate.
    /// - Returns: `true` if the value matches the format, `false` otherwise.
    public func validate(_ value: String) -> Bool {
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

    private static func _dateFormatter() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }

    private static func _dateFormatterFractional() -> ISO8601DateFormatter {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }

    /// RFC 3339 / ISO 8601 date-time using Foundation's ISO8601DateFormatter.
    /// Supports both `Z` timezone and `±HH:MM` offset forms, with and without
    /// fractional seconds. Caches the two formatters as static lazy vars.
    private static func validateDateTime(_ value: String) -> Bool {
        let f1 = _dateFormatter()
        if f1.date(from: value) != nil { return true }
        let f2 = _dateFormatterFractional()
        return f2.date(from: value) != nil
    }

    /// RFC 3339 date (e.g. `2025-01-01`). Uses strict regex because
    /// Foundation's DateFormatter accepts invalid months (e.g. month 13).
    /// Also validates month-aware day ranges (Feb 30 is rejected).
    private static func validateDate(_ value: String) -> Bool {
        let pattern = #"^\d{4}-\d{2}-\d{2}$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else { return false }
        let parts = value.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]), month >= 1, month <= 12,
              let day = Int(parts[2]), day >= 1
        else { return false }
        // Month-aware day limits
        let maxDay: Int
        switch month {
        case 2:
            // February — 28 days in non-leap years, 29 in leap years
            let isLeap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            maxDay = isLeap ? 29 : 28
        case 4, 6, 9, 11:
            maxDay = 30
        default:
            maxDay = 31
        }
        return day <= maxDay
    }

    /// RFC 3339 time (e.g. `12:00:00Z`). Uses strict regex because
    /// Foundation's DateFormatter accepts invalid hours (e.g. hour 25).
    private static func validateTime(_ value: String) -> Bool {
        let pattern = #"^\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?$"#
        guard value.range(of: pattern, options: .regularExpression) != nil else { return false }
        // Strip timezone suffix and fractional seconds to get the base time
        let base: String
        if let dotRange = value.firstIndex(of: ".") {
            base = String(value[value.startIndex ..< dotRange])
        } else if let zRange = value.firstIndex(of: "Z") {
            base = String(value[value.startIndex ..< zRange])
        } else if let plusRange = value.firstIndex(of: "+") {
            base = String(value[value.startIndex ..< plusRange])
        } else if let minusRange = value.firstIndex(of: "-") {
            // Only strip if '-' is part of a timezone offset, not a negative time
            // (RFC 3339 times don't have negative values, so '-' always means offset)
            base = String(value[value.startIndex ..< minusRange])
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

    /// ISO 8601 duration (e.g. `PT1H30M`). Uses regex to validate the
    /// full duration string, ensuring each designator is preceded by a number.
    private static func validateDuration(_ value: String) -> Bool {
        // Full ISO 8601 duration pattern with at-least-one-component requirement:
        // - Date form: P<num>Y, P<num>M, P<num>D, P<num>W, or combinations
        // - Time form: PT<num>H, PT<num>M, PT<num>S, or combinations
        // - Combined: P<num>Y<T<num>H, etc.
        // At least one component must be present (rejects bare P and PT).
        let pattern =
            #"^P(?:\d+(?:[YyMmDdWw]))(?:\d+(?:[YyMmDd]))*"#
                + #"(?:T(?:\d+(?:[HhMmSs]))(?:\d+(?:[HhMmSs]))*)?$"# + #"|^P(?:\d+[Ww])$"#
                + #"|^PT(?:\d+(?:[HhMmSs]))(?:\d+(?:[HhMmSs]))*$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }

    /// Basic email format validation (RFC 5322-ish pattern).
    /// Requires at least one character before @, a domain with at least one dot,
    /// and at least one character after the dot (non-empty TLD).
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
