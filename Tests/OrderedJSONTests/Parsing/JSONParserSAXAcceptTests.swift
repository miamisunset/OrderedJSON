import Foundation
import Testing

@testable import OrderedJSON

@Suite("Parser SAX accept tests")
struct JSONParserSAXAcceptTests {
  @Test("accept rejects lone minus")
  func acceptRejectsLoneMinus() {
    #expect(JSON.accept("-") == false)
  }

  @Test("accept rejects leading zero")
  func acceptRejectsLeadingZero() {
    #expect(JSON.accept("01") == false)
  }

  @Test("accept accepts valid values")
  func acceptAcceptsValidValues() {
    #expect(JSON.accept("null"))
    #expect(JSON.accept("true"))
    #expect(JSON.accept("42"))
    #expect(JSON.accept("\"hi\""))
    #expect(JSON.accept("{}"))
    #expect(JSON.accept("[]"))
    #expect(JSON.accept(#"{"k":"v"}"#))
    #expect(JSON.accept("[1,2]"))
  }

  @Test("accept rejects invalid values")
  func acceptRejectsInvalidValues() {
    #expect(JSON.accept("") == false)
    #expect(JSON.accept("invalid") == false)
    #expect(JSON.accept("{") == false)
    #expect(JSON.accept("[") == false)
    #expect(JSON.accept("}") == false)
    #expect(JSON.accept("]") == false)
  }

  @Test("accept rejects incomplete number")
  func acceptRejectsIncompleteNumber() {
    #expect(JSON.accept("-") == false)
    #expect(JSON.accept("0.") == false)
    #expect(JSON.accept("1.e") == false)
    #expect(JSON.accept("1.0e+") == false)
  }
}
