
public class Entity: Temporal {
    
    public var currentTick: Double = 0
    public var maximumTick: Double = 0
    
    public var baseStats: Stats = [:]
    public var currentStats: Stats = [:] //when a value is nil, for a given key, it means it's at max
    public var body = Body()
    
    public private(set) var executableAbilities:[ActiveAbility] = []
    public private(set) var passiveAbilities:[ActiveAbility] = []
    public private(set) var statusEffects:[ActiveStatusEffect] = []
    
    public var targets:[Entity] = []
    public var target: Entity? {
        get {
            return targets.first
        }
        set {
            if let v = newValue {
                targets = [v]
                return
            }
            targets = []
        }
    }
    
    public weak var data:AnyObject?
    
    // Stored on the entity for reuse
    public lazy var parser:Parser<String, PropertyResultType> = {
        return boolParser()
            <|> valueParser()
            <|> entityTargetParser(self)
            <|> entityStatusParser(self)
            <|> entityStatParser(self)
    }()
    
    
    //MARK: - Computed properties
    
    public var stats: Stats {
        var totalStats = self.baseStats
        for weapon in self.body.weapons {
            totalStats = totalStats + weapon.stats
        }
        for equip in self.body.equipment {
            totalStats = totalStats + equip.stats
        }
        return totalStats
    }
    
    public subscript(index:String) -> RPValue {
        return currentStats.get(index) ?? stats[index]
    }
    
    public func allCurrentStats() -> Stats {
        var cs:[String:RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = currentStats.get(type) ?? maxStats[type]
        }
        return Stats(cs)
    }
    
    public func setCurrentStats(newStats: Stats) {
        var cs:[String:RPValue] = [:]
        let maxStats = stats
        for type in RPGameEnvironment.statTypes {
            cs[type] = newStats[type] < maxStats[type] ? newStats[type] : nil
        }
        currentStats = Stats(cs, asPartial: true)
    }
    
    public func usableAbilities () -> [Ability] {
        
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
    
    public static func new() -> Entity {
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
    
    
    //MARK: Abilities
    
    public func addExecutableAbility(ability:Ability, conditional:Conditional) {
        let activeAbility = ActiveAbility(ability, conditional)
        activeAbility.entity = self
        executableAbilities.append(activeAbility)
    }
    
    public func addPassiveAbility(ability:Ability, conditional:Conditional) {
        let activeAbility = ActiveAbility(ability, conditional)
        activeAbility.entity = self
        passiveAbilities.append(activeAbility)
    }
    
    public func applyStatusEffect(se:StatusEffect) {
        
        if let existing = statusEffects.find({ $0.name == se.identity.name }) {
            
            //TODO: Handle stackability of status effects rather than just resetting
            existing.resetCooldown()
        } else {
        
            statusEffects.append(ActiveStatusEffect(se))
        }
        
    }
    
    public func dischargeStatusEffect(label:String) {
        statusEffects
            .filter { $0.labels.contains(label) }
            .forEach { $0.expendCharge() }
        statusEffects = statusEffects.filter { $0.isCoolingDown() }
    }
    
    //MARK: - RPEvent/Battle handling
    
    public func tick(moment:Moment) -> [Event] {
        
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
            
            if let _ = target {
                abilityEvents += activeAbility.getEvents()
                resetCooldown()
                break
            }
        }
        
        return abilityEvents + buffEvents
    }
    
    public func resetCooldown() {
        currentTick = 0
    }
    
    func eventWillOccur(event: Event) -> [Event] {
        return [] //TODO: Check for passive abilities that would trigger based on this event
    }

    func eventDidOccur(event: Event) -> [Event] {
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
    
    func hasStatus(name:String) -> Bool {
        return statusEffects.find({ $0.name == name }) != nil
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