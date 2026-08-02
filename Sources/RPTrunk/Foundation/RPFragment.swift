public struct RPFragment<RP: RPSpace>: Codable, Equatable {
    fileprivate struct IntermediaryContainer: RPFragmentContainer {
        let fragments: [RPFragment]
    }

    public typealias Stats = RP.Stats

    /// Stats applied to the body or ability
    public var stats: Stats?
    /// Cost in stats that will be removed events
    public var statsCost: Stats?
    /// Minimum required stats to use this
    public var requiredStats: Stats?
    /// Statuses the body must have to use this (or not have)
    public var requiredStatuses: [RPStatusRequirement]?
    /// Minimum/maximum threat among all bodies in current space to use this
    public var threatRequirement: RPThreatRequirement?
    /// Threat change with all targets during events
    public var threatCost: RPValue?
    /// Modifications the targeting behaviour, when in a RPFragment container, first fragment with targeting rules wins
    public var targeting: RPTargeting<RP>?
    /// status effect given/applied
    public var statusEffects: [RPStatusEffect<RP>]?
    /// Status types removed
    public var dischargedStatusEffects: [RPStatusCode]?
    
    /// Items that will be exchanged during event
    public var itemExchange: RPItemExchange?

    public init(stats: Stats) {
        self.stats = stats
    }

    public init(statsCost: Stats) {
        self.statsCost = statsCost
    }

    public init(requiredStats: Stats) {
        self.requiredStats = requiredStats
    }

    public init(requiredStatuses: [RPStatusRequirement]) {
        self.requiredStatuses = requiredStatuses
    }

    public init(threatRequirement: RPThreatRequirement) {
        self.threatRequirement = threatRequirement
    }

    public init(threatCost: RPValue) {
        self.threatCost = threatCost
    }

    public init(targetType: RPTargeting<RP>) {
        targeting = targetType
    }

    public init(statusEffects: [RPStatusEffect<RP>]) {
        self.statusEffects = statusEffects
    }

    public init(dischargedStatusEffects: [RPStatusCode]) {
        self.dischargedStatusEffects = dischargedStatusEffects
    }

    public init(itemExchange: RPItemExchange) {
        self.itemExchange = itemExchange
    }

    public init(flattenedFrom fragments: [RPFragment]) {
        let container = IntermediaryContainer(fragments: fragments)

        stats = container.stats
        statsCost = container.statsCost
        requiredStats = container.requiredStats
        requiredStatuses = container.requiredStatuses
        threatRequirement = container.threatRequirement
        threatCost = container.threatCost
        targeting = container.targeting
        statusEffects = container.statusEffects
        dischargedStatusEffects = container.dischargedStatusEffects
        itemExchange = container.itemExchange
    }

    public func getStats() -> Stats? { stats }
    public func getStatsCost() -> Stats? { statsCost }
    public func getRequiredStats() -> Stats? { requiredStats }
    public func getRequiredStatuses() -> [RPStatusRequirement] { requiredStatuses ?? [] }
    public func getThreatRequirement() -> RPThreatRequirement? { threatRequirement }
    public func getThreatCost() -> RPValue? { threatCost }
    public func getTargeting() -> RPTargeting<RP>? { targeting }
    public func getStatusEffects() -> [RPStatusEffect<RP>] { statusEffects ?? [] }
    public func getDischargedStatusEffects() -> [RPStatusCode] { dischargedStatusEffects ?? [] }
    public func getItemExchange() -> RPItemExchange? { itemExchange }
}
