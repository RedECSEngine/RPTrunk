import Foundation

public protocol ComponentContainer {
    var components: [Component] { get }
}

public extension ComponentContainer {
    var stats: Stats {
        return components
            .flatMap { $0.getStats() }
            .reduce(Stats(), +)
    }

    var cost: Stats {
        return components
            .flatMap { $0.getCost() }
            .reduce(Stats(), +)
    }

    var requirements: Stats {
        return components
            .flatMap { $0.getRequirements() }
            .reduce(Stats(), +)
    }

    var targeting: Targeting {
        for component in components {
            if let t = component.getTargeting() {
                return t
            }
        }
        return Targeting(.singleEnemy, .always)
    }

    var statusEffects: [StatusEffect] {
        return components
            .flatMap { $0.getStatusEffects() }
    }

    var dischargedStatusEffects: [String] {
        return components
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
}

func == (a: ComponentContainer, b: ComponentContainer) -> Bool {
    return a.stats == b.stats
        && a.cost == b.cost
        && a.requirements == b.requirements
        && a.targeting == b.targeting
        && a.statusEffects == b.statusEffects
        && a.dischargedStatusEffects == b.dischargedStatusEffects
}
