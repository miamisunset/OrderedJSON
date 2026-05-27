import OrderedCollections

/// A `CodingKey` used internally when encoding/decoding JSON objects.
///
/// Maps string keys directly without transformation — no key encoding strategy
/// is applied, preserving the original key order from the `OrderedDictionary`.
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
