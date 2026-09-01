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
