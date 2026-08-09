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

    public var targetingRange: Double = 1

    public private(set) var baseStats: Stats = .zero
    public private(set) var currentStats: Stats = .zero
    public var equipment = RPEquipment<RP>()
    public var inventory: [RPActiveItem<RP>] = []
    public var metadata: RP.BodyMetadata?

    public internal(set) var executableAbilities: [String: RPActiveAbility<RP>] = [:]
    public internal(set) var abilityOrder: [String] = []
    public internal(set) var statusEffects: [String: RPActiveStatusEffect<RP>] = [:]
    public internal(set) var triggers: [RPTrigger<RP>] = []
    public internal(set) var triggerCooldowns: [RPReferenceCode: RPTimeIncrement] = [:]

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

        return orderedExecutableAbilities
            .filter { $0.canExecute(in: rpSpace) }
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
        if executableAbilities[ability.code] == nil {
            abilityOrder.append(ability.code)
        }
        executableAbilities[ability.code] = activeAbility
    }

    public var orderedExecutableAbilities: [RPActiveAbility<RP>] {
        abilityOrder.compactMap { executableAbilities[$0] }
    }

    public mutating func addTrigger(_ trigger: RPTrigger<RP>) {
        triggers.append(trigger)
    }

    public var allTriggers: [(source: RPTriggerSource, trigger: RPTrigger<RP>)] {
        triggers.map { (.body, $0) }
            + statusEffects
                .sorted { $0.key < $1.key }
                .flatMap { code, active in
                    active.triggers.map { (RPTriggerSource.statusEffect(code), $0) }
                }
    }

    public func isTriggerReady(_ source: RPTriggerSource, _ trigger: RPTrigger<RP>) -> Bool {
        switch source {
        case .body:
            return triggerCooldowns[trigger.code] == nil
        case let .statusEffect(code):
            return statusEffects[code]?.isTriggerReady(trigger) ?? false
        }
    }

    public mutating func startTriggerCooldown(_ source: RPTriggerSource, _ trigger: RPTrigger<RP>) {
        switch source {
        case .body:
            guard trigger.cooldown > 0 else { return }
            triggerCooldowns[trigger.code] = trigger.cooldown
        case let .statusEffect(code):
            statusEffects[code]?.startTriggerCooldown(trigger)
        }
    }

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
        threat = [:]
    }

    public mutating func resetAbility(byName name: String) {
        executableAbilities[name]?.resetCooldown()
    }

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

        tickTriggerCooldowns(&triggerCooldowns, by: ownMoment.delta)

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

        let viable = orderedExecutableAbilities.filter {
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

    public func hasAnyStatus(tagged tags: Set<RPStatusTag>) -> Bool {
        statusEffects.values.contains { $0.tags.contains(where: tags.contains) }
    }

    public func hasAllStatuses(tagged tags: Set<RPStatusTag>) -> Bool {
        var remaining = tags
        for effect in statusEffects.values {
            remaining.subtract(effect.tags)
            if remaining.isEmpty { return true }
        }
        return remaining.isEmpty
    }

    public func usesAnyAbility(tagged tags: Set<RPAbilityTag>) -> Bool {
        executableAbilities.values.contains { !$0.ability.tags.isDisjoint(with: tags) }
    }

    public func usesAllAbilities(tagged tags: Set<RPAbilityTag>) -> Bool {
        var remaining = tags
        for ability in executableAbilities.values {
            remaining.subtract(ability.ability.tags)
            if remaining.isEmpty { return true }
        }
        return remaining.isEmpty
    }

    public func holdsAnyItem(tagged tags: Set<RPItemTag>) -> Bool {
        inventory.contains { !$0.tags.isDisjoint(with: tags) }
            || equipment.wornItems.contains { !$0.tags.isDisjoint(with: tags) }
    }

    public func holdsAllItems(tagged tags: Set<RPItemTag>) -> Bool {
        var remaining = tags
        for item in inventory {
            remaining.subtract(item.tags)
            if remaining.isEmpty { return true }
        }
        for item in equipment.wornItems {
            remaining.subtract(item.tags)
            if remaining.isEmpty { return true }
        }
        return remaining.isEmpty
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
