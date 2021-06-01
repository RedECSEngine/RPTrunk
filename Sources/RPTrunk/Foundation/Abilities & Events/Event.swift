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
    public let targets: Set<Id<Entity>>

    public private(set) var initiator: Id<Entity>

    public init(
        category: Category = .standardConflict,
        initiator: Entity,
        ability: Ability,
        rpSpace: RPSpace
    ) {
        self.category = category
        self.initiator = initiator.id
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

    public func getResults(in rpSpace: RPSpace) -> [ConflictResult] {
        guard let entity = rpSpace.entities[initiator] else {
            return []
        }
        
        let totalStats = getStats()
        let results = targets.map { target -> ConflictResult in
            RPGameEnvironment.current.delegate.resolveConflict(
                self,
                in: rpSpace,
                target: target,
                conflict: totalStats
            )
        }
        let costResult = RPGameEnvironment.current.delegate.resolveConflict(
            self,
            in: rpSpace,
            target: entity.id,
            conflict: getCost()
        )
        return results + [costResult]
    }

    func applyResults(_ results: [ConflictResult], in rpSpace: RPSpace) {
        results.forEach { result -> Void in
            let newStats = (rpSpace.entities[result.entity]?.allCurrentStats() ?? [:]) + result.change
            rpSpace.entities[result.entity]?.setCurrentStats(newStats)
        }
        applyStatusEffectChanges(to: targets, in: rpSpace)
        applyItemExchange(in: rpSpace)
    }

    private func applyStatusEffectChanges(to targets: Set<Id<Entity>>, in rpSpace: RPSpace) {
        ability.dischargedStatusEffects
            .forEach {
                name in
                targets.forEach {
                    rpSpace.entities[$0]?.dischargeStatusEffect(name)
                }
            }

        ability.statusEffects
            .forEach {
                se in
                targets.forEach {
                    rpSpace.entities[$0]?.applyStatusEffect(se)
                }
            }
    }

    func applyItemExchange(in rpSpace: RPSpace) {
        guard let exchange = ability.itemExchange else { return }
        guard let entity = rpSpace.entities[initiator] else { return }

        if exchange.requiresInitiatorOwnItem,
           entity.inventory.contains(where: { $0.name == exchange.item.name }) == false
        {
            // should not exchange since initiator does not currently own the item
            return
        }

        if exchange.removesItemFromInitiator,
           let idx = entity.inventory.firstIndex(where: { $0.name == exchange.item.name })
        {
            var newItemState = entity.inventory[idx]
            newItemState.amount -= 1
            if newItemState.amount <= 0 {
                rpSpace.entities[initiator]?.inventory.remove(at: idx)
            } else {
                rpSpace.entities[initiator]?.inventory[idx] = newItemState
            }
        }

        switch exchange.exchangeType {
        case .rpSpace:
            rpSpace.inventory.append(exchange.item)
        case .target:
            if let targetId = targets.first {
                rpSpace.entities[targetId]?.inventory.append(exchange.item)
            }
        case .targetTeam:
            if let teamId = targets.first.flatMap({ rpSpace.entities[$0] })?.teamId {
                rpSpace.teams[teamId]?.inventory.append(exchange.item)
            } else if let targetId = targets.first.flatMap({ rpSpace.entities[$0] })?.id {
                rpSpace.entities[targetId]?.inventory.append(exchange.item)
            }
        }
    }

    public func execute(in rpSpace: RPSpace) -> EventResult {
        let results = getResults(in: rpSpace)
        applyResults(results, in: rpSpace)
        return EventResult(self, results)
    }

    public func resetCooldowns(in rpSpace: RPSpace) {
        rpSpace.entities[initiator]?.resetCooldown()
        // reset cooldown if it is an executable
        rpSpace.entities[initiator]?.resetAbility(byName: ability.name)
    }
}
