/// The result of validating a JSON document against a JSON Schema.
///
/// Use `valid` to check whether validation succeeded, and `errors` to inspect
/// individual validation failures.
public struct JSONSchemaResult: Hashable, Sendable {
  /// `true` if the document passed all schema validation rules.
  public let valid: Bool

  /// The list of validation errors. Empty when `valid` is `true`.
  public let errors: [JSONSchemaError]

  /// Creates a validation result.
  /// - Parameters:
  ///   - valid: Whether validation passed.
  ///   - errors: Validation errors (empty for success).
  public init(valid: Bool, errors: [JSONSchemaError]) {
    self.valid = valid
    self.errors = errors
  }

  /// Convenience: throws the first error if validation failed, or does nothing
  /// on success. Useful with `try` for early exit on first failure.
  /// - Throws: `JSONSchemaError` — the first validation error.
  public func throwIfInvalid() throws {
    if let first = errors.first {
      throw first
    }
  }
}
