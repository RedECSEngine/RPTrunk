
open class Entity: Temporal, InventoryManager, Codable {
    enum CodingKeys: String, CodingKey {
        case id
        case teamId
        case currentTick
        case maximumTick
        case baseStats
        case currentStats
        case body
        case inventory
        case executableAbilities
        case passiveAbilities
        case statusEffects
    }

    open var id: Id<Entity> = "" {
        didSet {
            updateIds()
        }
    }

    open var teamId: Id<Team>?

    open var currentTick: RPTimeIncrement = 0
    open var maximumTick: RPTimeIncrement = 0

    open var baseStats: Stats = [:]
    open var currentStats: Stats = [:] // when a value is nil, for a given key, it means it's at max
    open var body = Body()
    open var inventory: [Item] = []

    open fileprivate(set) var executableAbilities: [String: ActiveAbility] = [:]
    open fileprivate(set) var passiveAbilities: [String: ActiveAbility] = [:]
    open fileprivate(set) var statusEffects: [String: ActiveStatusEffect] = [:]

    open var targets: Set<Entity> = []

    open weak var data: AnyObject?

    open var stats: Stats {
        var totalStats = self.baseStats
        for item in self.body.wornItems {
            totalStats = totalStats + item.stats
        }
        return totalStats
    }

    open subscript(index: String) -> RPValue {
        currentStats.get(index) ?? stats[index]
    }

    public static func new() -> Entity {
        RPGameEnvironment.current.delegate.createDefaultEntity()
    }

    public init(_ data: [String: RPValue]) {
        baseStats = Stats(data)
        currentStats = baseStats
    }

    public convenience init() {
        self.init([:])
    }

    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(Id<Entity>.self, forKey: .id)
        teamId = try values.decodeIfPresent(Id<Team>.self, forKey: .teamId)
        currentTick = try values.decode(RPTimeIncrement.self, forKey: .currentTick)
        maximumTick = try values.decode(RPTimeIncrement.self, forKey: .maximumTick)
        baseStats = try values.decode(Stats.self, forKey: .baseStats)
        currentStats = try values.decode(Stats.self, forKey: .currentStats)
        body = try values.decode(Body.self, forKey: .body)
        inventory = try values.decode([Item].self, forKey: .inventory)
        executableAbilities = try values.decode([String: ActiveAbility].self, forKey: .executableAbilities)
        passiveAbilities = try values.decode([String: ActiveAbility].self, forKey: .passiveAbilities)
        statusEffects = try values.decode([String: ActiveStatusEffect].self, forKey: .statusEffects)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(teamId, forKey: .teamId)
        try container.encode(currentTick, forKey: .currentTick)
        try container.encode(maximumTick, forKey: .maximumTick)
        try container.encode(baseStats, forKey: .baseStats)
        try container.encode(currentStats, forKey: .currentStats)
        try container.encode(body, forKey: .body)
        try container.encode(inventory, forKey: .inventory)
        try container.encode(executableAbilities, forKey: .executableAbilities)
        try container.encode(passiveAbilities, forKey: .passiveAbilities)
        try container.encode(statusEffects, forKey: .statusEffects)
    }

    open func allCurrentStats() -> Stats {
        var cs: [String: RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = currentStats.get(type) ?? maxStats[type]
        }
        return Stats(cs)
    }

    open func setCurrentStats(_ newStats: Stats) {
        var cs: [String: RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = newStats[type] < maxStats[type] ? newStats[type] : nil
        }
        currentStats = Stats(cs, asPartial: true)
    }

    open func usableAbilities(in rpSpace: RPSpace) -> [ActiveAbility] {
        guard !isCoolingDown() else {
            return []
        }

        return executableAbilities.values
            .filter { $0.canExecute(in: rpSpace) && allCurrentStats() >= $0.ability.cost }
    }

    open func getPossibleTargets() -> Set<Entity>? {
        if targets.count > 0 {
            return targets
        }

        return nil
    }

    open func getTarget() -> Entity? {
        targets.first
    }

    open func addExecutableAbility(_ ability: Ability, conditional: Conditional) {
        let activeAbility = ActiveAbility(entityId: id, ability: ability, conditional: conditional)
        executableAbilities[ability.name] = activeAbility
    }

    open func addPassiveAbility(_ ability: Ability, conditional: Conditional) {
        let activeAbility = ActiveAbility(entityId: id, ability: ability, conditional: conditional)
        passiveAbilities[ability.name] = activeAbility
    }

    open func applyStatusEffect(_ statusEffect: StatusEffect) {
        if statusEffects[statusEffect.name] != nil {
            // TODO: Handle stackability of status effects rather than just resetting
            statusEffects[statusEffect.name]?.resetCooldown()
        } else {
            statusEffects[statusEffect.name] = ActiveStatusEffect(entityId: id, statusEffect: statusEffect)
        }
    }

    open func dischargeStatusEffect(_ label: String) {
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

    open func resetCooldown() {
        currentTick = 0
    }

    open func resetAbility(byName name: String) {
        executableAbilities[name]?.resetCooldown()
    }

    open func incrementTickForStatusEffect(byName name: String) {
        statusEffects[name]?.incrementTick()

        if statusEffects[name]?.isCoolingDown() == false {
            statusEffects[name] = nil
        }
    }

    open func tick(_ moment: Moment) {
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

    open func getPendingExecutableEvents(in rpSpace: RPSpace) -> [Event] {
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

    open func getPendingPassiveEvents(in rpSpace: RPSpace) -> [Event] {
        var abilityEvents = [Event]()

        for activeAbility in passiveAbilities.values where activeAbility.canExecute(in: rpSpace) {
            abilityEvents += activeAbility.getPendingEvents(in: rpSpace)
        }
        return abilityEvents
    }

    fileprivate func updateIds() {
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

    open func canPerformEvents() -> Bool {
        for se in statusEffects.values where se.shouldDisableEntity() {
            return false
        }
        return true
    }

    open func hasStatus(_ name: String) -> Bool {
        statusEffects[name] != nil
    }
}

public extension Entity {
    func copy() -> Entity {
        let entity = Entity()
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
