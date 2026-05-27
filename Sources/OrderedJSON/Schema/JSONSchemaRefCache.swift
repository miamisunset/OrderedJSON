import Foundation

/// A thread-safe cache for resolved `$ref` targets.
/// Key is `resourceURI + "::" + refString`.
internal final class RefCache: @unchecked Sendable {
  private let lock = NSLock()
  private var cache: [String: ResolvedRef] = [:]

  func get(_ key: String) -> ResolvedRef? {
    lock.lock()
    defer { lock.unlock() }
    return cache[key]
  }

  func set(_ key: String, _ value: ResolvedRef) {
    lock.lock()
    defer { lock.unlock() }
    cache[key] = value
  }
}
