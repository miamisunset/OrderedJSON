/// Represents a validation error produced during JSON Schema validation.
///
/// Each error includes the location in the instance document where the error
/// occurred, the location in the schema where the failing keyword is defined,
/// the keyword name, and a human-readable message. Optionally includes the
/// value that failed and the parent schema that produced the error.
public struct JSONSchemaError: Error, Hashable, Sendable, CustomStringConvertible {
  /// A JSON Pointer path to the value in the instance document that failed validation.
  public let instancePath: String

  /// A JSON Pointer path to the keyword in the schema that caused the failure.
  public let schemaPath: String

  /// The keyword that produced the error (e.g. `"type"`, `"minimum"`, `"required"`).
  public let keyword: String

  /// A human-readable description of the validation failure.
  public let message: String

  /// The value that failed validation, if available.
  public let failedValue: JSON?

  /// The parent schema that produced this error, if available.
  public let parentSchema: JSON?

  /// Creates a schema validation error.
  /// - Parameters:
  ///   - instancePath: JSON Pointer to the failing value in the document.
  ///   - schemaPath: JSON Pointer to the keyword in the schema.
  ///   - keyword: The keyword that failed.
  ///   - message: Human-readable error message.
  ///   - failedValue: The value that failed validation (optional).
  ///   - parentSchema: The schema that produced this error (optional).
  public init(
    instancePath: String,
    schemaPath: String,
    keyword: String,
    message: String,
    failedValue: JSON? = nil,
    parentSchema: JSON? = nil
  ) {
    self.instancePath = instancePath
    self.schemaPath = schemaPath
    self.keyword = keyword
    self.message = message
    self.failedValue = failedValue
    self.parentSchema = parentSchema
  }

  public var description: String {
    "[\(keyword)] \(message) — instance: \(instancePath), schema: \(schemaPath)"
  }
}
