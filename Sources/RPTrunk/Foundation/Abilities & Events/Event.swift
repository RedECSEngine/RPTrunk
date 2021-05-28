import Foundation

public struct EventResult {
    public let event: Event
    public let effects: [ConflictResult]

    init(_ event: Event, _ effects: [ConflictResult]) {
        self.event = event
        self.effects = effects
    }
}

public struct Event {
    public enum Category {
        case standardConflict
        case periodicEffect
        case itemExchangeOnly
    }

    public let id = UUID().uuidString
    public let category: Category
    public let ability: Ability
    public let targets: Set<Entity>

    public private(set) weak var initiator: Entity!

    public init(
        category: Category = .standardConflict,
        initiator: Entity,
        ability: Ability,
        rpSpace: RPSpace
    ) {
        self.category = category
        self.initiator = initiator
        self.ability = ability
        targets = ability.targeting.getValidTargets(for: initiator, in: rpSpace)
    }

    func getStats() -> Stats {
        ability.stats
    }

    func getCost() -> Stats {
        ability.cost * -1
    }

    // MARK: - Results calculation and application

    public func getResults() -> [ConflictResult] {
        let totalStats = getStats()
        let results = targets.map { target -> ConflictResult in
            RPGameEnvironment.current.delegate.resolveConflict(self, target: target, conflict: totalStats)
        }
        let costResult = RPGameEnvironment.current.delegate.resolveConflict(self, target: initiator, conflict: getCost())
        return results + [costResult]
    }

    func applyResults(_ results: [ConflictResult], in rpSpace: RPSpace) {
        results.forEach { result -> Void in
            let newStats = result.entity.allCurrentStats() + result.change
            result.entity.setCurrentStats(newStats)
        }
        applyStatusEffectChanges(to: targets)
        applyItemExchange(in: rpSpace)
    }

    private func applyStatusEffectChanges(to targets: Set<Entity>) {
        ability.dischargedStatusEffects
            .forEach {
                name in
                targets.forEach { $0.dischargeStatusEffect(name) }
            }

        ability.statusEffects
            .forEach {
                se in
                targets.forEach { $0.applyStatusEffect(se) }
            }
    }

    func applyItemExchange(in rpSpace: RPSpace) {
        guard let exchange = ability.itemExchange else { return }

        if exchange.requiresInitiatorOwnItem,
           initiator.inventory.contains(where: { $0.name == exchange.item.name }) == false
        {
            // should not exchange since initiator does not currently own the item
            return
        }

        if exchange.removesItemFromInitiator,
           let idx = initiator.inventory.index(where: { $0.name == exchange.item.name })
        {
            var newItemState = initiator.inventory[idx]
            newItemState.amount -= 1
            if newItemState.amount <= 0 {
                initiator.inventory.remove(at: idx)
            } else {
                initiator.inventory[idx] = newItemState
            }
        }

        switch exchange.exchangeType {
        case .rpSpace:
            rpSpace.inventory.append(exchange.item)
        case .target:
            targets.first?.inventory.append(exchange.item)
        case .targetTeam:
            if let teamId = targets.first?.teamId {
                rpSpace.teams[teamId]?.inventory.append(exchange.item)
            } else {
                targets.first?.inventory.append(exchange.item)
            }
        }
    }

    public func execute(in rpSpace: RPSpace) -> EventResult {
        let results = getResults()
        applyResults(results, in: rpSpace)
        return EventResult(self, results)
    }

    public func resetCooldowns() {
        initiator.resetCooldown()
        // reset cooldown if it is an executable
        initiator.resetAbility(byName: ability.name)
    }
}
