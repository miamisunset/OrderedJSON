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
struct EvaluationContext {
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
    /// Set of enabled keywords from the schema's $vocabulary metaschema.
    /// If nil, all keywords are enabled. If non-nil, only keywords in this
    /// set should be validated. Propagated to nested subschemas.
    var enabledKeywords: Set<String>?

    /// Creates a context with default values for top-level validation.
    init(
        recursionDepth: Int = 0,
        currentResourceURI: String = "",
        dynamicScope: [DynamicAnchorFrame] = []
    ) {
        self.recursionDepth = recursionDepth
        self.currentResourceURI = currentResourceURI
        parentResourceURI = currentResourceURI
        self.dynamicScope = dynamicScope
        enabledKeywords = nil
    }

    func advanced() -> EvaluationContext {
        var next = self
        next.recursionDepth += 1
        return next
    }

    /// Advances the context for a *remote* `$ref` resolution.
    /// Sets both `currentResourceURI` and `parentResourceURI` to the new URI,
    /// meaning subsequent `$id` resolution will use the new URI as the parent.
    func advanced(resourceURI: String) -> EvaluationContext {
        var next = self
        next.recursionDepth += 1
        next.currentResourceURI = resourceURI
        next.parentResourceURI = resourceURI
        return next
    }

    /// Advances the context for a *local* `$ref` resolution.
    /// Only `currentResourceURI` is updated; `parentResourceURI` stays unchanged.
    /// This preserves the original parent URI so that nested `$id` values
    /// resolve against the correct base (the original resource, not the ref target).
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

    func withEnabledKeywords(_ keywords: Set<String>?) -> EvaluationContext {
        var next = self
        next.enabledKeywords = keywords
        return next
    }
}

// MARK: - Dynamic anchor frame

/// A single `$dynamicAnchor` frame on the dynamic scope stack.
/// Named tuple that carries `name` and `schema`, enabling `Equatable`/`Hashable`
/// conformance for future memoization.
struct DynamicAnchorFrame: Hashable {
    let name: String
    let schema: JSON
}
