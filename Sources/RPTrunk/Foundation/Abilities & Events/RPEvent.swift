public struct RPEventResult<RP: RPSpace>: Equatable, Codable {
    public let event: RPEvent<RP>
    public let effects: [RPConflictResult<RP>]
    public let itemTransfers: [RPItemTransfer]
    public var subResults: [RPEventResult<RP>] = []

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
        case triggered
    }

    public var id = UUID().uuidString
    public let category: Category
    public let ability: RPAbility<RP>
    public let targets: Set<RPBodyId>
    public let initiator: RPBodyId?
    public let subEvents: [RPEvent<RP>]

    /// Composes an event and, eagerly, the sub-events its ability declares.
    ///
    /// Explicit `targets` bypass the ability's targeting for *this* event only —
    /// sub-events always resolve their own rules, which is why `reactingTo` is a
    /// separate parameter rather than something folded into `targets`: it is
    /// handed down the whole tree so a reaction's sub-ability can aim at the
    /// attacker too.
    ///
    /// `initiator` is who performs this event; `reactingTo` is the event being
    /// answered. Both are bodies-adjacent and easy to confuse, so note that the
    /// `.initiator` *targeting selector* reads the latter's initiator, never
    /// this one.
    public init(
        category: Category = .standardConflict,
        initiator: RPBodyId,
        ability: RPAbility<RP>,
        targets: Set<RPBodyId>? = nil,
        reactingTo triggeringEvent: RPEvent<RP>? = nil,
        rpSpace: RP
    ) {
        self.category = category
        self.initiator = initiator
        self.ability = ability
        self.targets = targets
            ?? ability.targeting.getValidTargets(
                for: initiator,
                in: rpSpace,
                reactingTo: triggeringEvent
            )
        self.subEvents = ability.subAbilities.map {
            RPEvent(
                category: category,
                initiator: initiator,
                ability: $0,
                reactingTo: triggeringEvent,
                rpSpace: rpSpace
            )
        }
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
        self.subEvents = []
    }

    func getStats() -> Stats {
        ability.stats
    }

    func getCost() -> Stats {
        ability.statsCost * -1
    }

    // MARK: - Results calculation and application
    public func predictedResults(in rpSpace: RP) -> RPEventResult<RP> {
        var result = RPEventResult(self, self.getResults(in: rpSpace))
        result.subResults = subEvents.map { $0.predictedResults(in: rpSpace) }
        return result
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
                body.statusEffects[name]?.didPulse()
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
        var eventResult = RPEventResult<RP>(self, results, itemTransfers)
        rpSpace.applyThreatChanges(
            declaredThreatChanges() + RP.resolveThreatChanges(for: eventResult, in: rpSpace)
        )
        eventResult.subResults = subEvents.map { $0.execute(in: &rpSpace) }
        return eventResult
    }

    /// Commits an already-resolved result to the space — the second half of
    /// `execute`, with the rolling half skipped.
    ///
    /// Randomness is reused and determinism is recomputed: the
    /// `RPConflictResult`s carry dice that were thrown when the result was
    /// produced and must not be thrown twice, while status effects, item
    /// exchange and threat re-run here because they are functions of the state
    /// being written to, which has moved on since.
    ///
    /// This is what lets a forecast resolve a whole chain up front and then pay
    /// it out one node at a time as each animation lands.
    @discardableResult
    public func apply(
        _ resolved: RPEventResult<RP>,
        in rpSpace: inout RP
    ) -> RPEventResult<RP> {
        let itemTransfers = applyResults(resolved.effects, in: &rpSpace)
        var eventResult = RPEventResult<RP>(self, resolved.effects, itemTransfers)
        rpSpace.applyThreatChanges(
            declaredThreatChanges() + RP.resolveThreatChanges(for: eventResult, in: rpSpace)
        )
        eventResult.subResults = zip(subEvents, resolved.subResults).map {
            $0.apply($1, in: &rpSpace)
        }
        return eventResult
    }

    private func declaredThreatChanges() -> [RPThreatChange] {
        let threatCost = ability.threatCost
        guard threatCost != 0, let initiator = initiator else { return [] }
        return targets.flatMap { target in
            [
                RPThreatChange(holder: target, toward: initiator, delta: threatCost),
                RPThreatChange(holder: initiator, toward: target, delta: threatCost),
            ]
        }
    }

    public func resetInitiatorCooldowns(in rpSpace: inout RP) {
        guard let initiator = initiator else { return }
        rpSpace.modifyBody(id: initiator) { e, _ in
            e.resetCooldown()
            e.resetAbility(byName: ability.code)
        }
    }
}
