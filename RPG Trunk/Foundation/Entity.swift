
open class Entity: Temporal {
    
    open var currentTick: Double = 0
    open var maximumTick: Double = 0
    
    open var baseStats: Stats = [:]
    open var currentStats: Stats = [:] //when a value is nil, for a given key, it means it's at max
    open var body = Body()
    
    open fileprivate(set) var executableAbilities:[ActiveAbility] = []
    open fileprivate(set) var passiveAbilities:[ActiveAbility] = []
    open fileprivate(set) var statusEffects:[ActiveStatusEffect] = []
    
    open weak var parent:Entity? = nil
    open fileprivate(set) var children:[Entity] = []
    
    open var targets: [Entity] = []
    
    open weak var data:AnyObject?
    
    
    //MARK: - Computed properties
    
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
        
        return executableAbilities.flatMap {
            activeAbility in
            
            if self.allCurrentStats() >= activeAbility.ability.cost {
                return activeAbility.ability
            }
            return nil
        }
    }
    
    
    //MARK: - Initialization
    
    open static func new() -> Entity {
        return RPGameEnvironment.current.delegate.entityDefaults.copy()
    }
    
    public init(_ data:[String:RPValue]) {
        self.baseStats = Stats(data)
    }
    
    public convenience init() {
        self.init([:])
    }
    
    deinit {
        print("Entity dealloc", self)
    }
    
    
    //MARK: - Children
    
    open func addChild(_ entity:Entity) {
        assert(entity.parent == nil, "Entity already has a parent")
        
        entity.parent = self
        children.append(entity)
    }
    
    open func removeChild(_ entity:Entity) {
        guard let p = entity.parent, p === self,
           let idx = children.index(where: { $0 === entity })
            else {
            return
        }
        
        children.remove(at: idx)
        entity.parent = nil
    }
    
    
    //MARK: Targeting & Abilities
    
    open func getPossibleTargets() -> [Entity]? {
        
        if targets.count > 0 {
            return targets
        }
        
        if let p = parent,
            let targs = p.getPossibleTargets() {
            return targs
        }
        
        return nil
    }
    
    open func getTarget() -> Entity? {
        return targets.first
    }
    
    open func addExecutableAbility(_ ability:Ability, conditional:Conditional) {
        let activeAbility = ActiveAbility(ability, conditional)
        activeAbility.entity = self
        executableAbilities.append(activeAbility)
    }
    
    open func addPassiveAbility(_ ability:Ability, conditional:Conditional) {
        let activeAbility = ActiveAbility(ability, conditional)
        activeAbility.entity = self
        passiveAbilities.append(activeAbility)
    }
    
    open func applyStatusEffect(_ se:StatusEffect) {
        
        if let existing = statusEffects.first(where: { $0.name == se.identity.name }) {
            
            //TODO: Handle stackability of status effects rather than just resetting
            existing.resetCooldown()
        } else {
        
            statusEffects.append(ActiveStatusEffect(se))
        }
        
    }
    
    open func dischargeStatusEffect(_ label:String) {
        statusEffects
            .filter { $0.labels.contains(label) }
            .forEach { $0.expendCharge() }
        statusEffects = statusEffects.filter { $0.isCoolingDown() }
    }
    
    
    //MARK: - RPEvent/Battle handling
    
    open func tick(_ moment:Moment) -> [Event] {
        
        if currentTick < maximumTick {
            currentTick += moment.delta
        }
        
        // Next calculate new events that should occur from status effects
        let newMoment = moment.addSibling(self)
        let buffEvents = statusEffects.flatMap { $0.tick(newMoment) }
        
        statusEffects = statusEffects.filter { $0.isCoolingDown() }
        
        guard !isCoolingDown() && canPerformEvents() else {
            return buffEvents
        }
        
        // Get any events that should execute based on priorities
        var abilityEvents = [Event]()
        for activeAbility in executableAbilities where activeAbility.canExecute() {
            
            abilityEvents += activeAbility.getEvents()
            resetCooldown()
            break
        }
        
        return abilityEvents + buffEvents
    }
    
    open func resetCooldown() {
        currentTick = 0
    }
    
    func eventWillOccur(_ event: Event) -> [Event] {
        return [] //TODO: Check for passive abilities that would trigger based on this event
    }

    func eventDidOccur(_ event: Event) -> [Event] {
        var abilityEvents = [Event]()
        
        for activeAbility in passiveAbilities where activeAbility.canExecute() {
            abilityEvents += activeAbility.getEvents()
            break
        }
        return abilityEvents
    }
    
    //Querying
    
    func canPerformEvents() -> Bool {
        
        for se in statusEffects where se.shouldDisableEntity() {
            return false
        }
        return true
    }
    
    func hasStatus(_ name:String) -> Bool {
        return statusEffects.first(where: { $0.name == name }) != nil
    }
}

extension Entity {

    public func copy() -> Entity {
        
        let entity = Entity()
        entity.maximumTick = self.maximumTick
        entity.baseStats = self.baseStats
        entity.currentStats = self.currentStats
        entity.body = self.body
        entity.executableAbilities = self.executableAbilities.map { $0.copyForEntity(entity) }
        entity.passiveAbilities = self.passiveAbilities.map { $0.copyForEntity(entity) }
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
