import Foundation

@dynamicMemberLookup
public struct RPEntity<RP: RPSpace>: Temporal, InventoryManager, Codable {

    public typealias Stats = RP.Stats
    
    public var id: RPEntityId = UUID().uuidString {
        didSet {
            updateIds()
        }
    }

    public var teamId: RPTeamId?

    public var currentTick: RPTimeIncrement = 0
    public var maximumTick: RPTimeIncrement = 0

    public var baseStats: Stats = .zero
    public var currentStats: Stats = .zero
    public var body = Body<RP>()
    public var inventory: [RPItemId] = []

    public internal(set) var executableAbilities: [String: ActiveAbility<RP>] = [:]
    public internal(set) var passiveAbilities: [String: ActiveAbility<RP>] = [:]
    public internal(set) var statusEffects: [String: ActiveStatusEffect<RP>] = [:]

    public var targets: Set<RPEntityId> = []

    public subscript(index: String) -> RPValue {
        currentStats[index]
    }
    
    public subscript<T>(dynamicMember keyPath: KeyPath<Stats, T>) -> T {
        currentStats[keyPath: keyPath]
    }

    public static func new(cache: RPCache<RP>) -> RPEntity {
        RP.createDefaultEntity(cache: cache)
    }

    public init(_ data: [String: RPValue]) {
        baseStats = Stats(dict: data)
        currentStats = baseStats
    }

    public init() {
        self.init([:])
    }
    
    public func getTotalStats(in rpSpace: RP) -> Stats {
        var totalStats = self.baseStats
        body.wornItems
            .compactMap { rpSpace.itemById($0) }
            .forEach { item in
                totalStats = totalStats + item.stats
            }
        return totalStats
    }

    public mutating func setCurrentStats(_ newStats: Stats, in rpSpace: RP) {
        var newCurrentStats: [String: RPValue] = [:]
        let maxStats = getTotalStats(in: rpSpace)
        for type in RP.statTypes {
            newCurrentStats[type] = newStats[type] < maxStats[type] ? newStats[type] : maxStats[type]
        }
        currentStats = Stats(dict: newCurrentStats)
    }

    public func usableAbilities(in rpSpace: RP) -> [ActiveAbility<RP>] {
        guard !isCoolingDown() else {
            return []
        }

        return executableAbilities.values
            .filter {
                $0.canExecute(in: rpSpace) && (currentStats >= $0.ability.cost || $0.ability.cost == .zero)
            }
    }

    public func getPossibleTargets() -> Set<RPEntityId>? {
        if targets.count > 0 {
            return targets
        }

        return nil
    }

    public func getTarget() -> RPEntityId? {
        targets.first
    }

    public mutating func addExecutableAbility(_ ability: Ability<RP>, conditional: Conditional<RP>) {
        let activeAbility = ActiveAbility<RP>(entityId: id, ability: ability, conditional: conditional)
        executableAbilities[ability.name] = activeAbility
    }

    public mutating func addPassiveAbility(_ ability: Ability<RP>, conditional: Conditional<RP>) {
        let activeAbility = ActiveAbility<RP>(entityId: id, ability: ability, conditional: conditional)
        passiveAbilities[ability.name] = activeAbility
    }

    public mutating func applyStatusEffect(_ statusEffect: StatusEffect<RP>) {
        if statusEffects[statusEffect.name] != nil {
            // TODO: Handle stackability of status effects rather than just resetting
            statusEffects[statusEffect.name]?.resetCooldown()
        } else {
            statusEffects[statusEffect.name] = ActiveStatusEffect<RP>(entityId: id, statusEffect: statusEffect)
        }
    }

    public mutating func dischargeStatusEffect(_ label: String) {
        let relevantEffectNames = statusEffects.values
            .filter { $0.tags.contains(label) }
            .map(\.name)

        relevantEffectNames
            .forEach { self.statusEffects[$0]?.expendCharge() }

        relevantEffectNames
            .filter { self.statusEffects[$0]?.currentCharge == 0 }
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

    public mutating func tick(_ moment: Moment) {
        if currentTick < maximumTick {
            currentTick += moment.delta
        }

        for key in statusEffects.keys {
            statusEffects[key]?.tick(moment)
        }

        for name in executableAbilities.keys {
            executableAbilities[name]?.tick(moment)
        }
    }

    public func getPendingEvents(in rpSpace: RP) -> [Event<RP>] {
        getPendingPassiveEvents(in: rpSpace) + getPendingExecutableEvents(in: rpSpace)
    }

    func getPendingStatusEffectEvents(in rpSpace: RP) -> [Event<RP>] {
        statusEffects.values.flatMap { $0.getPendingEvents(in: rpSpace) }
    }

    public func getPendingExecutableEvents(in rpSpace: RP) -> [Event<RP>] {
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

    public func getPendingPassiveEvents(in rpSpace: RP) -> [Event<RP>] {
        var abilityEvents = [Event<RP>]()

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

public extension RPEntity {
    //TODO: revisit this function, was made pre-value type convversion
    func copy() -> RPEntity {
        var entity = RPEntity()
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

extension RPEntity: CustomStringConvertible {
    public var description: String {
        "Entity:\n " + String(describing: currentStats)
    }
}

extension RPEntity: Equatable {}

public func == <RP: RPSpace>(_ lhs: RPEntity<RP>, _ rhs: RPEntity<RP>) -> Bool {
    lhs.id == rhs.id
}

extension RPEntity: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
