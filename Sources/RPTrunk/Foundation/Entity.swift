import Foundation

public struct Entity: Temporal, InventoryManager, Codable {

    public var id: Id<Entity> = Id<Entity>(value: UUID().uuidString) {
        didSet {
            updateIds()
        }
    }

    public var teamId: Id<Team>?

    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement = 0

    public var baseStats: Stats = [:]
    public var currentStats: Stats = [:] // when a value is nil, for a given key, it means it's at max
    public var body = Body()
    public var inventory: [Item] = []

    public fileprivate(set) var executableAbilities: [String: ActiveAbility] = [:]
    public fileprivate(set) var passiveAbilities: [String: ActiveAbility] = [:]
    public fileprivate(set) var statusEffects: [String: ActiveStatusEffect] = [:]

    public var targets: Set<Id<Entity>> = []

    public var stats: Stats {
        var totalStats = self.baseStats
        for item in self.body.wornItems {
            totalStats = totalStats + item.stats
        }
        return totalStats
    }

    public subscript(index: String) -> RPValue {
        currentStats.get(index) ?? stats[index]
    }

    public static func new() -> Entity {
        RPGameEnvironment.current.delegate.createDefaultEntity()
    }

    public init(_ data: [String: RPValue]) {
        baseStats = Stats(data)
        currentStats = baseStats
    }

    public init() {
        self.init([:])
    }

    public func allCurrentStats() -> Stats {
        var cs: [String: RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = currentStats.get(type) ?? maxStats[type]
        }
        return Stats(cs)
    }

    public mutating func setCurrentStats(_ newStats: Stats) {
        var cs: [String: RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = newStats[type] < maxStats[type] ? newStats[type] : nil
        }
        currentStats = Stats(cs, asPartial: true)
    }

    public func usableAbilities(in rpSpace: RPSpace) -> [ActiveAbility] {
        guard !isCoolingDown() else {
            return []
        }

        return executableAbilities.values
            .filter { $0.canExecute(in: rpSpace) && allCurrentStats() >= $0.ability.cost }
    }

    public func getPossibleTargets() -> Set<Id<Entity>>? {
        if targets.count > 0 {
            return targets
        }

        return nil
    }

    public func getTarget() -> Id<Entity>? {
        targets.first
    }

    public mutating func addExecutableAbility(_ ability: Ability, conditional: Conditional) {
        let activeAbility = ActiveAbility(entityId: id, ability: ability, conditional: conditional)
        executableAbilities[ability.name] = activeAbility
    }

    public mutating func addPassiveAbility(_ ability: Ability, conditional: Conditional) {
        let activeAbility = ActiveAbility(entityId: id, ability: ability, conditional: conditional)
        passiveAbilities[ability.name] = activeAbility
    }

    public mutating func applyStatusEffect(_ statusEffect: StatusEffect) {
        if statusEffects[statusEffect.name] != nil {
            // TODO: Handle stackability of status effects rather than just resetting
            statusEffects[statusEffect.name]?.resetCooldown()
        } else {
            statusEffects[statusEffect.name] = ActiveStatusEffect(entityId: id, statusEffect: statusEffect)
        }
    }

    public mutating func dischargeStatusEffect(_ label: String) {
        let relevantEffectNames = statusEffects.values
            .filter { $0.labels.contains(label) }
            .map(\.name)

        relevantEffectNames
            .forEach { self.statusEffects[$0]?.expendCharge() }

        relevantEffectNames
            .filter { self.statusEffects[$0]?.isCoolingDown() == false }
            .forEach {
                statusEffects[$0] = nil
            }
    }

    public mutating func resetCooldown() {
        currentTick = 0
    }

    public mutating func resetAbility(byName name: String) {
        executableAbilities[name]?.resetCooldown()
    }

    public mutating func incrementTickForStatusEffect(byName name: String) {
        statusEffects[name]?.incrementTick()

        if statusEffects[name]?.isCoolingDown() == false {
            statusEffects[name] = nil
        }
    }

    public mutating func tick(_ moment: Moment) {
        if currentTick < maximumTick {
            currentTick += moment.delta
        }

        let newMoment = moment.addSibling(self)

        for key in statusEffects.keys {
            statusEffects[key]?.tick(newMoment)
        }

        for name in executableAbilities.keys {
            executableAbilities[name]?.tick(newMoment)
        }
    }

    public func getPendingEvents(in rpSpace: RPSpace) -> [Event] {
        getPendingPassiveEvents(in: rpSpace) + getPendingExecutableEvents(in: rpSpace)
    }

    func getPendingStatusEffectEvents(in rpSpace: RPSpace) -> [Event] {
        statusEffects.values.flatMap { $0.getPendingEvents(in: rpSpace) }
    }

    public func getPendingExecutableEvents(in rpSpace: RPSpace) -> [Event] {
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

    public func getPendingPassiveEvents(in rpSpace: RPSpace) -> [Event] {
        var abilityEvents = [Event]()

        for activeAbility in passiveAbilities.values where activeAbility.canExecute(in: rpSpace) {
            abilityEvents += activeAbility.getPendingEvents(in: rpSpace)
        }
        return abilityEvents
    }

    fileprivate mutating func updateIds() {
        executableAbilities.keys.forEach {
            abilityName in
            executableAbilities[abilityName]?.entityId = id
        }
        passiveAbilities.keys.forEach {
            abilityName in
            passiveAbilities[abilityName]?.entityId = id
        }
        statusEffects.keys.forEach {
            abilityName in
            statusEffects[abilityName]?.entityId = id
        }
    }

    // Querying

    public func canPerformEvents() -> Bool {
        for se in statusEffects.values where se.shouldDisableEntity() {
            return false
        }
        return true
    }

    public func hasStatus(_ name: String) -> Bool {
        statusEffects[name] != nil
    }
}

public extension Entity {
    func copy() -> Entity {
        var entity = Entity()
        entity.currentTick = currentTick
        entity.maximumTick = maximumTick
        entity.baseStats = baseStats
        entity.currentStats = currentStats
        entity.body = body
        entity.executableAbilities = executableAbilities
            .map { $0.value.copyForEntity(entity) }
            .toDictionary { $0.ability.name }
        entity.passiveAbilities = passiveAbilities
            .map { $0.value.copyForEntity(entity) }
            .toDictionary { $0.ability.name }
        entity.statusEffects = statusEffects
        return entity
    }
}

extension Entity: CustomStringConvertible {
    public var description: String {
        var o: [String: String] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            o[type] = " \(currentStats.get(type) ?? maxStats[type])/\(maxStats[type])"
        }
        return "Entity:\n " + o.description
    }
}

extension Entity: Equatable {}

public func == (_ lhs: Entity, _ rhs: Entity) -> Bool {
    lhs.id == rhs.id
}

extension Entity: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
