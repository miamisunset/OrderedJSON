/// A validation error with hierarchical sub-errors, used in verbose output mode.
///
/// In verbose mode, composition keywords (like `allOf`, `anyOf`, `oneOf`) and
/// conditional keywords (`if`/`then`/`else`) produce nested error trees showing
/// exactly which subschema failed and why.
public struct VerboseError: Hashable, Sendable, CustomStringConvertible {
  /// The primary error from the failing keyword.
  public let error: JSONSchemaError

  /// Sub-errors from nested keywords (e.g., subschemas in `allOf`).
  public let children: [VerboseError]

  /// Creates a hierarchical validation error.
  public init(error: JSONSchemaError, children: [VerboseError] = []) {
    self.error = error
    self.children = children
  }

  public var description: String {
    if children.isEmpty {
      return error.description
    }
    let childrenDesc = children.map { $0.description }.joined(separator: ", ")
    return "\(error.description) → [\(childrenDesc)]"
  }
}

/// The result of validating a JSON document against a JSON Schema,
/// supporting both basic and verbose output modes.
///
/// In basic mode (`OutputMode.basic`), `errors` contains a flat list of
/// validation errors. In verbose mode (`OutputMode.verbose`), use
/// `verboseErrors` for hierarchical error trees with nested sub-errors.
///
/// Wraps a `JSONSchemaResult` for the common flat-error surface and adds
/// `verboseErrors` for hierarchical error trees.
public struct VerboseResult: Hashable, Sendable {
  /// The underlying flat validation result.
  public let base: JSONSchemaResult

  /// Hierarchical errors for verbose mode. Empty in basic mode.
  public let verboseErrors: [VerboseError]

  /// `true` if the document passed all schema validation rules.
  public var valid: Bool { base.valid }

  /// Flat list of errors (always populated, regardless of mode).
  public var errors: [JSONSchemaError] { base.errors }

  /// Creates a validation result with both flat and verbose errors.
  public init(valid: Bool, errors: [JSONSchemaError], verboseErrors: [VerboseError] = []) {
    self.base = JSONSchemaResult(valid: valid, errors: errors)
    self.verboseErrors = verboseErrors
  }

  /// Convenience: throws the first error if validation failed.
  /// - Throws: `JSONSchemaError` — the first validation error.
  public func throwOnError() throws {
    try base.throwOnError()
  }
}
