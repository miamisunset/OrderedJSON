import Foundation
import OrderedCollections

/// A JSON Pointer (RFC 6901) reference into a JSON value.
public struct JSONPointer: Hashable, Sendable {
  public let segments: [String]

  public init(_ path: String) throws {
    // Parse the path into segments
    guard path.hasPrefix("/") || path.isEmpty else {
      throw JSONError.invalidString  // placeholder — define proper error
    }
    if path.isEmpty {
      segments = []
      return
    }
    segments = path.dropFirst().split(separator: "/", omittingEmptySubsequences: false).map {
      String($0).replacingOccurrences(of: "~1", with: "/").replacingOccurrences(of: "~0", with: "~")
    }
  }

  public init(segments: [String]) {
    self.segments = segments
  }

  /// Resolve this pointer against a JSON value.
  public func resolve(_ json: JSON) -> JSON? {
    var current = json
    for segment in segments {
      if let index = Int(segment) {
        guard case .array(let arr) = current.storage else { return nil }
        guard index >= 0, index < arr.count else { return nil }
        current = arr[index]
      } else {
        guard case .object(let dict) = current.storage else { return nil }
        guard let value = dict[segment] else { return nil }
        current = value
      }
    }
    return current
  }

  /// Set a value at this pointer path (creating intermediate objects/arrays as needed).
  public func set(into json: inout JSON, value: JSON) {
    // TODO: implement set
  }
}
