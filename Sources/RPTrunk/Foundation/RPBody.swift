import Foundation // TODO: Use foundation essentials

@dynamicMemberLookup
public struct RPBody<RP: RPSpace>: RPTemporal, Codable {

    public typealias Stats = RP.Stats
    
    public var id: RPBodyId = UUID().uuidString {
        didSet {
            updateIds()
        }
    }
    
    public var code: RPReferenceCode?
    public var displayName: String = "???"

    public var teamId: RPTeamId?

    public var currentTick: RPTimeIncrement = 0
    public var globalCooldown: RPTimeIncrement = 2500
    public var maximumTick: RPTimeIncrement { globalCooldown }

    public private(set) var baseStats: Stats = .zero
    public private(set) var currentStats: Stats = .zero
    public var equipment = RPEquipment<RP>()
    public var inventory: [RPActiveItem<RP>] = []
    public var metadata: RP.BodyMetadata?

    public internal(set) var executableAbilities: [String: RPActiveAbility<RP>] = [:]
    public internal(set) var statusEffects: [String: RPActiveStatusEffect<RP>] = [:]
    public internal(set) var triggers: [RPTrigger<RP>] = []
    public internal(set) var triggerCooldowns: [RPReferenceCode: RPTimeIncrement] = [:]

    public var targets: Set<RPBodyId> = []

    public internal(set) var threat: [RPBodyId: RPValue] = [:]

    /// Threat removed per unit of tick time. Zero (the default) disables
    /// decay entirely.
    public var threatDecayPerTick: Double = 0

    public subscript(index: String) -> RPValue {
        currentStats[index]
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<Stats, T>) -> T {
        currentStats[keyPath: keyPath]
    }

    public static func new(cache: RPCache<RP>) -> RPBody {
        RP.createDefaultBody(cache: cache)
    }

    public init(_ data: [String: RPValue]) {
        let stats = Stats(dict: data)
        baseStats = stats
        currentStats = RP.fullyResolvedStats(for: stats)
        currentTick = globalCooldown
    }

    public init() {
        self.init([:])
    }
    
    public func cumulativeStats() -> Stats {
        var totalStats = self.baseStats
        equipment.wornItems.forEach { item in
            totalStats = totalStats + item.stats
        }
        statusEffects.values.forEach { effect in
            totalStats = totalStats + effect.persistentStats
        }
        return totalStats
    }
    
    public mutating func setBaseStats(_ newStats: Stats) {
        baseStats = newStats
        currentStats = RP.fullyResolvedStats(for: newStats)
    }

    public mutating func setCurrentStats(_ newStats: Stats) {
        var newCurrentStats: [String: RPValue] = [:]
        let maxStats = RP.fullyResolvedStats(for: self)
        for type in RP.statTypes {
            newCurrentStats[type] = newStats[type] < maxStats[type] ? newStats[type] : maxStats[type]
        }
        currentStats = Stats(dict: newCurrentStats)
    }

    public func usableAbilities(in rpSpace: RP) -> [RPActiveAbility<RP>] {
        guard !isCoolingDown() else {
            return []
        }

        return executableAbilities.values
            .filter { $0.canExecute(in: rpSpace) }
    }

    public func getPossibleTargets() -> Set<RPBodyId>? {
        if targets.count > 0 {
            return targets
        }

        return nil
    }

    public func getTarget() -> RPBodyId? {
        var highestThreat = RPValue.min
        var candidates: [RPBodyId] = []
        for id in targets {
            let value = threat[id] ?? 0
            if value > highestThreat {
                highestThreat = value
                candidates = [id]
            } else if value == highestThreat {
                candidates.append(id)
            }
        }
        return candidates.min()
    }

    // MARK: - Threat

    /// Threat entries from highest to lowest, ties broken by id.
    public var threatList: [(bodyId: RPBodyId, threat: RPValue)] {
        threat
            .sorted { lhs, rhs in
                lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key
            }
            .map { (bodyId: $0.key, threat: $0.value) }
    }

    public func holdsThreat(toward id: RPBodyId) -> Bool {
        threat[id] != nil
    }

    public mutating func addThreat(toward id: RPBodyId, amount: RPValue) {
        setThreat(toward: id, amount: (threat[id] ?? 0) + amount)
    }

    public mutating func setThreat(toward id: RPBodyId, amount: RPValue) {
        if amount > 0 {
            threat[id] = amount
        } else {
            threat.removeValue(forKey: id)
        }
    }

    public mutating func clearThreat(toward id: RPBodyId) {
        threat.removeValue(forKey: id)
    }

    public mutating func addExecutableAbility(_ ability: RPAbility<RP>, conditional: RPConditional<RP>) {
        let activeAbility = RPActiveAbility<RP>(bodyId: id, ability: ability, conditional: conditional)
        executableAbilities[ability.code] = activeAbility
    }

    public mutating func addTrigger(_ trigger: RPTrigger<RP>) {
        triggers.append(trigger)
    }

    /// Every trigger this body currently answers to, paired with who owns it.
    ///
    /// Status-granted triggers are *read* from the effects the body is holding
    /// rather than copied onto it, so an expiring status takes its reactions
    /// with it and nothing has to be revoked. Effects are walked in code order
    /// so a chain built from this list is reproducible across runs.
    public var allTriggers: [(source: RPTriggerSource, trigger: RPTrigger<RP>)] {
        triggers.map { (.body, $0) }
            + statusEffects
                .sorted { $0.key < $1.key }
                .flatMap { code, active in
                    active.triggers.map { (RPTriggerSource.statusEffect(code), $0) }
                }
    }

    /// Asks whichever owner holds this trigger's clock whether it is off
    /// cooldown. A status effect keeps its own trigger cooldowns, so the body
    /// forwards rather than answering — a status must never write timing state
    /// into the body it rides on. A status that has since dropped off answers
    /// false, which is correct: its triggers are gone.
    public func isTriggerReady(_ source: RPTriggerSource, _ trigger: RPTrigger<RP>) -> Bool {
        switch source {
        case .body:
            return triggerCooldowns[trigger.code] == nil
        case let .statusEffect(code):
            return statusEffects[code]?.isTriggerReady(trigger) ?? false
        }
    }

    /// Starts a fired trigger's cooldown on whichever owner holds it, mirroring
    /// `isTriggerReady`. Body-declared triggers land in the body's own map;
    /// status-granted ones are pushed back into the effect that brought them.
    public mutating func startTriggerCooldown(_ source: RPTriggerSource, _ trigger: RPTrigger<RP>) {
        switch source {
        case .body:
            guard trigger.cooldown > 0 else { return }
            triggerCooldowns[trigger.code] = trigger.cooldown
        case let .statusEffect(code):
            statusEffects[code]?.startTriggerCooldown(trigger)
        }
    }

    /// Bills a fired trigger against the charges of the status that granted it,
    /// dropping the status once its last charge is gone — which is how an aura
    /// like "the next three attackers burn" retires itself.
    ///
    /// Charge-less effects are left alone entirely, so an aura bounded only by
    /// duration is unaffected. Removing an effect changes what the body's
    /// persistent stats sum to, hence the recalculation.
    public mutating func expendTriggerCharge(ofStatusEffect code: RPReferenceCode) {
        guard statusEffects[code]?.usesCharges == true else { return }
        statusEffects[code]?.expendCharge()
        guard (statusEffects[code]?.currentCharge ?? 0) <= 0 else { return }
        statusEffects[code] = nil
        recalculateStats()
    }

    public mutating func applyStatusEffect(_ statusEffect: RPStatusEffect<RP>) {
        if statusEffects[statusEffect.code] != nil {
            // TODO: Handle stackability of status effects rather than just resetting
            statusEffects[statusEffect.code]?.resetCooldown()
        } else {
            statusEffects[statusEffect.code] = RPActiveStatusEffect<RP>(bodyId: id, statusEffect: statusEffect)
        }
    }

    public mutating func dischargeStatusEffect(_ tag: RPStatusTag) {
        let relevantEffectNames = statusEffects.values
            .filter { $0.tags.contains(tag) }
            .map(\.code)

        relevantEffectNames
            .forEach { self.statusEffects[$0]?.expendCharge() }

        relevantEffectNames
            .filter { (self.statusEffects[$0]?.currentCharge ?? 0) <= 0 }
            .forEach {
                statusEffects[$0] = nil
            }
    }

    public mutating func resetCooldown() {
        currentTick = 0
    }

    public mutating func leaveEncounter() {
        teamId = nil
        currentTick = 0
        targets = []
        threat = [:]
    }

    public mutating func resetAbility(byName name: String) {
        executableAbilities[name]?.resetCooldown()
    }

    /// Advances every clock this body owns by one moment.
    ///
    /// Time is not uniform: the body's own cooldowns run at its speed multiplier
    /// (`ownMoment`) while each status effect gets a delta scaled for that
    /// effect, so a slowing aura can drag on its bearer without dragging on
    /// itself. Expired effects are swept here — which changes what persistent
    /// stats sum to, hence the recalculation.
    ///
    /// Only *body-declared* trigger cooldowns are counted down at the end;
    /// status-granted ones were already advanced inside their own effect's tick
    /// above. Like those, they count remaining time down and are removed at
    /// zero, so an absent key means ready.
    public mutating func tick(_ moment: RPMoment) {
        let ownMoment = RPMoment(delta: moment.delta * RP.timeMultiplier(for: self))
        let effectDeltas = statusEffects.keys.reduce(into: [String: RPTimeIncrement]()) {
            $0[$1] = moment.delta * RP.timeMultiplier(for: self, statusEffect: $1)
        }

        if currentTick < maximumTick {
            currentTick += ownMoment.delta
        }

        for key in statusEffects.keys {
            statusEffects[key]?.tick(RPMoment(delta: effectDeltas[key] ?? moment.delta))
        }
        let live = statusEffects.filter { !$0.value.isExpired }
        if live.count != statusEffects.count {
            statusEffects = live
            recalculateStats()
        }

        for name in executableAbilities.keys {
            executableAbilities[name]?.tick(ownMoment)
        }

        for key in triggerCooldowns.keys {
            let remaining = (triggerCooldowns[key] ?? 0) - ownMoment.delta
            triggerCooldowns[key] = remaining > 0 ? remaining : nil
        }

        if threatDecayPerTick > 0, !threat.isEmpty {
            let decay = RPValue((threatDecayPerTick * ownMoment.delta).rounded())
            if decay > 0 {
                for id in threat.keys {
                    setThreat(toward: id, amount: (threat[id] ?? 0) - decay)
                }
            }
        }
    }

    public mutating func recalculateStats() {
        setCurrentStats(currentStats)
    }

    public func getPendingEvents(in rpSpace: RP) -> [RPEvent<RP>] {
        getPendingExecutableEvents(in: rpSpace)
    }

    func getPendingStatusEffectEvents(in rpSpace: RP) -> [RPEvent<RP>] {
        statusEffects.values.flatMap { $0.getPendingEvents(in: rpSpace) }
    }

    public func getPendingExecutableEvents(in rpSpace: RP) -> [RPEvent<RP>] {
        guard !isCoolingDown(), canPerformEvents() else {
            return []
        }

        // Get any events that should execute based on priorities
        let abilityEvents = usableAbilities(in: rpSpace)
            .first(where: {
                ability in
                guard let firstEvent = ability.getPendingEvents(in: rpSpace).first else {
                    return false
                }
                return firstEvent.targets.isEmpty == false
            })
            .map { $0.getPendingEvents(in: rpSpace) } ?? []

        return abilityEvents
    }

    public func predictNextEvents(within horizon: RPTimeIncrement, in rpSpace: RP) -> [RPPredictedEvent<RP>] {
        guard canPerformEvents() else {
            return []
        }

        let viable = executableAbilities.values.filter {
            $0.wouldExecute(in: rpSpace)
                && $0.predictEvents(in: rpSpace).first?.targets.isEmpty == false
        }
        guard viable.isEmpty == false else {
            return []
        }

        var bodyReadyAt = Swift.max(0, maximumTick - currentTick)
        var abilityReadyAt: [RPReferenceCode: RPTimeIncrement] = viable.reduce(into: [:]) {
            $0[$1.ability.code] = Swift.max(0, $1.maximumTick - $1.currentTick)
        }

        var predictions: [RPPredictedEvent<RP>] = []
        var lastActAt: RPTimeIncrement = -1
        while bodyReadyAt <= horizon {
            guard let chosen = viable
                .first(where: { (abilityReadyAt[$0.ability.code] ?? 0) <= bodyReadyAt })
                ?? viable.min(by: {
                    (abilityReadyAt[$0.ability.code] ?? 0) < (abilityReadyAt[$1.ability.code] ?? 0)
                }),
                  let event = chosen.predictEvents(in: rpSpace).first
            else {
                break
            }
            let actAt = Swift.max(bodyReadyAt, abilityReadyAt[chosen.ability.code] ?? 0)
            guard actAt <= horizon, actAt > lastActAt || predictions.isEmpty else {
                break
            }
            predictions.append(RPPredictedEvent(event: event, readyIn: actAt))
            lastActAt = actAt
            abilityReadyAt[chosen.ability.code] = actAt + chosen.maximumTick
            bodyReadyAt = actAt + maximumTick
        }
        return predictions
    }

    /// Re-stamps this body's id onto the things that cached a copy of it, after
    /// `id` changes — which happens when a body is minted from the cache.
    /// Triggers are absent here on purpose: they carry no owner id, and are
    /// always evaluated against a body passed in at the call site.
    fileprivate mutating func updateIds() {
        executableAbilities.keys.forEach {
            abilityName in
            executableAbilities[abilityName]?.bodyId = id
        }
        statusEffects.keys.forEach {
            abilityName in
            statusEffects[abilityName]?.bodyId = id
        }
    }

    // Querying

    public func isCoolingDown() -> Bool {
        currentTick < maximumTick
    }

    public func canPerformEvents() -> Bool {
        for code in RP.actionImpairingStatuses where hasStatus(code) {
            return false
        }
        return true
    }

    public func hasStatus(_ code: RPStatusTag) -> Bool {
        statusEffects.values.contains { $0.tags.contains(code) }
    }
}

extension RPBody: CustomStringConvertible {
    public var description: String {
        "Body:\n " + String(describing: currentStats)
    }
}

extension RPBody: Equatable {}

public func == <RP: RPSpace>(_ lhs: RPBody<RP>, _ rhs: RPBody<RP>) -> Bool {
    lhs.id == rhs.id
}

extension RPBody: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
