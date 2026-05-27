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
  /// The ORIGINAL parent resource URI (before $ref/$dynamicRef overwrote
  /// currentResourceURI). Used for `$id` resolution: `$id` values are
  /// resolved against this parent URI, not against currentResourceURI.
  var parentResourceURI: String
  /// Dynamic scope stack: `$dynamicAnchor` frames encountered during
  /// validation. Innermost frame is last. Each frame is `(name, schema)`.
  var dynamicScope: [DynamicAnchorFrame]

  /// Creates a context with default values for top-level validation.
  init(
    recursionDepth: Int = 0,
    currentResourceURI: String = "",
    dynamicScope: [DynamicAnchorFrame] = []
  ) {
    self.recursionDepth = recursionDepth
    self.currentResourceURI = currentResourceURI
    self.parentResourceURI = currentResourceURI
    self.dynamicScope = dynamicScope
  }

  func advanced() -> EvaluationContext {
    var next = self
    next.recursionDepth += 1
    return next
  }

  /// Normal advancement: both currentResourceURI and parentResourceURI
  /// are updated to the new resource URI. Nested subschemas inherit
  /// this as their parent.
  func advanced(resourceURI: String) -> EvaluationContext {
    var next = self
    next.recursionDepth += 1
    next.currentResourceURI = resourceURI
    next.parentResourceURI = resourceURI
    return next
  }

  /// Advancement via $ref/$dynamicRef: currentResourceURI is updated
  /// to the resolved schema's URI, but parentResourceURI stays as the
  /// ORIGINAL parent's URI. This ensures $id in the resolved schema
  /// resolves against the correct parent.
  func advancedViaRef(resourceURI: String) -> EvaluationContext {
    var next = self
    next.recursionDepth += 1
    next.currentResourceURI = resourceURI
    return next
  }

  func advanced(withAnchor name: String, schema: JSON, resourceURI: String) -> EvaluationContext {
    var next = self
    next.recursionDepth += 1
    next.currentResourceURI = resourceURI
    next.parentResourceURI = resourceURI
    next.dynamicScope = dynamicScope + [DynamicAnchorFrame(name: name, schema: schema)]
    return next
  }
}

// MARK: - Dynamic anchor frame

/// A single `$dynamicAnchor` frame on the dynamic scope stack.
/// Named tuple that carries `name` and `schema`, enabling `Equatable`/`Hashable`
/// conformance for future memoization.
internal struct DynamicAnchorFrame: Sendable, Hashable {
  let name: String
  let schema: JSON
}
