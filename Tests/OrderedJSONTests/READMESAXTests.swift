import Foundation
import Testing

@testable import OrderedJSON

@Test func readmeSAX() {
  class MyHandler: JSONSAXEventHandler {
    var events: [String] = []
    func null() -> Bool {
      events.append("null")
      return true
    }
    func boolean(_ v: Bool) -> Bool {
      events.append("bool:\(v)")
      return true
    }
    func integer(_ v: Int64) -> Bool {
      events.append("int:\(v)")
      return true
    }
    func float(_ v: Double, string: String) -> Bool {
      events.append("float:\(v)")
      return true
    }
    func string(_ v: String) -> Bool {
      events.append("string:\(v)")
      return true
    }
    func startObject() -> Bool {
      events.append("{")
      return true
    }
    func key(_ v: String) -> Bool {
      events.append("key:\(v)")
      return true
    }
    func endObject() -> Bool {
      events.append("}")
      return true
    }
    func startArray() -> Bool {
      events.append("[")
      return true
    }
    func endArray() -> Bool {
      events.append("]")
      return true
    }
    func parseError(_ e: JSONParseError, data: Data) -> Bool {
      events.append("error")
      return false
    }
  }

  let handler = MyHandler()
  let ok = JSON.parse("{\"a\": 1}", handler: handler)
  #expect(ok)
  #expect(handler.events.contains("key:a"))
  #expect(handler.events.contains("int:1"))

  // accept() validation
  #expect(JSON.accept("{\"valid\": 1}"))
  #expect(JSON.accept("invalid") == false)
}
