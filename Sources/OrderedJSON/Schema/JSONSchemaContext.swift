import Foundation

// MARK: - Evaluation context

/// Bundles the per-validation-call state that must propagate through all
/// keyword validators and recursive `validateValue` calls.
///
/// Without this struct, every keyword validator takes three separate
/// defaulted parameters (`recursionDepth`, `currentResourceURI`,
/// `dynamicScope`), making it easy to forget to forward one — exactly the
/// footgun pattern that PR #34 (recursionDepth) and PR #36
/// (currentResourceURI) hit. Consolidating into one struct ensures that
/// a single `ctx` parameter carries all of them.
internal struct EvaluationContext: Sendable {
  /// Current recursion depth (incremented at each `validateValue` call).
  var recursionDepth: Int
  /// The base URI of the resource scope currently being validated.
  /// Empty string for the root resource. Used by `resolveRef` to
  /// determine which `ResourceScope` to query.
  var currentResourceURI: String
  /// Dynamic scope stack: `$dynamicAnchor` frames encountered during
  /// validation. Innermost frame is last. Each frame is `(name, schema)`.
  var dynamicScope: [(String, JSON)]

  /// Creates a context with default values for top-level validation.
  /// - Parameters:
  ///   - recursionDepth: Starting recursion depth (usually 0).
  ///   - currentResourceURI: Starting resource URI (empty for root).
  ///   - dynamicScope: Starting dynamic scope (empty for root).
  init(
    recursionDepth: Int = 0,
    currentResourceURI: String = "",
    dynamicScope: [(String, JSON)] = []
  ) {
    self.recursionDepth = recursionDepth
    self.currentResourceURI = currentResourceURI
    self.dynamicScope = dynamicScope
  }

  /// Returns a new context with `recursionDepth` incremented by 1.
  /// The resource URI and dynamic scope are carried forward unchanged.
  func advanced() -> EvaluationContext {
    var next = self
    next.recursionDepth += 1
    return next
  }

  /// Returns a new context with `recursionDepth` incremented by 1 and
  /// `currentResourceURI` set to the given URI.
  func advanced(resourceURI: String) -> EvaluationContext {
    var next = self
    next.recursionDepth += 1
    next.currentResourceURI = resourceURI
    return next
  }

  /// Returns a new context with a `$dynamicAnchor` frame pushed onto the
  /// dynamic scope stack, `recursionDepth` incremented by 1, and
  /// `currentResourceURI` set to the given URI.
  func advanced(withAnchor name: String, schema: JSON, resourceURI: String) -> EvaluationContext {
    var next = self
    next.recursionDepth += 1
    next.currentResourceURI = resourceURI
    next.dynamicScope = dynamicScope + [(name, schema)]
    return next
  }
}
