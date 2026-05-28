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
public struct VerboseResult: Hashable, Sendable {
  /// `true` if the document passed all schema validation rules.
  public let valid: Bool

  /// Flat list of errors (always populated, regardless of mode).
  public let errors: [JSONSchemaError]

  /// Hierarchical errors for verbose mode. Empty in basic mode.
  public let verboseErrors: [VerboseError]

  /// Creates a validation result with both flat and verbose errors.
  public init(valid: Bool, errors: [JSONSchemaError], verboseErrors: [VerboseError] = []) {
    self.valid = valid
    self.errors = errors
    self.verboseErrors = verboseErrors
  }

  /// Convenience: throws the first error if validation failed.
  /// - Throws: `JSONSchemaError` — the first validation error.
  public func throwOnError() throws {
    if let first = errors.first {
      throw first
    }
  }
}
