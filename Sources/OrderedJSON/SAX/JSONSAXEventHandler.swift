import Foundation

/// Event handler protocol for SAX-style JSON parsing.
///
/// SAX (Simple API for XML/JSON) parsing avoids constructing a full JSON
/// tree in memory. Instead, each structural element is reported to the
/// handler as it is encountered.
///
/// Each method returns `true` to continue parsing or `false` to stop early.
/// Returning `false` from any method immediately stops the parse without
/// reporting an error — useful for validation where you want to reject
/// at the first problem.
///
/// ## Example
///
/// ```swift
/// class Collector: JSONSAXEventHandler {
///   var events: [(String, String)] = []
///   func null() -> Bool { events.append(("null", "")); return true }
///   func string(_ v: String) -> Bool { events.append(("string", v)); return true }
///   // ... other callbacks
/// }
/// JSON.saxParse(#"{"key":"value"}"#, handler: Collector())
/// ```
public protocol JSONSAXEventHandler {
  /// Called when a JSON `null` value is parsed.
  func null() -> Bool
  /// Called when a JSON boolean value is parsed.
  func boolean(_ value: Bool) -> Bool
  /// Called when a JSON integer value is parsed.
  func integer(_ value: Int64) -> Bool
  /// Called when a JSON floating-point value is parsed.
  /// - Parameters:
  ///   - value: The parsed double value.
  ///   - string: The original string representation.
  func float(_ value: Double, string: String) -> Bool
  /// Called when a JSON string value is parsed.
  func string(_ value: String) -> Bool
  /// Called when a JSON object `{` is parsed.
  func startObject() -> Bool
  /// Called when a JSON object key is parsed.
  func key(_ value: String) -> Bool
  /// Called when a JSON object `}` is parsed.
  func endObject() -> Bool
  /// Called when a JSON array `[` is parsed.
  func startArray() -> Bool
  /// Called when a JSON array `]` is parsed.
  func endArray() -> Bool
  /// Called when a parse error is encountered.
  ///
  /// The error is recoverable — the handler can choose to continue
  /// or stop. Returning `false` stops parsing; returning `true`
  /// attempts to continue (may produce further errors).
  func parseError(_ error: JSONParseError, data: Data) -> Bool
}
