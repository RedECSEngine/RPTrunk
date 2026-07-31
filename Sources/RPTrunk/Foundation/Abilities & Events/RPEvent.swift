public struct RPEventResult<RP: RPSpace>: Equatable, Codable {
    public let event: RPEvent<RP>
    public let effects: [RPConflictResult<RP>]
    public let itemTransfers: [RPItemTransfer]

    public init(_ event: RPEvent<RP>, _ effects: [RPConflictResult<RP>], _ itemTransfers: [RPItemTransfer] = []) {
        self.event = event
        self.effects = effects
        self.itemTransfers = itemTransfers
    }
}

public struct RPEvent<RP: RPSpace>: Equatable, Codable {
    public typealias Stats = RP.Stats
    public enum Category: Equatable, Codable {
        case standardConflict
        case periodicEffect(name: String)
        case itemExchangeOnly
    }

    public var id = UUID().uuidString
    public let category: Category
    public let ability: RPAbility<RP>
    public let targets: Set<RPBodyId>
    public let initiator: RPBodyId?

    public init(
        category: Category = .standardConflict,
        initiator: RPBodyId,
        ability: RPAbility<RP>,
        targets: Set<RPBodyId>? = nil,
        rpSpace: RP
    ) {
        self.category = category
        self.initiator = initiator
        self.ability = ability
        self.targets = targets ?? ability.targeting.getValidTargets(for: initiator, in: rpSpace)
    }
    
    public init(
        category: Category = .standardConflict,
        ability: RPAbility<RP>,
        targets: Set<RPBodyId>
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
    public func predictedResults(in rpSpace: RP) -> RPEventResult<RP> {
        RPEventResult(self, self.getResults(in: rpSpace))
    }

    public func getResults(in rpSpace: RP) -> [RPConflictResult<RP>] {
        var results: [RPConflictResult<RP>] = []
        
        let totalStats = getStats()
        results += targets.map { target -> RPConflictResult<RP> in
            RP.resolveConflict(
                self,
                in: rpSpace,
                target: target,
                conflict: totalStats
            )
        }
        
        if let initiator = initiator, let body = rpSpace.bodyById(initiator) {
            results.append(RP.resolveConflict(
                self,
                in: rpSpace,
                target: body.id,
                conflict: getCost()
            ))
        }
        
        return results
    }

    func applyResults(_ results: [RPConflictResult<RP>], in rpSpace: inout RP) -> [RPItemTransfer] {
        results.forEach { result -> Void in
            let newStats = (rpSpace.bodyById(result.body)?.currentStats ?? .zero) + result.change
            rpSpace.modifyBody(id: result.body, perform: { e, _ in
                e.setCurrentStats(newStats)
            })
        }
        applyStatusEffectChanges(to: targets, in: &rpSpace)
        let itemTransfers = applyItemExchange(in: &rpSpace)

        if case let .periodicEffect(name) = category, let initiator = initiator {
            rpSpace.modifyBody(id: initiator) { body, space in
                body.statusEffects[name]?.incrementTick()
            }
        }
        return itemTransfers
    }

    private func applyStatusEffectChanges(to targets: Set<RPBodyId>, in rpSpace: inout RP) {
        ability.dischargedStatusEffects
            .forEach {
                name in
                targets.forEach { target in
                    rpSpace.modifyBody(id: target) { t, _ in t.dischargeStatusEffect(name) }
                }
            }

        ability.statusEffects
            .forEach {
                se in
                targets.forEach { target in
                    rpSpace.modifyBody(id: target) { t, _ in t.applyStatusEffect(se) }
                }
            }
    }

    func applyItemExchange(in rpSpace: inout RP) -> [RPItemTransfer] {
        guard let exchange = ability.itemExchange,
              let initiator = initiator,
              let recipient = targets.first
        else { return [] }

        switch exchange.kind {
        case .transfer(let itemId):
            return rpSpace.transferItem(id: itemId, from: initiator, to: recipient)
        case .transferAll:
            return rpSpace.transferAllItems(from: initiator, to: recipient)
        }
    }

    public func execute(in rpSpace: inout RP) -> RPEventResult<RP> {
        let results = getResults(in: rpSpace)
        let itemTransfers = applyResults(results, in: &rpSpace)
        let eventResult = RPEventResult<RP>(self, results, itemTransfers)
        rpSpace.applyThreatChanges(
            RP.resolveThreatChanges(for: eventResult, in: rpSpace)
        )
        return eventResult
    }

    public func resetInitiatorCooldowns(in rpSpace: inout RP) {
        guard let initiator = initiator else { return }
        rpSpace.modifyBody(id: initiator) { e, _ in
            e.resetCooldown()
            e.resetAbility(byName: ability.code)
        }
    }
}
