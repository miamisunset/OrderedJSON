import Testing

@testable import OrderedJSON

@Test func readmeDynamicMemberLookup() throws {
  let json = try JSON.parse(#"{"user": {"name": "Alice", "age": 30}}"#)

  #expect(json.user.name == JSON.string("Alice"))
  #expect(json.user.age == JSON.number(.integer(30)))

  #expect(json.missingKey == JSON.null)

  var mutable = json
  mutable.user.name = JSON.string("Bob")
  #expect(mutable.user.name == JSON.string("Bob"))
}

@Test func readmeSendable() throws {
  let json = try JSON.parse("{\"key\": \"value\"}")
  // Verify it's Sendable by passing across a Task
  Task {
    let value = json["key"]
    #expect(value == JSON.string("value"))
  }
}
