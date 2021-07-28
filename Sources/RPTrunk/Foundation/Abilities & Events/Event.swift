import Foundation

public struct EventResult: Equatable {
    public let event: Event
    public let effects: [ConflictResult]

    init(_ event: Event, _ effects: [ConflictResult]) {
        self.event = event
        self.effects = effects
    }
}

public struct Event: Equatable {
    public enum Category: Equatable {
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
        guard let entity = rpSpace.entityById(initiator) else {
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

    func applyResults<RP: RPSpace>(_ results: [ConflictResult], in rpSpace: inout RP) {
        results.forEach { result -> Void in
            let newStats = (rpSpace.entityById(result.entity)?.allCurrentStats() ?? [:]) + result.change
            rpSpace.modifyEntity(id: result.entity, perform: {
                $0.setCurrentStats(newStats)
            })
        }
        applyStatusEffectChanges(to: targets, in: &rpSpace)
        applyItemExchange(in: &rpSpace)
    }

    private func applyStatusEffectChanges<RP: RPSpace>(to targets: Set<Id<Entity>>, in rpSpace: inout RP) {
        ability.dischargedStatusEffects
            .forEach {
                name in
                targets.forEach { target in
                    rpSpace.modifyEntity(id: target) { $0.dischargeStatusEffect(name) }
                }
            }

        ability.statusEffects
            .forEach {
                se in
                targets.forEach { target in
                    rpSpace.modifyEntity(id: target) { $0.applyStatusEffect(se) }
                }
            }
    }

    func applyItemExchange<RP: RPSpace>(in rpSpace: inout RP) {
        guard let exchange = ability.itemExchange else { return }
        guard let entity = rpSpace.entityById(initiator) else { return }

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
                rpSpace.modifyEntity(id: initiator) { $0.inventory.remove(at: idx) }
            } else {
                rpSpace.modifyEntity(id: initiator) { $0.inventory[idx] = newItemState }
            }
        }

        switch exchange.exchangeType {
        case .rpSpace:
            break
//            rpSpace.inventory.append(exchange.item)
        case .target:
            if let targetId = targets.first {
                rpSpace.modifyEntity(id: targetId) { $0.inventory.append(exchange.item) }
            }
        case .targetTeam:
            if let teamId = targets.first.flatMap(rpSpace.entityById)?.teamId {
                rpSpace.modifyTeam(id: teamId) { $0.inventory.append(exchange.item) }
            } else if let targetId = targets.first {
                rpSpace.modifyEntity(id: targetId) { $0.inventory.append(exchange.item) }
            }
        }
    }

    public func execute<RP: RPSpace>(in rpSpace: inout RP) -> EventResult {
        let results = getResults(in: rpSpace)
        applyResults(results, in: &rpSpace)
        return EventResult(self, results)
    }

    public func resetCooldowns<RP: RPSpace>(in rpSpace: inout RP) {
        rpSpace.modifyEntity(id: initiator) {
            $0.resetCooldown()
            $0.resetAbility(byName: ability.name)
        }
    }
}
