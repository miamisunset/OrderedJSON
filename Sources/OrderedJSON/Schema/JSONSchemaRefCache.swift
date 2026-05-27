import Foundation

/// A thread-safe cache for resolved `$ref` targets.
/// Key is `resourceURI + "::" + refString`.
///
/// Uses `NSLock` for thread safety.  `OSAllocatedLock` (macOS 13+/iOS 16+)
/// would be faster but is not available on the current Swift version.
final class RefCache: @unchecked Sendable {
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
