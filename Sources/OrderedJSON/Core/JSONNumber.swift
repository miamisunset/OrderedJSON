import OrderedCollections

public enum JSONNumber: Hashable, Sendable {
  case integer(Int64)
  case float(Double)
}
