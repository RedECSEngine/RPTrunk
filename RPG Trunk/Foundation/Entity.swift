
open class Entity: Temporal {
    
    open var id: String = ""
    open var teamId: String?
    
    open var currentTick: RPTimeIncrement = 0
    open var maximumTick: RPTimeIncrement = 0
    
    open var baseStats: Stats = [:]
    open var currentStats: Stats = [:] //when a value is nil, for a given key, it means it's at max
    open var body = Body()
    
    open fileprivate(set) var executableAbilities:[String: ActiveAbility] = [:]
    open fileprivate(set) var passiveAbilities:[String: ActiveAbility] = [:]
    open fileprivate(set) var statusEffects:[ActiveStatusEffect] = []
    
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
    
    open func usableAbilities () -> [Ability] {
        
        guard !isCoolingDown() else {
            return []
        }
        
        return executableAbilities
            .filter { $0.value.canExecute() && allCurrentStats() > $0.value.ability.cost }
            .map { $0.value.ability }
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
    
    open func applyStatusEffect(_ se:StatusEffect) {
        
        if let statusIndex = statusEffects.index(where: { $0.name == se.identity.name }) {
            //TODO: Handle stackability of status effects rather than just resetting
            statusEffects[statusIndex].resetCooldown()
        } else {
            statusEffects.append(ActiveStatusEffect(se))
        }
    }
    
    open func dischargeStatusEffect(_ label:String) {
        
        let backwardsCount = (0..<statusEffects.count).reversed() // for safe array removal as traversing
        for i in backwardsCount {
            guard statusEffects[i].labels.contains(label) else {
                continue
            }
            statusEffects[i].expendCharge()
            if false == statusEffects[i].isCoolingDown() {
                statusEffects.remove(at: i)
            }
        }
    }
    
    open func resetCooldown() {
        currentTick = 0
    }
    
    open func resetAbility(byName name: String) {
        executableAbilities[name]?.resetCooldown()
    }
    
    open func tick(_ moment:Moment) -> [Event] {
        
        if currentTick < maximumTick {
            currentTick += moment.delta
        }
        
        let newMoment = moment.addSibling(self)
        
        var statusEffectEvents = [Event]()
        let backwardsCount = (0..<statusEffects.count).reversed() // for safe array removal as traversing
        for i in backwardsCount {
            statusEffectEvents += statusEffects[i].tick(newMoment)
            if false == statusEffects[i].isCoolingDown() {
                statusEffects.remove(at: i)
            }
        }
        
        for name in executableAbilities.keys {
            _ = executableAbilities[name]?.tick(newMoment)
        }
        
        return getPendingPassiveEvents() + statusEffectEvents + getPendingExecutableEvents()
    }
    
    func getPendingExecutableEvents() -> [Event] {
        
        guard !isCoolingDown() && canPerformEvents() else {
            return []
        }
        
        // Get any events that should execute based on priorities
        var abilityEvents = [Event]()
        for activeAbility in executableAbilities.values where activeAbility.canExecute() {
                
                abilityEvents += activeAbility.getEvents()
                break
        }
        abilityEvents = abilityEvents.filter { false == $0.targets.isEmpty }
        
        return abilityEvents
    }
    
    open func getPendingPassiveEvents() -> [Event] {
        var abilityEvents = [Event]()
        
        for activeAbility in passiveAbilities.values where activeAbility.canExecute() {
            abilityEvents += activeAbility.getEvents()
        }
        return abilityEvents
    }

    //Querying
    
    open func canPerformEvents() -> Bool {
        
        for se in statusEffects where se.shouldDisableEntity() {
            return false
        }
        return true
    }
    
    open func hasStatus(_ name:String) -> Bool {
        return statusEffects.first(where: { $0.name == name }) != nil
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
