public struct RPLootTableJSON<RP: RPSpace>: Codable, Equatable {
    public var maxItemsDropped: Int?
    public var items: [RPLootTableItemJSON<RP>]?
}

public struct RPLootTableItemJSON<RP: RPSpace>: Codable, Equatable {
    public var itemCode: String
    public var chance: RPValue?
    public var amountMin: Int?
    public var amountMax: Int?
    public var variation: RPLootVariationJSON<RP>?
}

public struct RPLootVariationJSON<RP: RPSpace>: Codable, Equatable {
    public var maximumFragments: Int?
    public var fragments: [FragmentVariationJSON<RP>]?
}

public struct FragmentVariationJSON<RP: RPSpace>: Codable, Equatable {
    public var fragment: RPFragmentSetJSON<RP>
    public var variableStats: RP.Stats?
    public var chance: RPValue?
}
