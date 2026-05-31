import Testing

@testable import OrderedJSON

@Suite("Builder Round Trip Tests") struct JSONBuilderRoundTripTests {

  @Test("builder round trip with encoder decoder") func builderRoundTripWithEncoderDecoder() throws
  {
    struct Person: Codable {
      let name: String
      let age: Int
      let tags: [String]
    }

    let json = JSON.ObjectBuilder()
      .set("name", "Alice")
      .set("age", 30)
      .set(
        "tags",
        JSON.ArrayBuilder()
          .add("admin")
          .add("user")
      )
      .build()

    let decoder = OrderedJSONDecoder()
    let person = try decoder.decode(Person.self, from: json)
    #expect(person.name == "Alice")
    #expect(person.age == 30)
    #expect(person.tags == ["admin", "user"])
  }
}
