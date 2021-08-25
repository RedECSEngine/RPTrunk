import Foundation

public struct Component<RP: RPSpace>: Codable, Equatable {
    fileprivate struct IntermediaryContainer: ComponentContainer {
        let components: [Component]
    }
    
    public typealias Stats = RP.Stats

    public var stats: Stats?
    public var cost: Stats?
    public var requirements: Stats?
    public var targeting: Targeting<RP>?
    public var statusEffects: [StatusEffect<RP>]?
    public var dischargedStatusEffects: [String]?
    public var itemExchange: ItemExchange?

    public init(stats: Stats) {
        self.stats = stats
    }

    public init(cost: Stats) {
        self.cost = cost
    }

    public init(requirements: Stats) {
        self.requirements = requirements
    }

    public init(targetType: Targeting<RP>) {
        targeting = targetType
    }

    public init(statusEffects: [StatusEffect<RP>]) {
        self.statusEffects = statusEffects
    }

    public init(dischargedStatusEffects: [String]) {
        self.dischargedStatusEffects = dischargedStatusEffects
    }

    public init(itemExchange: ItemExchange) {
        self.itemExchange = itemExchange
    }

    public init(flattenedFrom components: [Component]) {
        let container = IntermediaryContainer(components: components)

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
    public func getTargeting() -> Targeting<RP>? { targeting }
    public func getStatusEffects() -> [StatusEffect<RP>] { statusEffects ?? [] }
    public func getDischargedStatusEffects() -> [String] { dischargedStatusEffects ?? [] }
    public func getItemExchange() -> ItemExchange? { itemExchange }
}
