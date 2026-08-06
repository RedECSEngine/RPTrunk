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

    var statsCost: Stats {
        fragments
            .compactMap { $0.getStatsCost() }
            .reduce(.zero, +)
    }

    var requiredStats: Stats {
        fragments
            .compactMap { $0.getRequiredStats() }
            .reduce(.zero, +)
    }

    var requiredStatuses: [RPStatusRequirement] {
        fragments
            .flatMap { $0.getRequiredStatuses() }
    }

    var threatRequirement: RPThreatRequirement? {
        for fragment in fragments {
            if let requirement = fragment.getThreatRequirement() {
                return requirement
            }
        }
        return nil
    }

    var threatCost: RPValue {
        fragments
            .compactMap { $0.getThreatCost() }
            .reduce(0, +)
    }

    /// When in a RPFragment container, first fragment with targeting rules wins. There's no concept of combine
    /// If multiple target types is preferred it is better to use `subAbilities` on the `RPAbility`
    var targeting: RPTargeting<RP> {
        for fragment in fragments {
            if let t = fragment.getTargeting() {
                return t
            }
        }
        return RPTargeting(.all)
    }

    var statusEffects: [RPStatusEffect<RP>] {
        fragments
            .flatMap { $0.getStatusEffects() }
    }

    var dischargedStatusEffects: [RPStatusTag] {
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
            && statsCost == b.statsCost
            && requiredStats == b.requiredStats
            && requiredStatuses == b.requiredStatuses
            && threatRequirement == b.threatRequirement
            && threatCost == b.threatCost
            && targeting == b.targeting
            && statusEffects == b.statusEffects
            && dischargedStatusEffects == b.dischargedStatusEffects
    }
}
