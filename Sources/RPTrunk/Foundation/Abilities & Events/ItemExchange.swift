/*
     Situations to handle

     - collect and immediately consume item
     - collect and store item
     - exchange item between entities (trade, steal, drop)
     - use item, to initiate an ability
 */
public struct RPItemExchange: Codable, Equatable {
    public enum Kind: Codable, Equatable {
        case transfer(RPItemId)
        case transferAll
    }

    public let kind: Kind

    public init(kind: Kind) {
        self.kind = kind
    }
}
