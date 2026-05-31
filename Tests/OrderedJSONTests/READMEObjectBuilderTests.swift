import Testing

@testable import OrderedJSON

@Test func readmeObjectBuilder() {
  let person = JSON.ObjectBuilder()
    .set("name", "Alice")
    .set("age", 30)
    .set("active", true)
    .set("pi", 3.14)
    .build()
  #expect(person.isObject)
  #expect(person.count == 4)
  #expect(person["name"] == JSON.string("Alice"))
}

@Test func readmeObjectBuilderNested() {
  let nested = JSON.ObjectBuilder()
    .set("name", "Alice")
    .set(
      "address",
      JSON.ObjectBuilder()
        .set("city", "NYC")
        .set("zip", "10001")
        .build()
    )
    .set(
      "tags",
      JSON.ArrayBuilder()
        .add("admin")
        .add("user")
        .build()
    )
    .build()
  #expect(nested.isObject)
  #expect(nested.count == 3)
}
