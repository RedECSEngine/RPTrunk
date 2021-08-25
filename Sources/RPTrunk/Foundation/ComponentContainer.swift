import Foundation

public protocol ComponentContainer {
    associatedtype RP: RPSpace
    typealias Stats = RP.Stats
    var components: [Component<RP>] { get }
}

public extension ComponentContainer {
    var stats: Stats {
        components
            .compactMap { $0.getStats() }
            .reduce(.zero, +)
    }

    var cost: Stats {
        components
            .compactMap { $0.getCost() }
            .reduce(.zero, +)
    }

    var requirements: Stats {
        components
            .compactMap { $0.getRequirements() }
            .reduce(.zero, +)
    }

    var targeting: Targeting<RP> {
        for component in components {
            if let t = component.getTargeting() {
                return t
            }
        }
        return Targeting(.singleEnemy, .always)
    }

    var statusEffects: [StatusEffect<RP>] {
        components
            .flatMap { $0.getStatusEffects() }
    }

    var dischargedStatusEffects: [String] {
        components
            .flatMap { $0.getDischargedStatusEffects() }
    }

    var itemExchange: ItemExchange? {
        for component in components {
            if let exchange = component.getItemExchange() {
                return exchange
            }
        }
        return nil
    }
    
    func isEqualTo(_ b: Self) -> Bool {
        stats == b.stats
            && cost == b.cost
            && requirements == b.requirements
            && targeting == b.targeting
            && statusEffects == b.statusEffects
            && dischargedStatusEffects == b.dischargedStatusEffects
    }
}
