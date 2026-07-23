public struct RPFragment<RP: RPSpace>: Codable, Equatable {
    fileprivate struct IntermediaryContainer: RPFragmentContainer {
        let fragments: [RPFragment]
    }
    
    public typealias Stats = RP.Stats

    public var stats: Stats?
    public var cost: Stats?
    public var requirements: Stats?
    public var targeting: RPTargeting<RP>?
    public var statusEffects: [RPStatusEffect<RP>]?
    public var dischargedStatusEffects: [String]?
    public var itemExchange: RPItemExchange?

    public init(stats: Stats) {
        self.stats = stats
    }

    public init(cost: Stats) {
        self.cost = cost
    }

    public init(requirements: Stats) {
        self.requirements = requirements
    }

    public init(targetType: RPTargeting<RP>) {
        targeting = targetType
    }

    public init(statusEffects: [RPStatusEffect<RP>]) {
        self.statusEffects = statusEffects
    }

    public init(dischargedStatusEffects: [String]) {
        self.dischargedStatusEffects = dischargedStatusEffects
    }

    public init(itemExchange: RPItemExchange) {
        self.itemExchange = itemExchange
    }

    public init(flattenedFrom fragments: [RPFragment]) {
        let container = IntermediaryContainer(fragments: fragments)

        stats = container.stats
        cost = container.cost
        requirements = container.requirements
        targeting = container.targeting
        statusEffects = container.statusEffects
        dischargedStatusEffects = container.dischargedStatusEffects
        itemExchange = container.itemExchange
    }

    public func getStats() -> Stats? { stats }
    public func getCost() -> Stats? { cost }
    public func getRequirements() -> Stats? { requirements }
    public func getTargeting() -> RPTargeting<RP>? { targeting }
    public func getStatusEffects() -> [RPStatusEffect<RP>] { statusEffects ?? [] }
    public func getDischargedStatusEffects() -> [String] { dischargedStatusEffects ?? [] }
    public func getItemExchange() -> RPItemExchange? { itemExchange }
}
