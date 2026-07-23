public protocol RPFragmentContainer {
    associatedtype RP: RPSpace
    typealias Stats = RP.Stats
    var fragments: [RPFragment<RP>] { get }
}

public extension RPFragmentContainer {
    var stats: Stats {
        fragments
            .compactMap { $0.getStats() }
            .reduce(.zero, +)
    }

    var cost: Stats {
        fragments
            .compactMap { $0.getCost() }
            .reduce(.zero, +)
    }

    var requirements: Stats {
        fragments
            .compactMap { $0.getRequirements() }
            .reduce(.zero, +)
    }

    var targeting: RPTargeting<RP> {
        for fragment in fragments {
            if let t = fragment.getTargeting() {
                return t
            }
        }
        return RPTargeting(.singleEnemy, .always)
    }

    var statusEffects: [RPStatusEffect<RP>] {
        fragments
            .flatMap { $0.getStatusEffects() }
    }

    var dischargedStatusEffects: [String] {
        fragments
            .flatMap { $0.getDischargedStatusEffects() }
    }

    var itemExchange: RPItemExchange? {
        for fragment in fragments {
            if let exchange = fragment.getItemExchange() {
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
