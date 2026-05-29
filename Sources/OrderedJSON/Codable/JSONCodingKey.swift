import OrderedCollections

/// A `CodingKey` used internally when encoding/decoding JSON objects.
///
/// Maps string keys directly without transformation — no key encoding strategy
/// is applied, preserving the original key order from the `OrderedDictionary`.
///
/// Supports both string-keyed and integer-keyed containers via the two
/// initializers. Integer keys are serialized as their decimal string representation.
struct JSONCodingKey: CodingKey {
  let stringValue: String
  let intValue: Int?

  init(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init(intValue: Int) {
    stringValue = "\(intValue)"
    self.intValue = intValue
  }
}
