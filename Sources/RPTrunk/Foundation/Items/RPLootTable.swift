public struct RPLootTable<RP: RPSpace>: Codable, Equatable, Sendable {
    public var code: RPReferenceCode
    public var items: [RPLootTableItem<RP>]
    public var maxItemsDropped: Int

    public init(code: RPReferenceCode, items: [RPLootTableItem<RP>], maxItemsDropped: Int) {
        self.code = code
        self.items = items
        self.maxItemsDropped = maxItemsDropped
    }
}

public struct RPLootTableItem<RP: RPSpace>: Codable, Equatable, Sendable {
    public enum Kind: Codable, Equatable, Sendable {
        case fixed
        case variant(RPLootVariation<RP>)
    }
    public var itemCode: RPReferenceCode
    public var chance: Int
    public var amount: Range<Int>
    public var kind: Kind

    public init(itemCode: RPReferenceCode, chance: Int, amount: Range<Int>, kind: Kind) {
        self.itemCode = itemCode
        self.chance = chance
        self.amount = amount
        self.kind = kind
    }
}

public struct RPLootResult<RP: RPSpace>: Codable, Equatable, Sendable {
    public var items: [RPActiveItem<RP>]

    public init(items: [RPActiveItem<RP>]) {
        self.items = items
    }
}

public struct RPFragmentVariation<RP: RPSpace>: Codable, Equatable, Sendable {
    public var fragment: RPFragment<RP>
    public var variableStats: RP.Stats?
    public var chance: Int

    public init(fragment: RPFragment<RP>, variableStats: RP.Stats?, chance: Int) {
        self.fragment = fragment
        self.variableStats = variableStats
        self.chance = chance
    }
}

public struct RPLootVariation<RP: RPSpace>: Codable, Equatable, Sendable {
    public var fragments: [RPFragmentVariation<RP>]
    public var maximumFragments: Int

    public init(fragments: [RPFragmentVariation<RP>], maximumFragments: Int) {
        self.fragments = fragments
        self.maximumFragments = maximumFragments
    }
}
