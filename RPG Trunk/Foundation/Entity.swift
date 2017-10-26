
open class Entity: Temporal, InventoryManager {

    open var id: String = ""
    open var teamId: String?
    
    open var currentTick: RPTimeIncrement = 0
    open var maximumTick: RPTimeIncrement = 0
    
    open var baseStats: Stats = [:]
    open var currentStats: Stats = [:] //when a value is nil, for a given key, it means it's at max
    open var body = Body()
    open var inventory: [Storable] = []
    
    open fileprivate(set) var executableAbilities: [String: ActiveAbility] = [:]
    open fileprivate(set) var passiveAbilities: [String: ActiveAbility] = [:]
    open fileprivate(set) var statusEffects: [String: ActiveStatusEffect] = [:]
    
    open var targets: [Entity] = []
    
    open weak var data:AnyObject?
    
    open var stats: Stats {
        var totalStats = self.baseStats
        for weapon in self.body.weapons {
            totalStats = totalStats + weapon.stats
        }
        for equip in self.body.equipment {
            totalStats = totalStats + equip.stats
        }
        return totalStats
    }
    
    open subscript(index:String) -> RPValue {
        return currentStats.get(index) ?? stats[index]
    }
    
    open func allCurrentStats() -> Stats {
        var cs:[String:RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = currentStats.get(type) ?? maxStats[type]
        }
        return Stats(cs)
    }
    
    open func setCurrentStats(_ newStats: Stats) {
        var cs:[String:RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = newStats[type] < maxStats[type] ? newStats[type] : nil
        }
        currentStats = Stats(cs, asPartial: true)
    }
    
    open func usableAbilities() -> [ActiveAbility] {
        
        guard !isCoolingDown() else {
            return []
        }
        
        return executableAbilities.values
            .filter { $0.canExecute() && allCurrentStats() > $0.ability.cost }
    }
    
    
    //MARK: - Initialization
    
    open static func new() -> Entity {
        return RPGameEnvironment.current.delegate.createDefaultEntity()
    }
    
    public init(_ data:[String:RPValue]) {
        self.baseStats = Stats(data)
    }
    
    public convenience init() {
        self.init([:])
    }
    
    open func getPossibleTargets() -> [Entity]? {
        
        if targets.count > 0 {
            return targets
        }
        
        return nil
    }
    
    open func getTarget() -> Entity? {
        return targets.first
    }
    
    open func addExecutableAbility(_ ability:Ability, conditional:Conditional) {
        var activeAbility = ActiveAbility(ability, conditional)
        activeAbility.entity = self
        executableAbilities[ability.name] = activeAbility
    }
    
    open func addPassiveAbility(_ ability:Ability, conditional:Conditional) {
        var activeAbility = ActiveAbility(ability, conditional)
        activeAbility.entity = self
        passiveAbilities[ability.name] = activeAbility
    }
    
    open func applyStatusEffect(_ se: StatusEffect) {
        
        if statusEffects[se.identity.name] != nil {
            //TODO: Handle stackability of status effects rather than just resetting
            statusEffects[se.identity.name]?.resetCooldown()
        } else {
            statusEffects[se.identity.name] = ActiveStatusEffect(se)
        }
    }
    
    open func dischargeStatusEffect(_ label: String) {
        
        let relevantEffectNames = statusEffects.values
            .filter { $0.identity.labels.contains(label) }
            .map { $0.identity.name }
            
        relevantEffectNames
            .forEach { statusEffects[$0]?.expendCharge() }
        
        relevantEffectNames
            .filter { statusEffects[$0]?.isCoolingDown() == false }
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
        
        if false == statusEffects[name]?.isCoolingDown() {
            statusEffects[name] = nil
        }
    }
    
    open func tick(_ moment:Moment) {
        
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
        return getPendingPassiveEvents(in: rpSpace) + getPendingExecutableEvents(in: rpSpace)
    }

    func getPendingStatusEffectEvents(in rpSpace: RPSpace) -> [Event] {
        return statusEffects.values.flatMap { $0.getPendingEvents(in: rpSpace) }
    }
    
    open func getPendingExecutableEvents(in rpSpace: RPSpace) -> [Event] {
        
        guard !isCoolingDown() && canPerformEvents() else {
            return []
        }
        
        // Get any events that should execute based on priorities
        let abilityEvents = usableAbilities()
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
        
        for activeAbility in passiveAbilities.values where activeAbility.canExecute() {
            abilityEvents += activeAbility.getPendingEvents(in: rpSpace)
        }
        return abilityEvents
    }

    //Querying
    
    open func canPerformEvents() -> Bool {
        
        for se in statusEffects.values where se.shouldDisableEntity() {
            return false
        }
        return true
    }
    
    open func hasStatus(_ name: String) -> Bool {
        return statusEffects[name] != nil
    }
}

extension Entity {

    public func copy() -> Entity {
        
        let entity = Entity()
        entity.currentTick = self.currentTick
        entity.maximumTick = self.maximumTick
        entity.baseStats = self.baseStats
        entity.currentStats = self.currentStats
        entity.body = self.body
        entity.executableAbilities = self.executableAbilities
            .map { $0.value.copyForEntity(entity) }
            .toDictionary { $0.ability.name }
        entity.passiveAbilities = self.passiveAbilities
            .map { $0.value.copyForEntity(entity) }
            .toDictionary { $0.ability.name }
        entity.statusEffects = self.statusEffects
        return entity
    }
}

extension Entity: CustomStringConvertible {
    
    public var description:String {
        var o:[String:String] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            o[type] = " \(currentStats.get(type) ?? maxStats[type])/\(maxStats[type])"
        }
        return "Entity:\n " + o.description
    }
    
}
