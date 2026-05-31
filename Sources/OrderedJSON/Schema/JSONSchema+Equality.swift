import Foundation
import OrderedCollections

extension JSONSchema {

  // MARK: - Schema-aware equality

  /// Compares two JSON values using schema-aware equality semantics.
  /// Integers compare equal to equal floats (`1` == `1.0`). Objects compare
  /// by key-value pairs ignoring key order.
  static func schemaEqual(_ lhs: JSON, _ rhs: JSON) -> Bool {
    switch (lhs.storage, rhs.storage) {
    case (.null, .null): return true
    case (.boolean(let a), .boolean(let b)): return a == b
    case (.number(.integer(let a)), .number(.integer(let b))): return a == b
    case (.number(.float(let a)), .number(.float(let b))): return a == b
    case (.number(.integer(let a)), .number(.float(let b))): return Double(a) == b
    case (.number(.float(let a)), .number(.integer(let b))): return a == Double(b)
    case (.string(let a), .string(let b)):
      // Compare at Unicode scalar level, not canonical equivalence
      let sa = a.unicodeScalars
      let sb = b.unicodeScalars
      guard sa.count == sb.count else { return false }
      for (scalarA, scalarB) in zip(sa, sb) {
        if scalarA.value != scalarB.value { return false }
      }
      return true
    case (.array(let a), .array(let b)):
      guard a.count == b.count else { return false }
      for (i, elem) in a.enumerated() {
        if !schemaEqual(elem, b[i]) { return false }
      }
      return true
    case (.object(let a), .object(let b)):
      guard a.count == b.count else { return false }
      for (key, value) in a {
        guard let bVal = b[key] else { return false }
        if !schemaEqual(value, bVal) { return false }
      }
      return true
    default: return false
    }
  }

  // MARK: - Hashable conformance (ignoring runtime caches)

  public func hash(into hasher: inout Hasher) {
    hasher.combine(draft)
    hasher.combine(compiled)
    hasher.combine(formatOptions)
    hasher.combine(outputMode)
    // refCache is excluded — it's a runtime cache, not part of schema identity.
  }

  public static func == (lhs: JSONSchema, rhs: JSONSchema) -> Bool {
    lhs.draft == rhs.draft && lhs.compiled == rhs.compiled && lhs.formatOptions == rhs.formatOptions
      && lhs.outputMode == rhs.outputMode
    // refCache is excluded.
  }
}
