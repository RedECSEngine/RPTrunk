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
    public var itemCode: RPReferenceCode
    public var chance: Int
    public var amount: Range<Int>
    public var requiredVariations: [RPFragmentVariation<RP>]
    public var optionalVariations: [RPFragmentVariation<RP>]
    public var maxNumberOfOptionalStats: Int

    public init(
        itemCode: RPReferenceCode,
        chance: Int = RPChance.certain,
        amount: Range<Int> = 1 ..< 2,
        requiredVariations: [RPFragmentVariation<RP>] = [],
        optionalVariations: [RPFragmentVariation<RP>] = [],
        maxNumberOfOptionalStats: Int = 0
    ) {
        self.itemCode = itemCode
        self.chance = chance
        self.amount = amount
        self.requiredVariations = requiredVariations
        self.optionalVariations = optionalVariations
        self.maxNumberOfOptionalStats = maxNumberOfOptionalStats
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
