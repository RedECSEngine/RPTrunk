import Foundation

public struct EventResult<RP: RPSpace>: Equatable {
    public let event: Event<RP>
    public let effects: [ConflictResult<RP>]

    init(_ event: Event<RP>, _ effects: [ConflictResult<RP>]) {
        self.event = event
        self.effects = effects
    }
}

public struct Event<RP: RPSpace>: Equatable, Codable {
    public typealias Stats = RP.Stats
    public enum Category: Equatable, Codable {
        case standardConflict
        case periodicEffect(name: String)
        case itemExchangeOnly
    }

    public var id = UUID().uuidString
    public let category: Category
    public let ability: Ability<RP>
    public let targets: Set<RPEntityId>
    public let initiator: RPEntityId?

    public init(
        category: Category = .standardConflict,
        initiator: RPEntityId,
        ability: Ability<RP>,
        rpSpace: RP
    ) {
        self.category = category
        self.initiator = initiator
        self.ability = ability
        self.targets = ability.targeting.getValidTargets(for: initiator, in: rpSpace)
    }
    
    public init(
        category: Category = .standardConflict,
        ability: Ability<RP>,
        targets: Set<RPEntityId>
    ) {
        self.category = category
        self.initiator = nil
        self.ability = ability
        self.targets = targets
    }

    func getStats() -> Stats {
        ability.stats
    }

    func getCost() -> Stats {
        ability.cost * -1
    }

    // MARK: - Results calculation and application

    public func getResults(in rpSpace: RP) -> [ConflictResult<RP>] {
        var results: [ConflictResult<RP>] = []
        
        let totalStats = getStats()
        results += targets.map { target -> ConflictResult<RP> in
            RP.resolveConflict(
                self,
                in: rpSpace,
                target: target,
                conflict: totalStats
            )
        }
        
        if let initiator = initiator, let entity = rpSpace.entityById(initiator) {
            results.append(RP.resolveConflict(
                self,
                in: rpSpace,
                target: entity.id,
                conflict: getCost()
            ))
        }
        
        return results
    }

    func applyResults(_ results: [ConflictResult<RP>], in rpSpace: inout RP) {
        results.forEach { result -> Void in
            let newStats = (rpSpace.entityById(result.entity)?.currentStats ?? .zero) + result.change
            rpSpace.modifyEntity(id: result.entity, perform: {
                $0.setCurrentStats(newStats, in: $1)
            })
        }
        applyStatusEffectChanges(to: targets, in: &rpSpace)
        applyItemExchange(in: &rpSpace)
        
        if case let .periodicEffect(name) = category, let initiator = initiator {
            rpSpace.modifyEntity(id: initiator) { entity, space in
                entity.statusEffects[name]?.incrementTick()
            }
        }
    }

    private func applyStatusEffectChanges(to targets: Set<RPEntityId>, in rpSpace: inout RP) {
        ability.dischargedStatusEffects
            .forEach {
                name in
                targets.forEach { target in
                    rpSpace.modifyEntity(id: target) { t, _ in t.dischargeStatusEffect(name) }
                }
            }

        ability.statusEffects
            .forEach {
                se in
                targets.forEach { target in
                    rpSpace.modifyEntity(id: target) { t, _ in t.applyStatusEffect(se) }
                }
            }
    }

    func applyItemExchange(in rpSpace: inout RP) {
        guard let exchange = ability.itemExchange else { return }
        
        if let initiator = initiator, let entity = rpSpace.entityById(initiator) {
            if exchange.requiresInitiatorOwnItem {
                if entity.inventory.contains(where: { $0 == exchange.item }) == false {
                    // should not exchange since initiator does not currently own the item
                    return
                }
                if var newItemState = rpSpace.itemById(exchange.item) {
                    newItemState.amount -= 1
                    if newItemState.amount <= 0 {
                        rpSpace.modifyEntity(id: initiator) { e, _ in e.inventory.removeAll(where: { $0 == exchange.item }) }
                    }
                    rpSpace.modifyItem(id: exchange.item, perform: { i, _ in i = newItemState })
                }
            }
        }
    
        switch exchange.exchangeType {
        case .target:
            if let targetId = targets.first {
                rpSpace.modifyEntity(id: targetId) { e, _ in e.inventory.append(exchange.item) }
            }
        case .targetTeam:
            if let teamId = targets.first.flatMap(rpSpace.entityById)?.teamId {
                rpSpace.modifyTeam(id: teamId) { t, _ in t.inventory.append(exchange.item) }
            } else if let targetId = targets.first {
                rpSpace.modifyEntity(id: targetId) { e, _ in e.inventory.append(exchange.item) }
            }
        }
    }

    public func execute(in rpSpace: inout RP) -> EventResult<RP> {
        let results = getResults(in: rpSpace)
        applyResults(results, in: &rpSpace)
        return EventResult<RP>(self, results)
    }

    public func resetInitiatorCooldowns(in rpSpace: inout RP) {
        guard let initiator = initiator else { return }
        rpSpace.modifyEntity(id: initiator) { e, _ in
            e.resetCooldown()
            e.resetAbility(byName: ability.name)
        }
    }
}
