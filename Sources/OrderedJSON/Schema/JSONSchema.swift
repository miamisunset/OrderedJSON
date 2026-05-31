import Foundation
import OrderedCollections

/// A compiled JSON Schema that can validate JSON documents against a schema.
///
/// Supports Draft 2020-12 (primary) and Draft 7 (backward compatibility).
///
/// ## Creating a schema
///
/// ```swift
/// let schemaJSON: JSON = .object([
///   "type": .string("object"),
///   "properties": .object([
///     "name": .object(["type": .string("string")]),
///     "age":  .object(["type": .string("integer"), "minimum": .number(.integer(0))])
///   ]),
///   "required": .array([.string("name")])
/// ])
///
/// let schema = try JSONSchema(schema: schemaJSON)
/// ```
///
/// ## Validating a document
///
/// ```swift
/// let doc: JSON = .object(["name": .string("Alice"), "age": .number(.integer(30))])
/// try schema.validate(doc)  // throws on first error
///
/// let result = schema.validating(doc)  // collect all errors
/// print(result.valid)  // true
/// ```
///
/// Remote schemas can be pre-registered for `$ref` resolution:
///
/// ```swift
/// let schema = try JSONSchema(schema: schemaJSON, remoteSchemas: [
///   "http://example.com/schema.json": someRemoteSchemaJSON
/// ])
/// ```
///
/// - Warning: Two semantically-equivalent schemas with differently-ordered keys
///   will produce different `Hashable` values, since `JSON` hashing is
///   structure-preserving.
public struct JSONSchema: Hashable, Sendable {
  /// The JSON Schema draft version to use for validation.
  public enum Draft: Hashable, Sendable {
    /// JSON Schema Draft 7 (2018). Widely deployed, used by OpenAPI 3.0.
    case draft7
    /// JSON Schema Draft 2020-12 (2022). The current standard.
    case draft202012
    /// Auto-detect the draft from the schema's `$schema` keyword.
    /// Defaults to `.draft202012` if no `$schema` is present.
    case auto
  }

  /// The schema JSON that was provided at init.
  let schemaJSON: JSON
  /// The resolved draft version.
  let draft: Draft
  /// The compiled schema with resolved `$ref`, `$defs`, `$id`, `$anchor`.
  let compiled: CompiledSchema?
  /// Cache for resolved `$ref` targets to avoid repeated resolution.
  let refCache: RefCache?
  /// Remote compiled schemas pre-registered for `$ref` resolution, keyed by
  /// URL. When a `$ref` cannot be resolved locally, these are consulted.
  let remoteCompiled: [String: CompiledSchema]
  /// Options for format validation (which formats to enable/disable).
  let formatOptions: JSONSchemaFormatOptions

  /// The output mode for validation results.
  let outputMode: OutputMode

  /// Controls the detail level of validation results.
  ///
  /// - `.basic` (default): flat list of errors with path, keyword, message.
  /// - `.verbose`: hierarchical errors grouped by schema path, with failed
  ///   value and parent schema information.
  public enum OutputMode: Hashable, Sendable {
    /// Flat list of errors with instance path, schema path, keyword, message.
    case basic
    /// Hierarchical errors with nested sub-errors for composition keywords.
    case verbose
  }

  /// Creates a compiled JSON Schema from a JSON representation.
  ///
  /// The schema JSON is validated internally — malformed schemas (e.g., invalid
  /// regex patterns, non-object schemas) throw an error during init.
  ///
  /// - Parameters:
  ///   - schema: The JSON representation of the schema.
  ///   - draft: The draft version to use. Defaults to `.auto`.
  ///   - formatOptions: Options for format validation. Defaults to all enabled.
  ///   - outputMode: The output mode for validation results. Defaults to `.basic`.
  ///   - remoteSchemas: Remote schemas pre-registered for `$ref` resolution,
  ///     keyed by URL. These are compiled internally for efficient resolution.
  ///     Defaults to empty.
  /// - Throws: `JSONSchemaError` if the schema itself is invalid.
  public init(
    schema: JSON, draft: Draft = .auto,
    formatOptions: JSONSchemaFormatOptions = JSONSchemaFormatOptions(),
    outputMode: OutputMode = .basic,
    remoteSchemas: [String: JSON] = [:]
  ) throws {
    // Detect draft from $schema if auto
    let resolvedDraft: Draft
    if draft == .auto {
      resolvedDraft = JSONSchema.detectDraft(from: schema)
    } else {
      resolvedDraft = draft
    }

    // Validate schema structure
    guard schema.isObject || schema.isBoolean else {
      throw JSONSchemaError(
        instancePath: "",
        schemaPath: "",
        keyword: "schema",
        message: "Schema must be a JSON object or boolean"
      )
    }

    // Pre-compile regex patterns so invalid regexes fail at init time
    // rather than during validation. Boolean schemas have no patterns.
    if schema.isObject {
      try JSONSchema.validatePatterns(schema)
    }

    // Compile the schema for $defs, $ref, $id, $anchor support
    let compiled: CompiledSchema?
    if schema.isObject {
      compiled = try CompiledSchema(schema: schema)
    } else {
      compiled = nil
    }

    // Create a ref cache for faster $ref resolution at runtime.
    let refCache: RefCache?
    if compiled != nil {
      refCache = RefCache()
    } else {
      refCache = nil
    }

    // Compile remote schemas for efficient resolution.
    // Also register all resource URIs from each remote schema so that
    // $ref to URIs defined via $id within the remote schema resolve.
    var remoteCompiled: [String: CompiledSchema] = [:]
    for (url, remoteJSON) in remoteSchemas {
      if remoteJSON.isObject {
        do {
          let compiled = try CompiledSchema(schema: remoteJSON)
          // Register the file URL itself
          remoteCompiled[url] = compiled
          // Also register all resource URIs from this remote schema.
          // Each resource URI (including empty string for root) is resolved
          // against the file URL to form the absolute key.
          for (resourceURI, _) in compiled.resources {
            let absoluteURI = CompiledSchema.resolveRelativeID(resourceURI, parentBaseURI: url)
            remoteCompiled[absoluteURI] = compiled
          }
        } catch {
          // Skip invalid remote schemas silently
        }
      }
    }
    self.remoteCompiled = remoteCompiled

    schemaJSON = schema
    self.draft = resolvedDraft
    self.compiled = compiled
    self.refCache = refCache
    self.formatOptions = formatOptions
    self.outputMode = outputMode
  }
}
