public struct EventResult<RP: RPSpace>: Equatable, Codable {
    public let event: Event<RP>
    public let effects: [ConflictResult<RP>]
    public let itemTransfers: [ItemTransfer]

    init(_ event: Event<RP>, _ effects: [ConflictResult<RP>], _ itemTransfers: [ItemTransfer] = []) {
        self.event = event
        self.effects = effects
        self.itemTransfers = itemTransfers
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
        targets: Set<RPEntityId>? = nil,
        rpSpace: RP
    ) {
        self.category = category
        self.initiator = initiator
        self.ability = ability
        self.targets = targets ?? ability.targeting.getValidTargets(for: initiator, in: rpSpace)
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

    func applyResults(_ results: [ConflictResult<RP>], in rpSpace: inout RP) -> [ItemTransfer] {
        results.forEach { result -> Void in
            let newStats = (rpSpace.entityById(result.entity)?.currentStats ?? .zero) + result.change
            rpSpace.modifyEntity(id: result.entity, perform: {
                $0.setCurrentStats(newStats, in: $1)
            })
        }
        applyStatusEffectChanges(to: targets, in: &rpSpace)
        let itemTransfers = applyItemExchange(in: &rpSpace)

        if case let .periodicEffect(name) = category, let initiator = initiator {
            rpSpace.modifyEntity(id: initiator) { entity, space in
                entity.statusEffects[name]?.incrementTick()
            }
        }
        return itemTransfers
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

    func applyItemExchange(in rpSpace: inout RP) -> [ItemTransfer] {
        guard let exchange = ability.itemExchange,
              let initiator = initiator,
              let recipient = targets.first
        else { return [] }

        switch exchange.kind {
        case .transfer(let itemId):
            guard rpSpace.itemById(itemId)?.entity == initiator else { return [] }
            return rpSpace.transferItem(id: itemId, to: recipient)
        case .transferAll:
            return rpSpace.transferAllItems(from: initiator, to: recipient)
        }
    }

    public func execute(in rpSpace: inout RP) -> EventResult<RP> {
        let results = getResults(in: rpSpace)
        let itemTransfers = applyResults(results, in: &rpSpace)
        let eventResult = EventResult<RP>(self, results, itemTransfers)
        rpSpace.applyThreatChanges(
            RP.resolveThreatChanges(for: eventResult, in: rpSpace)
        )
        return eventResult
    }

    public func resetInitiatorCooldowns(in rpSpace: inout RP) {
        guard let initiator = initiator else { return }
        rpSpace.modifyEntity(id: initiator) { e, _ in
            e.resetCooldown()
            e.resetAbility(byName: ability.code)
        }
    }
}
