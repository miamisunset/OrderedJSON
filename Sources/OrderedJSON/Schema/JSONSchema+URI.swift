import Foundation

// MARK: - RFC 3986 URI joining

extension CompiledSchema {

  /// Resolves a relative `$id` value against a parent base URI per RFC 3986.
  ///
  /// Uses Foundation's `URL` type which handles the common cases:
  /// - Absolute URIs (with scheme): returned as-is
  /// - Network-path URIs (starting with `//`): authority replaced
  /// - Absolute path URIs (starting with `/`): path+query replaced
  /// - Relative path URIs: merged with parent's path
  /// - Fragment-only URIs (`#foo`): parent URI with fragment replaced
  /// - Empty `$id` (or missing `$id`): parent URI returned unchanged
  ///
  /// - Parameters:
  ///   - child: The `$id` value from the subschema (may be empty/absent).
  ///   - parentBaseURI: The parent resource's base URI (empty for root).
  /// - Returns: The resolved absolute URI string.
  static func resolveRelativeID(_ child: String?, parentBaseURI: String) -> String {
    guard let child = child, !child.isEmpty else { return parentBaseURI }

    // Absolute URI — use as-is
    if let url = URL(string: child), url.scheme != nil {
      return child
    }

    // Parent is empty (root with no $id) — use child as-is
    if parentBaseURI.isEmpty {
      return child
    }

    // Resolve relative URI against parent base
    guard let base = URL(string: parentBaseURI) else { return child }
    guard let resolved = URL(string: child, relativeTo: base)?.absoluteString else { return child }
    return resolved
  }
}
